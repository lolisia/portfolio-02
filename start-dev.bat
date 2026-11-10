@echo off
setlocal
cd /d "%~dp0"

where node >nul 2>nul
if errorlevel 1 (
    echo [ERROR] Node.js is required. Install Node.js and try again.
    pause
    exit /b 1
)

where npm >nul 2>nul
if errorlevel 1 (
    echo [ERROR] npm was not found. Check your Node.js installation.
    pause
    exit /b 1
)

if not exist "node_modules\vite\bin\vite.js" (
    echo Installing dependencies...
    call npm ci
    if errorlevel 1 (
        echo [ERROR] Failed to install dependencies.
        pause
        exit /b 1
    )
)

echo Starting development server. Press Ctrl+C to stop.
call npm run dev -- --host 127.0.0.1 %*
if errorlevel 1 (
    echo [ERROR] The development server stopped with an error.
    pause
    exit /b 1
)
endlocal
