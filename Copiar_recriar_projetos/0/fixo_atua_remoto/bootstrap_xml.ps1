Add-Type -AssemblyName System.Windows.Forms

function BytesToHex { param([byte[]]$Bytes)
  return ($Bytes | ForEach-Object { $_.ToString("X2") }) -join "" }

$fbd = New-Object FolderBrowserDialog
$fbd.Description = "Selecione a pasta do projeto"
if ($fbd.ShowDialog() -ne "OK") { exit }; $src = $fbd.SelectedPath; $proj = Split-Path $src -Leaf

if (!(Test-Path "$env:LOCALAPPDATA\estruturas_XML")) { New-Item "$env:LOCALAPPDATA\estruturas_XML" -Force | Out-Null }

$savedlg = New-Object SaveFileDialog
$savedlg.InitialDirectory = "$env:LOCALAPPDATA\estruturas_XML"
$savedlg.Filter = "XML|*.xml"
$savedlg.FileName = "bootstrap_${proj}_$(Get-Date -Format 'yyyyMMddHHmmss').xml"
if ($savedlg.ShowDialog() -ne "OK") { exit }; $out = $savedlg.FileName

$folders = Get-ChildItem $src -Directory -Recurse |
  ForEach-Object { $_.FullName.Substring($src.Length).TrimStart('\') } | Sort-Object
$allFiles = Get-ChildItem $src -File -Recurse

$settings = New-Object System.Xml.XmlWriterSettings
$settings.Indent = $true; $settings.IndentChars = '  '
$settings.Encoding = New-Object System.Text.UTF8Encoding $false
$settings.NewLineHandling = [System.Xml.NewLineHandling]::None

$w = [System.Xml.XmlWriter]::Create($out, $settings)
$w.WriteStartDocument()
$w.WriteStartElement('project')
$w.WriteAttributeString('name', $proj)
$w.WriteAttributeString('created', (Get-Date -Format 'o'))
$w.WriteAttributeString('version', '1.0')

$w.WriteStartElement('folders')
foreach ($f in $folders) { $w.WriteElementString('folder', $f) }
$w.WriteEndElement()

$w.WriteStartElement('files')
$count = 0

foreach ($f in $allFiles) {
  $rel = $f.FullName.Substring($src.Length).TrimStart('\')
  $bytes = [System.IO.File]::ReadAllBytes($f.FullName)
  $hashRef = (Get-FileHash $f.FullName -Algorithm SHA256).Hash.ToUpper()
  $hex = BytesToHex -Bytes $bytes
  $w.WriteStartElement('file')
  $w.WriteAttributeString('path', $rel)
  $w.WriteAttributeString('hash', "sha256:$hashRef")
  $w.WriteAttributeString('encoding', 'hex')
  $w.WriteElementString('hex', $hex)
  $w.WriteEndElement()
  $count++
}

$w.WriteEndElement(); $w.WriteEndElement(); $w.WriteEndDocument(); $w.Close()

Write-Host "OK: $count arquivos" -ForegroundColor Green
Write-Host "XML: $out" -ForegroundColor Cyan
[System.Windows.Forms.MessageBox]::Show("$count arquivos capturados.`n$out", "Sucesso")
Read-Host "Enter para sair"