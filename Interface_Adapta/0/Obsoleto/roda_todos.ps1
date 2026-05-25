$scripts = @(
    'capture-screen.js',
    'audio-listener.js',
    'interaction-handler.js',
    'sync-engine.js'
)

foreach ($script in $scripts) {
    Write-Host "Iniciando $script..."
    & node $script
    Start-Sleep -Seconds 2
}

Write-Host "Todos os scripts foram iniciados!"