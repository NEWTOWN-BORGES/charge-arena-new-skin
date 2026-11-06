@echo off
setlocal
echo ===================================================
echo     Charge Arena - Servidor Dedicado Online PvP
echo ===================================================
echo Porta UDP: 27941
echo.

set PORT=27941
if not "%~1"=="" set PORT=%~1

set GODOT_EXE=
if exist "%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.1-stable_win64_console.exe" (
    set "GODOT_EXE=%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.1-stable_win64_console.exe"
) else (
    where godot >nul 2>nul
    if %errorlevel% equ 0 (
        set GODOT_EXE=godot
    )
)

if "%GODOT_EXE%"=="" (
    echo [ERRO] Executavel do Godot nao encontrado!
    echo Instale o Godot 4 ou configure no PATH.
    pause
    exit /b 1
)

echo Iniciando servidor headless na porta UDP %PORT%...
echo Para fechar o servidor, pressione Ctrl+C nesta janela.
echo.

"%GODOT_EXE%" --headless --path "%~dp0.." --script res://scripts/network/server_main.gd -- --port=%PORT%

pause

