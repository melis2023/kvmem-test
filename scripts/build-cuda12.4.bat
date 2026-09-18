@echo off
REM ============================================================
REM  CUDA 12.4 Build - V100/RTX 20/RTX 30/RTX 40
REM
REM  GPU Support:
REM    - V100/Titan V (sm_70)      - Volta
REM    - RTX 2060/2070/2080 (sm_75) - Turing
REM    - RTX 3060/3070/3080/3090 (sm_86) - Ampere
REM    - RTX 4060/4070/4080/4090 (sm_89) - Ada Lovelace
REM
REM  Usage:    build-cuda12.4.bat
REM  Output:   build-cuda12.4\bin\llama-kvmem-server.exe
REM ============================================================

cd /d "I:\llama\kvmem-llama.cpp-v016\kvmem-test"

echo ============================================================
echo  CUDA 12.4 Build
echo  Current dir: %CD%
echo ============================================================

set "VSROOT=D:\Program Files\Microsoft Visual Studio\2022\Professional"
set "CUDAROOT=C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v12.4"
set "BUILDDIR=build-cuda12.4"

echo [0/3] Setting up MSVC environment...
call "%VSROOT%\VC\Auxiliary\Build\vcvarsall.bat" x64 >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo ERROR: vcvarsall.bat failed
    goto :end
)
echo     OK

echo [1/3] Configuring %BUILDDIR% ...
cmake -S . -B %BUILDDIR% -G Ninja ^
    -DCMAKE_BUILD_TYPE=Release ^
    -DCMAKE_C_COMPILER=cl -DCMAKE_CXX_COMPILER=cl ^
    -DCMAKE_CUDA_HOST_COMPILER=cl ^
    -DCMAKE_CUDA_COMPILER="%CUDAROOT%/bin/nvcc.exe" ^
    -DCUDAToolkit_ROOT="%CUDAROOT%" ^
    -DGGML_CUDA=ON ^
    -DGGML_NATIVE:BOOL=OFF ^
    -DGGML_CUDA_FA_ALL_QUANTS=ON ^
    -DLLAMA_KVMEM=ON

if %ERRORLEVEL% neq 0 (
    echo.
    echo === CONFIGURE FAILED ===
    goto :end
)
echo     OK

echo [2/3] Building ...
cmake --build %BUILDDIR% --config Release -- -j %NUMBER_OF_PROCESSORS%
if %ERRORLEVEL% neq 0 (
    echo.
    echo === BUILD FAILED ===
    goto :end
)

echo.
echo [3/3] BUILD OK
dir /b %BUILDDIR%\bin\*.exe

:end
echo.
echo ============================================================
echo  Press any key to close...
echo ============================================================
pause >nul
