
$inputFile = "bootstrap_Agente_Independente_CORRIGIDO_20260509_142000_json.txt"
$outputFile = "C:\temp\bootstrap_Agente_Independente_CORRIGIDO_COMPLETO.json"

New-Item -ItemType Directory -Path "C:\temp" -Force | Out-Null

if (-not (Test-Path $inputFile)) {
    Write-Error "Arquivo de entrada não encontrado: $inputFile"
    exit 1
}

try {
    $jsonContent = Get-Content $inputFile -Raw -Encoding UTF8
    $data = $jsonContent | ConvertFrom-Json
} catch {
    Write-Error "Falha ao fazer parse do JSON: $($_.Exception.Message)"
    exit 1
}

if ($data -isnot [array]) {
    $data = @($data)
}

$missingCounts = @{}
$requiredFields = @('hash_sha256', 'timestamp', 'permissions', 'extension', 'encoding')

foreach ($item in $data) {
    foreach ($field in $requiredFields) {
        if (-not ($item.PSObject.Properties.Name -contains $field)) {
            if (-not $missingCounts.ContainsKey($field)) { $missingCounts[$field] = 0 }
            $missingCounts[$field]++

            switch ($field) {
                'hash_sha256' {
                    $hashValue = '0000000000000000000000000000000000000000000000000000000000000000'
                    if ($item.PSObject.Properties['content']) {
                        $bytes = [System.Text.Encoding]::UTF8.GetBytes($item.content)
                        $sha256 = [System.Security.Cryptography.SHA256]::Create()
                        $hashBytes = $sha256.ComputeHash($bytes)
                        $hashValue = [System.BitConverter]::ToString($hashBytes) -replace '-', ''
                        $sha256.Dispose()
                    }
                    $item | Add-Member -MemberType NoteProperty -Name 'hash_sha256' -Value $hashValue
                }
                'timestamp' {
                    $item | Add-Member -MemberType NoteProperty -Name 'timestamp' -Value (Get-Date -Format "yyyy-MM-ddTHH:mm:ss.fffZ")
                }
                'permissions' {
                    $item | Add-Member -MemberType NoteProperty -Name 'permissions' -Value '0644'
                }
                'extension' {
                    $ext = ''
                    if ($item.PSObject.Properties['name']) {
                        $ext = [System.IO.Path]::GetExtension($item.name)
                    }
                    $item | Add-Member -MemberType NoteProperty -Name 'extension' -Value $ext
                }
                'encoding' {
                    $item | Add-Member -MemberType NoteProperty -Name 'encoding' -Value 'UTF-8'
                }
            }
        }
    }
}

totalCount = $data.Count
totalSize = 0
if ($data | Where-Object { $_.PSObject.Properties['size'] }) {
    $totalSize = ($data | ForEach-Object { [long]($_.size ?? 0) } | Measure-Object -Sum).Sum
}

$globalMeta = @{
    generated_at = Get-Date -Format "yyyy-MM-ddTHH:mm:ss.fffZ"
    total_items = $totalCount
    total_size_bytes = $totalSize
    fields_fixed_count = $missingCounts
}

$completeData = @{
    metadata = $globalMeta
    items = $data
}

$completeJson = $completeData | ConvertTo-Json -Depth 20
$completeJson | Out-File -FilePath $outputFile -Encoding UTF8 -NoNewline

Write-Host "\n=== RELATÓRIO DO CORRIGIDOR JSON ===" -ForegroundColor Green
Write-Host "Arquivo lido: $inputFile" -ForegroundColor Green
Write-Host "JSON salvo em: $outputFile" -ForegroundColor Green
Write-Host "Total de itens: $totalCount" -ForegroundColor Green
Write-Host "Itens com campos adicionados:" -ForegroundColor Green
foreach ($field in $requiredFields) {
    $count = $missingCounts[$field] ?? 0
    Write-Host "  $field : $count" -ForegroundColor Green
}
Write-Host "Metadados globais calculados." -ForegroundColor Green
Write-Host "Concluído com sucesso!" -ForegroundColor Green