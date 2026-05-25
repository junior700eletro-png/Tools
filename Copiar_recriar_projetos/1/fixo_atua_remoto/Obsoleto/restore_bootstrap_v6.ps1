# restore_bootstrap_v6.ps1 — CORRIGIDO (Remove-BinaryEntries reescrito com rastreamento de profundidade)
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Web.Extensions
Add-Type -AssemblyName System.Drawing

$flagStrict = $false

function Write-Log($m, $l='INFO') {
    Write-Host "[$(Get-Date -f 'HH:mm:ss') $l] $m"
}

# ─── Remove blocos de arquivos binários — rastreamento de profundidade de chaves ───
function Remove-BinaryEntries {
    param($raw)
    $extBin = '\.(lnk|exe|dll|so|dylib|bin|pyc|pyo|pyd|jpg|jpeg|png|gif|bmp|ico|webp|svg|pdf|doc|docx|xls|xlsx|ppt|pptx|zip|rar|7z|tar|gz|bz2|db|sqlite|sqlite3|mp3|mp4|avi|mov|wav|flac|ogg|wma|mkv|webm|ttf|otf|woff|woff2|eot|iso|img|o|a|lib|obj|pdb|idb|ilk)$'

    # Localiza o array "files"
    $mFiles = [regex]::Match($raw, '"files"\s*:\s*\[')
    if (-not $mFiles.Success) { return $raw }

    $arrStart = $mFiles.Index + $mFiles.Length
    # Encontra o ] de fechamento do array (profundidade)
    $depth = 1
    $arrEnd = $arrStart
    for ($i = $arrStart; $i -lt $raw.Length; $i++) {
        if ($raw[$i] -eq '[' -or $raw[$i] -eq '{') { $depth++ }
        elseif ($raw[$i] -eq ']' -or $raw[$i] -eq '}') { $depth-- }
        if ($depth -eq 0) { $arrEnd = $i; break }
    }

    $inner = $raw.Substring($arrStart, $arrEnd - $arrStart)

    # Extrai cada bloco {} individual por profundidade
    $entries = @()
    $i = 0
    while ($i -lt $inner.Length) {
        while ($i -lt $inner.Length -and $inner[$i] -ne '{') { $i++ }
        if ($i -ge $inner.Length) { break }
        $oStart = $i; $oDepth = 1; $i++
        while ($i -lt $inner.Length -and $oDepth -gt 0) {
            if ($inner[$i] -eq '{') { $oDepth++ }
            elseif ($inner[$i] -eq '}') { $oDepth-- }
            if ($oDepth -gt 0) { $i++ }
        }
        $entries += $inner.Substring($oStart, $i - $oStart + 1)
        $i++
    }

    # Filtra: mantém só os que NÃO são binários
    $filtered = @()
    foreach ($entry in $entries) {
        $pMatch = [regex]::Match($entry, '"path"\s*:\s*"([^"]*)"')
        if ($pMatch.Success -and $pMatch.Groups[1].Value -match $extBin) { continue }
        $filtered += $entry
    }

    # Reconstrói o JSON
    $before = $raw.Substring(0, $mFiles.Index)
    $after  = $raw.Substring($arrEnd + 1)
    return $before + '"files": [' + ($filtered -join ',') + ']' + $after
}

# ─── Sanitização do JSON ───
function Sanitize-JsonRaw {
    param($raw)
    if (-not $raw) { return $raw }
    $s = $raw -replace "`0", ''
    $s = [regex]::Replace($s, '[\x00-\x08\x0B\x0C\x0E-\x1F]', ' ')
    $s = $s -replace '\$', ''

    # Varredura caractere-por-caractere: remove \ quando seguido de char inválido
    $validEsc = @{'"'=$true; '\'=$true; '/'=$true; 'b'=$true; 'f'=$true; 'n'=$true; 'r'=$true; 't'=$true; 'u'=$true}
    $sb = New-Object System.Text.StringBuilder
    $i = 0
    while ($i -lt $s.Length) {
        if ($s[$i] -eq '\' -and $i + 1 -lt $s.Length) {
            $next = $s[$i + 1]
            if (-not $validEsc.ContainsKey($next)) { $i++ }
        }
        [void]$sb.Append($s[$i]); $i++
    }
    $s = $sb.ToString()
    $s = [regex]::Replace($s, ' {2,}', ' ')
    return $s.Trim()
}

function Convert-HashtableToPSObject {
    param($hash)
    if ($hash -is [System.Collections.IDictionary]) {
        $obj = New-Object PSObject
        foreach ($key in $hash.Keys) { $obj | Add-Member NoteProperty $key (Convert-HashtableToPSObject $hash[$key]) }
        return $obj
    }
    elseif ($hash -is [System.Collections.IList]) {
        $arr = @()
        foreach ($item in $hash) { $arr += Convert-HashtableToPSObject $item }
        return ,$arr
    }
    else { return $hash }
}

function Read-Bootstrap($path) {
    $raw = [System.IO.File]::ReadAllText($path, [Text.Encoding]::UTF8)
    $raw = $raw.Trim()
    if ($raw -match '^\s*#') {
        $lines = $raw -split "`r?`n"
        $raw = ($lines[1..($lines.Count - 1)] -join "`n").Trim()
    }

    $raw = Remove-BinaryEntries $raw
    $cleaned = Sanitize-JsonRaw $raw

    try {
        $ser = New-Object System.Web.Script.Serialization.JavaScriptSerializer
        $ser.MaxJsonLength = [int]::MaxValue
        return Convert-HashtableToPSObject ($ser.DeserializeObject($cleaned))
    }
    catch { Write-Log "JavaScriptSerializer: $_" 'WARN' }

    try {
        if ($cleaned -match '\{.*\}') {
            $extracted = $matches[0]
            $ser = New-Object System.Web.Script.Serialization.JavaScriptSerializer
            $ser.MaxJsonLength = [int]::MaxValue
            return Convert-HashtableToPSObject ($ser.DeserializeObject($extracted))
        }
    }
    catch { Write-Log "Fallback regex: $_" 'WARN' }

    try { return $cleaned | ConvertFrom-Json -ErrorAction Stop }
    catch { throw "JSON inválido mesmo após sanitização: $_" }
}

function Get-NextVersion($parentDir) {
    $max = -1
    if (Test-Path $parentDir) {
        Get-ChildItem $parentDir -Directory | ForEach-Object {
            if ($_.Name -match '^\d+$') { $v = [int]$_.Name; if ($v -gt $max) { $max = $v } }
        }
    }
    return $max + 1
}

function Update-NumberedPaths($data, $delta) {
    $pattern = '^(.*/)?(\d+)(/.*|)$'
    foreach ($f in $data.files) {
        if ($f.path -match $pattern) {
            $pre = $matches[1]; $num = [int]$matches[2]; $pos = $matches[3]
            $f.path = "$pre$([int]$num + $delta)$pos"
        }
    }
    for ($i = 0; $i -lt $data.folders.Count; $i++) {
        if ($data.folders[$i] -match $pattern) {
            $pre = $matches[1]; $num = [int]$matches[2]; $pos = $matches[3]
            $data.folders[$i] = "$pre$([int]$num + $delta)$pos"
        }
    }
    return $data
}

function Select-Items($title, $items, $label) {
    $form = New-Object System.Windows.Forms.Form
    $form.Text = $title; $form.Size = New-Object System.Drawing.Size(500,600)
    $form.StartPosition = 'CenterScreen'
    $form.MinimizeBox = $false; $form.MaximizeBox = $false

    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text = $label; $lbl.Location = New-Object System.Drawing.Point(12,9)
    $lbl.Size = New-Object System.Drawing.Size(460,20)

    $list = New-Object System.Windows.Forms.CheckedListBox
    $list.Location = New-Object System.Drawing.Point(12,35); $list.Size = New-Object System.Drawing.Size(460,430)
    $list.CheckOnClick = $true
    foreach ($item in $items) { [void]$list.Items.Add($item, $true) }

    $btnOK = New-Object System.Windows.Forms.Button
    $btnOK.Text = 'OK'; $btnOK.Location = New-Object System.Drawing.Point(300,480)
    $btnOK.Size = New-Object System.Drawing.Size(80,30)
    $btnOK.Add_Click({ $form.Close() })

    $btnAll = New-Object System.Windows.Forms.Button
    $btnAll.Text = 'Marcar Todos'; $btnAll.Location = New-Object System.Drawing.Point(120,480)
    $btnAll.Size = New-Object System.Drawing.Size(100,30)
    $btnAll.Add_Click({ for ($i=0; $i -lt $list.Items.Count; $i++) { $list.SetItemChecked($i, $true) } })

    $btnNone = New-Object System.Windows.Forms.Button
    $btnNone.Text = 'Desmarcar Todos'; $btnNone.Location = New-Object System.Drawing.Point(12,480)
    $btnNone.Size = New-Object System.Drawing.Size(100,30)
    $btnNone.Add_Click({ for ($i=0; $i -lt $list.Items.Count; $i++) { $list.SetItemChecked($i, $false) } })

    $form.Controls.AddRange(@($lbl, $list, $btnOK, $btnAll, $btnNone))
    $form.ShowDialog() | Out-Null

    $result = @()
    for ($i = 0; $i -lt $list.Items.Count; $i++) { if ($list.GetItemChecked($i)) { $result += $list.Items[$i] } }
    return $result
}

try {
    $of = New-Object System.Windows.Forms.OpenFileDialog
    $of.Filter = 'JSON Bootstrap|*.json'
    if ($of.ShowDialog() -ne 'OK') { exit }

    $data = Read-Bootstrap $of.FileName
    $basePath = if ($data.source_folder) { $data.source_folder } else { ".\" }

    Write-Log "Projeto: $($data.project_name) v$($data.version)" 'SUCCESS'
    Write-Log "Arquivos: $($data.files.Count) | Pastas: $($data.folders.Count)"
    if (-not $data.source_folder) { Write-Log "'source_folder' ausente — assumindo .\" 'WARN' }

    $resp = [System.Windows.Forms.MessageBox]::Show("Restaurar na pasta original?`n$basePath", 'Destino', 'YesNo', 'Question')
    if ($resp -eq 'Yes') { $dest = $basePath }
    else {
        $fd = New-Object System.Windows.Forms.FolderBrowserDialog
        $fd.Description = 'Selecione a pasta destino'
        if ($fd.ShowDialog() -ne 'OK') { exit }
        $dest = $fd.SelectedPath
    }

    $verParent = Join-Path $dest "Agente_Independente"
    $nextVer = Get-NextVersion $verParent
    if (Test-Path (Join-Path $verParent "0")) {
        $bumpResp = [System.Windows.Forms.MessageBox]::Show("Pasta Agente_Independente/0/ já existe.`nDeseja criar versão $nextVer?", 'Versionamento', 'YesNo', 'Question')
        if ($bumpResp -eq 'Yes') { $data = Update-NumberedPaths $data $nextVer; Write-Log "Bump: Agente_Independente/$nextVer/" 'SUCCESS' }
    }

    $selectFolders = $false
    $respF = [System.Windows.Forms.MessageBox]::Show("Deseja selecionar pastas específicas?`nSe não, restaura tudo.", 'Pastas', 'YesNo', 'Question')
    if ($respF -eq 'Yes') { $selectFolders = $true }

    $chosenFolders = @(); $chosenFiles = @()
    if ($selectFolders) {
        $shortFolders = @(); $seen = @{}
        foreach ($f in ($data.folders | Sort-Object)) {
            $top = ($f -split '/')[0]
            if (-not $seen.ContainsKey($top)) { $shortFolders += $top; $seen[$top] = $true }
        }
        if ($shortFolders.Count -eq 0) { $shortFolders = $data.folders | Sort-Object }
        $chosenFolders = Select-Items "Selecionar Pastas" $shortFolders "Marque as pastas:"
        if ($chosenFolders.Count -eq 0) { $selectFolders = $false }

        if ($chosenFolders.Count -gt 0) {
            $respA = [System.Windows.Forms.MessageBox]::Show("Deseja selecionar arquivos específicos?", 'Arquivos', 'YesNo', 'Question')
            if ($respA -eq 'Yes') {
                $candidate = @()
                foreach ($f in $data.files) {
                    foreach ($cf in $chosenFolders) { if ($f.path -like "$cf/*" -or $f.path -eq $cf) { $candidate += $f.path; break } }
                }
                $chosenFiles = Select-Items "Selecionar Arquivos" ($candidate | Sort-Object) "Marque os arquivos:"
            }
        }
    }

    $foldersToCreate = if ($selectFolders -and $chosenFolders.Count -gt 0) {
        $chosenFolders | ForEach-Object { $data.folders | Where-Object { $_ -eq $_ -or $_ -like "$_/*" } }
    } else { $data.folders }

    foreach ($folder in ($foldersToCreate | Sort-Object -Unique)) {
        $p = Join-Path $dest $folder
        if (!(Test-Path $p)) { New-Item $p -ItemType Directory -Force | Out-Null }
    }

    $ok = 0; $err = 0; $skip = 0
    $filesToRestore = if ($selectFolders -and $chosenFolders.Count -gt 0) {
        if ($chosenFiles.Count -gt 0) { $data.files | Where-Object { $chosenFiles -contains $_.path } }
        else {
            $data.files | Where-Object {
                $matched = $false
                foreach ($cf in $chosenFolders) { if ($_.path -like "$cf/*" -or $_.path -eq $cf) { $matched = $true; break } }
                $matched
            }
        }
    } else { $data.files }

    foreach ($file in $filesToRestore) {
        try {
            if (-not $file.path) { Write-Log "'path' ausente — ignorando" 'WARN'; $skip++; continue }
            if ($file.path.IndexOfAny([System.IO.Path]::GetInvalidPathChars()) -ge 0) {
                Write-Log "Path inválido: $($file.path) — ignorando" 'WARN'; $skip++; continue
            }

            $fp = Join-Path $dest $file.path
            $d = Split-Path $fp -Parent
            if (!(Test-Path $d)) { New-Item $d -ItemType Directory -Force | Out-Null }

            $content = if ($file.content) { $file.content -replace "`0", '' } else { '' }

            if ($file.size -and $file.size -gt 0 -and !$flagStrict) {
                $realSize = [System.Text.Encoding]::UTF8.GetByteCount($content)
                if ($realSize -ne $file.size) { Write-Log "Size divergente: $($file.path) — declarado $($file.size), real $realSize" 'WARN' }
            }

            [System.IO.File]::WriteAllText($fp, $content, [Text.Encoding]::UTF8)
            Write-Log "OK: $($file.path)" 'SUCCESS'; $ok++
        }
        catch { Write-Log "Falha em $($file.path): $_" 'ERROR'; $err++ }
    }

    [System.Windows.Forms.MessageBox]::Show("Restaurado: $ok arquivos`nPulados: $skip`nErros: $err`nPasta: $dest", 'Concluído', 'OK', 'Information')
    Write-Log "Final: $ok restaurados, $skip pulados, $err erros" 'SUCCESS'
}
catch {
    Write-Log "ERRO GERAL: $_" 'ERROR'
    [System.Windows.Forms.MessageBox]::Show("Erro: $_", 'Erro', 'OK', 'Error')
}

Read-Host 'Concluído. Enter para sair'