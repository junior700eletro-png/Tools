@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "& { .\"%~dp0criar_projeto.ps1\" %* }"
pause