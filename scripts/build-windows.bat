@echo off
REM ============================================================
REM kvmem-llama.cpp - native Windows build launcher
REM
REM Usage:  scripts\build-windows.bat          (configure only)
REM         scripts\build-windows.bat build    (configure + compile)
REM
REM This is a thin wrapper. The real logic lives in build-windows.ps1
REM so that it can be debugged and run directly:
REM   powershell -ExecutionPolicy Bypass -File scripts\build-windows.ps1 -Build
REM ============================================================
setlocal

set "PS1=%~dp0build-windows.ps1"
if not exist "%PS1%" (
    echo ERROR: build-windows.ps1 not found next to this script.
    exit /b 2
)

set "EXTRA="
if /I "%~1"=="build" set "EXTRA=-Build"

powershell -NoProfile -ExecutionPolicy Bypass -File "%PS1%" %EXTRA%
set "RC=%ERRORLEVEL%"
endlocal & exit /b %RC%
