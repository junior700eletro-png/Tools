# restore_xml.ps1 - Restaura projeto do XML (formato hex)

Add-Type -AssemblyName System.Windows.Forms

function HexToBytes { param([string]$Hex)
  $len = $Hex.Length; $bytes = [byte[]]::new($len / 2)
  for ($i = 0; $i -lt $len; $i += 2) {
    $bytes[$i / 2] = [Convert]::ToByte($Hex.Substring($i, 2), 16) }
  return $bytes }

$ofd = New-Object System.Windows.Forms.OpenFileDialog
$ofd.InitialDirectory = "$env:LOCALAPPDATA\estruturas_XML"
$ofd.Filter = "XML|*.xml"
$ofd.Title = "Selecione o bootstrap XML"
if ($ofd.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) { exit }
$xmlPath = $ofd.FileName

try { [xml]$xml = Get-Content $xmlPath -Raw -Encoding UTF8 }
catch { [System.Windows.Forms.MessageBox]::Show("Erro: $_", "Erro"); Read-Host; exit }

$projName = $xml.project.name
if ([string]::IsNullOrWhiteSpace($projName)) { $projName = [IO.Path]::GetFileNameWithoutExtension($xmlPath) }

$fbd = New-Object System.Windows.Forms.FolderBrowserDialog
$fbd.Description = "Pasta de destino para '$projName'"
$fbd.SelectedPath = "$env:LOCALAPPDATA\estruturas_XML"
if ($fbd.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) { exit }
$dest = $fbd.SelectedPath

Write-Host "Criando pastas..." -ForegroundColor Cyan
foreach ($folder in $xml.project.folders.folder) {
  New-Item -ItemType Directory -Path (Join-Path $dest $folder.InnerText) -Force | Out-Null }

$ok = 0; $falha = 0
Write-Host "`nProcessando arquivos..." -ForegroundColor Cyan

foreach ($file in $xml.project.files.file) {
  $rel = $file.GetAttribute("path")
  $storedHash = $file.GetAttribute("hash")
  $encoding = $file.GetAttribute("encoding")
  $fullPath = Join-Path $dest $rel
  $dir = Split-Path $fullPath -Parent
  if (!(Test-Path $dir)) { New-Item $dir -Force | Out-Null }

  try {
    if ($encoding -ne "hex") { throw "Encoding desconhecido: $encoding em $rel" }
    $hex = $file.hex
    $bytes = HexToBytes -Hex $hex
    [System.IO.File]::WriteAllBytes($fullPath, $bytes)

    $newHash = "sha256:$((Get-FileHash $fullPath -Algorithm SHA256).Hash.ToUpper())"
    if ($newHash -eq $storedHash) {
      Write-Host "  [OK] $rel" -ForegroundColor Green; $ok++ }
    else {
      Write-Host "  [FALHA HASH] $rel" -ForegroundColor Red
      Write-Host "    esperado: $storedHash`n    obtido:   $newHash" -ForegroundColor Gray; $falha++ }
  } catch {
    Write-Host "  [ERRO] $rel : $_" -ForegroundColor Red; $falha++ }
}

Write-Host "`nOK: $ok | Falhas: $falha" -ForegroundColor $(if ($falha -eq 0) {'Green'} else {'Red'})
if ($falha -eq 0) { [System.Windows.Forms.MessageBox]::Show("$ok arquivos restaurados em:`n$dest", "Sucesso") }
else { [System.Windows.Forms.MessageBox]::Show("$ok OK | $falha falhas", "Resultado") }
Read-Host "Enter para sair"