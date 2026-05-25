# bootstrap_v2.ps1 — Geração limpa: só texto, sem binários, sem cache
Add-Type -AssemblyName System.Windows.Forms

function Write-Log($m,$l='INFO'){Write-Host "[$(Get-Date -f 'HH:mm:ss') $l] $m"}

# Whitelist de extensões de texto
$textExtensions = @(
    '.ps1','.psm1','.psd1','.bat','.cmd','.py','.pyw',
    '.json','.xml','.yaml','.yml','.toml','.ini','.cfg','.env',
    '.txt','.md','.rst','.log',
    '.html','.htm','.js','.css','.scss','.ts','.jsx','.tsx','.vue',
    '.sql','.csv','.tsv',
    '.ps1xml','.clixml',
    '.gradle','.properties',
    '.gitignore','.dockerfile','.editorconfig',
    '.sh','.bash','.zsh','.fish'
)

# Pastas a ignorar completamente
$ignoreFolders = @(
    '__pycache__','.git','.svn','.hg',
    'node_modules','.venv','venv','.env',
    '.pytest_cache','.mypy_cache','.ruff_cache',
    'obj','bin','debug','release',
    '.vs','.vscode','.idea',
    'dist','build','.next','.nuxt',
    '__MACOSX'
)

# Extensões explicitamente ignoradas (binários)
$ignoreExtensions = @(
    '.lnk','.exe','.dll','.so','.dylib','.bin',
    '.pyc','.pyo','.pyd',
    '.jpg','.jpeg','.png','.gif','.bmp','.ico','.svg','.webp',
    '.pdf','.doc','.docx','.xls','.xlsx','.ppt','.pptx',
    '.zip','.rar','.7z','.tar','.gz','.bz2',
    '.db','.sqlite','.sqlite3',
    '.ttf','.otf','.woff','.woff2','.eot',
    '.mp3','.mp4','.avi','.mov','.wav','.flac',
    '.iso','.img',
    '.o','.a','.lib','.obj',
    '.pdb','.idb','.ilk'
)

$maxFileSize = 5 * 1024 * 1024  # 5MB

function Test-IsTextFile {
    param($path)
    $ext = [System.IO.Path]::GetExtension($path).ToLowerInvariant()
    if ($ext -eq '') { return $true }  # sem extensão, tenta ler
    if ($textExtensions -contains $ext) { return $true }
    if ($ignoreExtensions -contains $ext) { return $false }
    # Extensão desconhecida: testa conteúdo
    try {
        $bytes = New-Object byte[] 512
        $fs = [System.IO.File]::OpenRead($path)
        $read = $fs.Read($bytes, 0, 512)
        $fs.Close()
        # Se tiver byte nulo nos primeiros 512 bytes, é binário
        if ($bytes[0..($read-1)] -contains 0) { return $false }
        return $true
    } catch { return $false }
}

try {
    $f = New-Object System.Windows.Forms.FolderBrowserDialog
    $f.Description = 'Selecione a pasta origem'
    if ($f.ShowDialog() -ne 'OK') { exit }
    $src = $f.SelectedPath
    $pName = Split-Path $src -Leaf

    Write-Log "Escaneando $src..."

    $folders = @(); $files = @()
    $skipped = @{folders=0; binary=0; size=0; total=0}

    # Primeiro coleta pastas (pulando as ignoradas)
    Get-ChildItem $src -Recurse -Directory | ForEach-Object {
        $skip = $false
        $p = $_.FullName
        foreach ($ig in $ignoreFolders) {
            if ($p -match [regex]::Escape($ig)) { $skip = $true; break }
        }
        if (-not $skip) {
            $folders += $p.Substring($src.Length + 1)
        } else {
            $skipped.folders++
        }
    }

    # Depois coleta arquivos (filtrando)
    Get-ChildItem $src -Recurse -File | ForEach-Object {
        $rel = $_.FullName.Substring($src.Length + 1)

        # Pula se estiver em pasta ignorada
        foreach ($ig in $ignoreFolders) {
            if ($rel -match [regex]::Escape($ig)) { $skipped.folders++; return }
        }

        # Pula se for binário
        if (-not (Test-IsTextFile $_.FullName)) {
            Write-Log "  [BIN] $rel" 'WARN'; $skipped.binary++; return
        }

        # Pula se for grande demais
        if ($_.Length -gt $maxFileSize) {
            Write-Log "  [GRANDE] $rel ($($_.Length) bytes)" 'WARN'; $skipped.size++; return
        }

        try {
            $c = [System.IO.File]::ReadAllText($_.FullName, [Text.Encoding]::UTF8)
            # Remove bytes nulos do conteúdo (segurança extra)
            $c = $c -replace "`0", ''
            $sz = [System.Text.Encoding]::UTF8.GetByteCount($c)
            $files += @{path=$rel; content=$c; size=$sz}
            Write-Log "  $rel ($sz bytes)"
        } catch {
            Write-Log "  [ERRO] $rel : $_" 'ERROR'; $skipped.total++
        }
    }

    $out = @{
        created_date = (Get-Date -f 'yyyy-MM-dd HH:mm:ss')
        version = '1.0.0'
        project_name = $pName
        files = $files
        source_folder = $src
        ignore_mode = $false
        folders = $folders
    }

    Write-Log "---" 'INFO'
    Write-Log "Pastas ignoradas: $($skipped.folders)" 'INFO'
    Write-Log "Arquivos binários ignorados: $($skipped.binary)" 'INFO'
    Write-Log "Arquivos grandes ignorados: $($skipped.size)" 'INFO'
    Write-Log "Erros de leitura: $($skipped.total)" 'INFO'
    Write-Log "Total de arquivos no JSON: $($files.Count)" 'SUCCESS'

    $sf = New-Object System.Windows.Forms.SaveFileDialog
    $sf.Filter = 'JSON|*.json'
    $sf.FileName = "bootstrap_$pName.json"
    if ($sf.ShowDialog() -eq 'OK') {
        $json = $out | ConvertTo-Json -Depth 10
        [System.IO.File]::WriteAllText($sf.FileName, "# bootstrap_$pName.json`r`n$json", [Text.Encoding]::UTF8)
        Write-Log "Salvo: $($sf.FileName)" 'SUCCESS'
    }

} catch {
    Write-Log "ERRO: $_" 'ERROR'
    [System.Windows.Forms.MessageBox]::Show("Erro: $_", 'Erro', 'OK', 'Error')
}

Read-Host 'Concluído. Enter para sair'