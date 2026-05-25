# Garante que o diretório C:\temp existe
New-Item -ItemType Directory -Force -Path 'C:\temp' | Out-Null

# Caminho do arquivo de entrada
$inputFile = 'bootstrap_Agente_Independente_CORRIGIDO_20260509_142000_json.txt'

# Lê o arquivo JSON completo sem truncamento
$jsonContent = Get-Content -Path $inputFile -Raw -Encoding UTF8

# Valida se o JSON é válido
try {
    $null = $jsonContent | ConvertFrom-Json -ErrorAction Stop
} catch {
    Write-Error "JSON inválido no arquivo $inputFile : $($_.Exception.Message)"
    exit 1
}

# Calcula o tamanho exato em bytes UTF-8
$byteSize = [System.Text.Encoding]::UTF8.GetByteCount($jsonContent)

# Salva em arquivo temporário
$outputFile = 'C:\temp\bootstrap_temp.json'
$jsonContent | Out-File -FilePath $outputFile -Encoding UTF8

# Exibe confirmação em VERDE
Write-Host "✅ Arquivo lido com sucesso" -ForegroundColor Green
Write-Host "✅ Tamanho: $byteSize bytes" -ForegroundColor Green
Write-Host "✅ Arquivo temporário criado em: $outputFile" -ForegroundColor Green
Write-Host "✅ Pronto para usar com Create_file.ps1" -ForegroundColor Green