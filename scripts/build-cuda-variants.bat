@echo off
rem ============================================================
rem  Build distributable CUDA variants of kvmem-llama.cpp (native Windows)
rem  Uses UPSTREAM llama.cpp arch selection: no -DCMAKE_CUDA_ARCHITECTURES
rem  override plus -DGGML_NATIVE=OFF, so CMake picks the portable list.
rem
rem   build-cuda13.4 : 75v 80v 86r 89r 90v 120a-r 121a-r
rem                    -> Turing / Ampere(30xx) / Ada(40xx) / Blackwell(50xx)
rem                    -> needs a driver new enough for the CUDA 13.4 runtime
rem   build-cuda12.4 : 50v 61v 70v 75v 80v 86r 89r 90v
rem                    -> Maxwell .. Hopper; runs on Blackwell only via PTX JIT
rem                    -> works with much older drivers
rem
rem  -Clean drops the old CMakeCache (the previous explicit arch lists would
rem  otherwise stay in effect). That means a FULL rebuild: 30-60 min each.
rem  Drop -Clean from the command if you want an incremental build instead.
rem
rem  Run from a normal CMD window, NOT inside an agent session
rem  (docs\windows.md section 2.5: duplicate env vars crash MSBuild/MSB6001).
rem ============================================================
setlocal
set "PS=powershell -ExecutionPolicy Bypass -File"
set "SCRIPT=%~dp0build-cuda-variant.ps1"

echo.
echo ==== [1/2] CUDA 13.4  -^> build-cuda13.4 (portable: 20/30/40/50 series) ====
%PS% "%SCRIPT%" -CudaVer 13.4 -Build -Clean
if errorlevel 1 goto failed

echo.
echo ==== [2/2] CUDA 12.4  -^> build-cuda12.4 (portable: Maxwell..Hopper) ====
%PS% "%SCRIPT%" -CudaVer 12.4 -Build -Clean
if errorlevel 1 goto failed

echo.
echo ALL BUILDS OK
pause
exit /b 0

:failed
echo.
echo BUILD FAILED - see the errors above.
pause
exit /b 1
