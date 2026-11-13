@echo off
setlocal
cd /d "%~dp0"

rem Override this if Godot is installed elsewhere:
rem   set GODOT_EXE=C:\Godot\Godot_v4.7.2-stable_mono_win64_console.exe
if not defined GODOT_EXE set "GODOT_EXE=D:\Godot\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64_console.exe"

if not exist "%~dp0godot\project.godot" (
    echo [ERROR] Godot project not found: "%~dp0godot\project.godot"
    pause
    exit /b 1
)

if not exist "%GODOT_EXE%" (
    where godot >nul 2>nul
    if errorlevel 1 (
        echo [ERROR] Godot executable not found.
        echo Set GODOT_EXE to the Godot executable path, for example:
        echo   set GODOT_EXE=C:\Godot\Godot_v4.7.2-stable_mono_win64_console.exe
        pause
        exit /b 1
    )
    for /f "delims=" %%G in ('where godot') do set "GODOT_EXE=%%G"
)

echo Starting Godot project...
echo   Project: %~dp0godot
echo   Godot:   %GODOT_EXE%
echo.

"%GODOT_EXE%" --path "%~dp0godot" %*
if errorlevel 1 (
    echo.
    echo [ERROR] Godot exited with an error.
    pause
    exit /b 1
)

endlocal
