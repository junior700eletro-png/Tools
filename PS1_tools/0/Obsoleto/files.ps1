# salvar_arquivo.ps1
$ErrorActionPreference = 'Stop'
$baseDir = "C:\Users\$env:USERNAME\Desktop\Scripts_Adapta"
if (!(Test-Path $baseDir)) { New-Item -ItemType Directory -Path $baseDir | Out-Null }
$logPath = Join-Path $baseDir "salvar_arquivo_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
function Write-Log { param([string]$Message, [string]$Color='White') Write-Host $Message -ForegroundColor $Color; Add-Content -Path $logPath -Value "[$((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))] $Message" }
try {
    $clip = Get-Clipboard
    $lines = $clip -split "`r`n"
    if ($lines[0].Trim() -notmatch '^#\s+(.+\..+)$') { throw "Primeira linha deve ser: # arquivo.ext" }
    $filename = $matches[1]
    $fullPath = Join-Path $baseDir $filename
    $content = $lines[1..($lines.Count-1)] -join "`r`n"
    $processed = @("# PATH ABSOLUTO: $fullPath")
    foreach ($line in ($content -split "`r`n")) {
        $t = $line.TrimStart()
        if (!($t.StartsWith('#') -or $t.StartsWith(';') -or $t.StartsWith('//'))) { $processed += $line }
    }
    if (Test-Path $fullPath) {
        $obs = Join-Path $baseDir '.obsoleto'
        if (!(Test-Path $obs)) { $di = New-Item -ItemType Directory -Path $obs -Force; $di.Attributes = 'Hidden' }
        $ext = [System.IO.Path]::GetExtension($filename)
        $base = [System.IO.Path]::GetFileNameWithoutExtension($filename)
        $c = 1; do { $bkp = Join-Path $obs "${base}_V$c$ext"; $c++ } while (Test-Path $bkp)
        Copy-Item $fullPath $bkp
        Write-Log "Backup criado: $bkp" Yellow
    }
    Set-Content -Path $fullPath -Value ($processed -join "`r`n") -Encoding UTF8
    Write-Log "Arquivo salvo: $fullPath" Green
} catch { Write-Log "ERRO: $_" Red }
