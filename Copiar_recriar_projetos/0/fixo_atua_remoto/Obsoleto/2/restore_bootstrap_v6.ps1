# restore_bootstrap_v6.ps1 — Restaurador completo com seleção de pastas/arquivos e version bump
Add-Type -AssemblyName System.Windows.Forms

$flagStrict = $false

function Write-Log($m, $l='INFO') {
    Write-Host "[$(Get-Date -f 'HH:mm:ss') $l] $m"
}

# ─── Parsing tolerante ───
function Read-Bootstrap($path) {
    $raw = [System.IO.File]::ReadAllText($path)
    $lines = $raw -split "`r?`n"
    $json = if ($lines[0].TrimStart().StartsWith('#')) {
        ($lines[1..($lines.Count - 1)] -join "`n")
    } else { $raw }

    try { $data = $json | ConvertFrom-Json -ErrorAction Stop }
    catch { throw "JSON inválido: $_" }

    if (-not $data.files -or @($data.files).Count -eq 0) {
        throw "Array 'files' vazio ou ausente."
    }
    return $data
}

# ─── Version bump: encontra próxima versão disponível ───
function Get-NextVersion($parentDir) {
    $max = -1
    if (Test-Path $parentDir) {
        Get-ChildItem $parentDir -Directory | ForEach-Object {
            if ($_.Name -match '^\d+$') {
                $v = [int]$_.Name
                if ($v -gt $max) { $max = $v }
            }
        }
    }
    return $max + 1
}

# ─── Atualiza paths numerados no JSON ───
function Update-NumberedPaths($data, $delta) {
    $pattern = '^(.*/)?(\d+)(/.*|)$'
    # Atualiza paths nos files
    foreach ($f in $data.files) {
        if ($f.path -match $pattern) {
            $pre = $matches[1]
            $num = [int]$matches[2]
            $pos = $matches[3]
            $newNum = $num + $delta
            $f.path = "$pre$newNum$pos"
        }
        # se content tiver header path, atualiza também
        if ($f.content -match '^#\s*(.*)') {
            $hPath = $matches[1]
            if ($hPath -match $pattern) {
                $pre = $matches[1]
                $num = [int]$matches[2]
                $pos = $matches[3]
                $newNum = $num + $delta
                $f.content = $f.content -replace "^#\s*$([regex]::Escape($hPath))", "# $pre$newNum$pos"
            }
        }
    }
    # Atualiza folders
    for ($i = 0; $i -lt $data.folders.Count; $i++) {
        if ($data.folders[$i] -match $pattern) {
            $pre = $matches[1]
            $num = [int]$matches[2]
            $pos = $matches[3]
            $newNum = $num + $delta
            $data.folders[$i] = "$pre$newNum$pos"
        }
    }
    return $data
}

# ─── Selecionar itens em CheckedListBox ───
function Select-Items($title, $items, $label) {
    $form = New-Object System.Windows.Forms.Form
    $form.Text = $title
    $form.Size = New-Object System.Drawing.Size(500,600)
    $form.StartPosition = 'CenterScreen'
    $form.MinimizeBox = $false; $form.MaximizeBox = $false

    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text = $label
    $lbl.Location = New-Object System.Drawing.Point(12,9)
    $lbl.Size = New-Object System.Drawing.Size(460,20)

    $list = New-Object System.Windows.Forms.CheckedListBox
    $list.Location = New-Object System.Drawing.Point(12,35)
    $list.Size = New-Object System.Drawing.Size(460,430)
    $list.CheckOnClick = $true
    foreach ($item in $items) { [void]$list.Items.Add($item, $true) }

    $btnOK = New-Object System.Windows.Forms.Button
    $btnOK.Text = 'OK'
    $btnOK.Location = New-Object System.Drawing.Point(300,480)
    $btnOK.Size = New-Object System.Drawing.Size(80,30)
    $btnOK.Add_Click({ $form.Close() })

    $btnAll = New-Object System.Windows.Forms.Button
    $btnAll.Text = 'Marcar Todos'
    $btnAll.Location = New-Object System.Drawing.Point(120,480)
    $btnAll.Size = New-Object System.Drawing.Size(100,30)
    $btnAll.Add_Click({ for ($i=0; $i -lt $list.Items.Count; $i++) { $list.SetItemChecked($i, $true) } })

    $btnNone = New-Object System.Windows.Forms.Button
    $btnNone.Text = 'Desmarcar Todos'
    $btnNone.Location = New-Object System.Drawing.Point(12,480)
    $btnNone.Size = New-Object System.Drawing.Size(100,30)
    $btnNone.Add_Click({ for ($i=0; $i -lt $list.Items.Count; $i++) { $list.SetItemChecked($i, $false) } })

    $form.Controls.AddRange(@($lbl, $list, $btnOK, $btnAll, $btnNone))
    $form.ShowDialog() | Out-Null

    $result = @()
    for ($i = 0; $i -lt $list.Items.Count; $i++) {
        if ($list.GetItemChecked($i)) { $result += $list.Items[$i] }
    }
    return $result
}

# ════════════════════════════ MAIN ════════════════════════════
try {
    # ── Abrir JSON ──
    $of = New-Object System.Windows.Forms.OpenFileDialog
    $of.Filter = 'JSON Bootstrap|*.json'
    if ($of.ShowDialog() -ne 'OK') { exit }

    $data = Read-Bootstrap $of.FileName

    $basePath = if ($data.source_folder) { $data.source_folder } else { ".\" }

    Write-Log "Projeto: $($data.project_name) v$($data.version)" 'SUCCESS'
    Write-Log "Arquivos: $($data.files.Count) | Pastas: $($data.folders.Count)"

    if (-not $data.source_folder) {
        Write-Log "'source_folder' ausente — assumindo .\" 'WARN'
    }

    # ── Destino ──
    $msg = "Restaurar na pasta original?`n$basePath"
    $resp = [System.Windows.Forms.MessageBox]::Show($msg, 'Destino', 'YesNo', 'Question')
    if ($resp -eq 'Yes') { $dest = $basePath }
    else {
        $fd = New-Object System.Windows.Forms.FolderBrowserDialog
        $fd.Description = 'Selecione a pasta destino'
        if ($fd.ShowDialog() -ne 'OK') { exit }
        $dest = $fd.SelectedPath
    }

    # ── Version bump ──
    $verParent = Join-Path $dest "Agente_Independente"
    $nextVer = Get-NextVersion $verParent

    if (Test-Path (Join-Path $verParent "0")) {
        $msgBump = "Pasta Agente_Independente/0/ já existe.`nDeseja criar versão $nextVer em vez de sobrescrever?"
        $bumpResp = [System.Windows.Forms.MessageBox]::Show($msgBump, 'Versionamento', 'YesNo', 'Question')
        if ($bumpResp -eq 'Yes') {
            $delta = $nextVer
            Write-Log "Aplicando bump de +$delta nas pastas numeradas" 'INFO'
            $data = Update-NumberedPaths $data $delta
            Write-Log "Nova versão: Agente_Independente/$delta/" 'SUCCESS'
        }
    }

    # ── Menu 1: Selecionar pastas? ──
    $selectFolders = $false
    $selFoldersResp = [System.Windows.Forms.MessageBox]::Show(
        "Deseja selecionar pastas específicas para restaurar?`nSe não, todas as pastas serão restauradas.",
        'Selecionar Pastas', 'YesNo', 'Question'
    )
    if ($selFoldersResp -eq 'Yes') { $selectFolders = $true }

    $chosenFolders = @()
    $chosenFiles = @()

    if ($selectFolders) {
        # Extrai as pastas de primeiro nível relevantes (a partir de Agente_Independente/N/)
        $folderPrefix = "Agente_Independente/$([regex]::Escape($nextVer))"
        $shortFolders = @()
        $allFolders = $data.folders | Sort-Object
        $seen = @{}
        foreach ($f in $allFolders) {
            $parts = $f -split '/'
            if ($parts.Count -ge 1) {
                $top = $parts[0]
                if (-not $seen.ContainsKey($top)) {
                    $shortFolders += $top
                    $seen[$top] = $true
                }
            }
        }
        if ($shortFolders.Count -eq 0) {
            # fallback: usa pastas do source_folder
            $shortFolders = $data.folders | Sort-Object
        }

        $chosenFolders = Select-Items "Selecionar Pastas" $shortFolders "Marque as pastas a restaurar:"
        if ($chosenFolders.Count -eq 0) {
            Write-Log "Nenhuma pasta selecionada — restaurando tudo" 'WARN'
            $selectFolders = $false
        }

        # ── Menu 2: Selecionar arquivos? (só se escolheu pastas) ──
        if ($chosenFolders.Count -gt 0) {
            $selFilesResp = [System.Windows.Forms.MessageBox]::Show(
                "Deseja selecionar arquivos específicos dentro das pastas escolhidas?",
                'Selecionar Arquivos', 'YesNo', 'Question'
            )
            if ($selFilesResp -eq 'Yes') {
                $candidateFiles = @()
                foreach ($f in $data.files) {
                    foreach ($cf in $chosenFolders) {
                        if ($f.path -like "$cf/*" -or $f.path -eq $cf) {
                            $candidateFiles += $f.path
                            break
                        }
                    }
                }
                $chosenFiles = Select-Items "Selecionar Arquivos" ($candidateFiles | Sort-Object) "Marque os arquivos a restaurar:"
                if ($chosenFiles.Count -eq 0) {
                    Write-Log "Nenhum arquivo selecionado — restaurando todos das pastas escolhidas" 'WARN'
                }
            }
        }
    }

    # ── Cria pastas ──
    $foldersToCreate = if ($selectFolders -and $chosenFolders.Count -gt 0) {
        $chosenFolders | ForEach-Object {
            $data.folders | Where-Object { $_ -eq $_ -or $_ -like "$_/*" }
        }
    } else { $data.folders }

    foreach ($folder in ($foldersToCreate | Sort-Object -Unique)) {
        $p = Join-Path $dest $folder
        if (!(Test-Path $p)) {
            New-Item $p -ItemType Directory -Force | Out-Null
        }
    }

    # ── Restaura arquivos ──
    $ok = 0; $err = 0; $skip = 0

    $filesToRestore = if ($selectFolders -and $chosenFolders.Count -gt 0) {
        if ($chosenFiles.Count -gt 0) {
            $data.files | Where-Object { $chosenFiles -contains $_.path }
        } else {
            $data.files | Where-Object {
                $matched = $false
                foreach ($cf in $chosenFolders) {
                    if ($_.path -like "$cf/*" -or $_.path -eq $cf) { $matched = $true; break }
                }
                $matched
            }
        }
    } else { $data.files }

    foreach ($file in $filesToRestore) {
        try {
            if (-not $file.path) { Write-Log "'path' ausente — ignorando" 'WARN'; $skip++; continue }

            $invalid = [System.IO.Path]::GetInvalidPathChars()
            if ($file.path.IndexOfAny($invalid) -ge 0) {
                Write-Log "Path inválido: $($file.path) — ignorando" 'WARN'
                $skip++; continue
            }

            $fp = Join-Path $dest $file.path
            $d = Split-Path $fp -Parent
            if (!(Test-Path $d)) { New-Item $d -ItemType Directory -Force | Out-Null }

            $content = if ($file.content) { $file.content } else { '' }

            if ($file.size -and $file.size -gt 0 -and !$flagStrict) {
                $realSize = [System.Text.Encoding]::UTF8.GetByteCount($content)
                if ($realSize -ne $file.size) {
                    Write-Log "Size divergente: $($file.path) — declarado $($file.size), real $realSize" 'WARN'
                }
            }

            [System.IO.File]::WriteAllText($fp, $content, [Text.Encoding]::UTF8)
            Write-Log "OK: $($file.path)" 'SUCCESS'
            $ok++
        }
        catch {
            Write-Log "Falha em $($file.path): $_" 'ERROR'
            $err++
        }
    }

    $msgFinal = "Restaurado: $ok arquivos`nPulados: $skip`nErros: $err`nPasta: $dest"
    [System.Windows.Forms.MessageBox]::Show($msgFinal, 'Restauração Concluída', 'OK', 'Information')
    Write-Log "Final: $ok restaurados, $skip pulados, $err erros" 'SUCCESS'
}
catch {
    Write-Log "ERRO GERAL: $_" 'ERROR'
    [System.Windows.Forms.MessageBox]::Show("Erro: $_", 'Erro', 'OK', 'Error')
}

Read-Host 'Concluído. Enter para sair'