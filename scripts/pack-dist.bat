@echo off
rem ============================================================
rem  Pack a built CUDA variant into a redistributable folder.
rem
rem  Usage:
rem    pack-dist.bat 12.4
rem    pack-dist.bat 12.4 -Zip
rem    pack-dist.bat 12.4 -Zip -Verify
rem
rem  Output:
rem    dist-cuda12.4\          merged, runs on a PC with no CUDA installed
rem    cudart-dist-cuda12.4\   official style: only the 3 CUDA runtime dlls
rem
rem  Run from a normal CMD window (docs\windows.md 2.5).
rem ============================================================
setlocal
if "%~1"=="" (
  echo.
  echo Usage: pack-dist.bat ^<12.4^|13.1^|13.4^> [-Zip] [-Verify]
  echo.
  pause
  exit /b 1
)
set "VER=%~1"
shift
set "EXTRA=%1 %2 %3"
powershell -ExecutionPolicy Bypass -File "%~dp0pack-dist.ps1" -CudaVer %VER% %EXTRA%
if errorlevel 1 goto failed
echo.
pause
exit /b 0

:failed
echo.
echo PACK FAILED - see the errors above.
pause
exit /b 1
