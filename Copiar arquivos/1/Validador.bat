@echo off
Powershell -ExecutionPolicy Bypass -File "C:\Users\user\Desktop\Tools\Copiar arquivos\Script1_Gerador_JSON.ps1"
pause
Powershell -ExecutionPolicy Bypass -File "C:\Users\user\Desktop\Tools\Copiar arquivos\Create_file.ps1"
puse
Powershell -ExecutionPolicy Bypass -File "C:\Users\user\Desktop\Tools\Copiar arquivos\Script2_Validador_JSON.ps1"
pause