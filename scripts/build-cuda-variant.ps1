# ============================================================
# kvmem-llama.cpp - native Windows build, per-CUDA-version variant
#
# Same flags as scripts\build-windows.ps1 (official Windows flow), but the
# CUDA toolkit and the target architecture list are selected by -CudaVer,
# and the output goes to build-cuda<ver> instead of build-win-native.
#
# Usage (normal CMD / PowerShell, NOT inside an agent session):
#   powershell -ExecutionPolicy Bypass -File scripts\build-cuda-variant.ps1 -CudaVer 13.4
#   powershell -ExecutionPolicy Bypass -File scripts\build-cuda-variant.ps1 -CudaVer 13.4 -Build
#   powershell -ExecutionPolicy Bypass -File scripts\build-cuda-variant.ps1 -CudaVer 12.4 -Build
#
# Output: build-cuda<ver>\bin\llama-kvmem-server.exe / llama-kvmem-cli.exe
# Incremental: ninja only rebuilds what changed (arch changes force full rebuild).
# Exit codes: 0 ok, 2 bad repo path, 3 configure failed, 4 build failed
# ============================================================

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [ValidateSet('12.4','13.1','13.4')]
    [string]$CudaVer,

    [string]$BuildDir  = "",
    [string]$Targets   = "llama-kvmem-server llama-kvmem-cli",
    [string]$Arch      = "",
    [switch]$Build,
    [switch]$Reconfigure,
    [switch]$Clean
)

$ErrorActionPreference = "Continue"

# --- toolchain locations (mirrors build-windows.ps1) ----------------------
$VSROOT   = "D:\Program Files\Microsoft Visual Studio\2022\Professional"
$MsvcVer  = "14.44.35207"
$SDK      = "10.0.26100.0"
$CMAKEDIR = "C:\Program Files\CMake\bin"

# Portable toolkits live in C:\Temp\CUDA; 13.1 is the installed one.
if ($CudaVer -eq '13.1') {
    $CUDAROOT = "C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v13.1"
} else {
    $CUDAROOT = "C:\Temp\CUDA\cuda-$CudaVer-toolkit"
}

# -Arch is OPTIONAL. When it is empty we do NOT pass -DCMAKE_CUDA_ARCHITECTURES
# and we set GGML_NATIVE=OFF, which is exactly upstream llama.cpp's behaviour
# for a portable build (ggml/src/ggml-cuda/CMakeLists.txt lines 27-55):
#
#   CUDA 13.4 -> 75-virtual 80-virtual 86-real 89-real 90-virtual
#                120a-real 121a-real     (Turing .. Blackwell, + JIT fallback)
#   CUDA 12.4 -> 50-virtual 61-virtual 70-virtual 75-virtual 80-virtual
#                86-real 89-real 90-virtual   (Maxwell .. Hopper, no sm_120)
#
# Blackwell sm_120 needs CUDA >= 12.8, so a 12.4 build can never contain
# native Blackwell code; it can still run there via PTX JIT (90-virtual).
# Pass -Arch explicitly only if you want to narrow the targets.

if ([string]::IsNullOrWhiteSpace($BuildDir)) { $BuildDir = "build-cuda$CudaVer" }

$repo = Split-Path -Parent $PSScriptRoot
if (-not (Test-Path (Join-Path $repo "CMakeLists.txt"))) {
    Write-Host "ERROR: cannot find repository root (no CMakeLists.txt at $repo)" -ForegroundColor Red
    exit 2
}

# --- sanity-check the toolchain ------------------------------------------
$clExe = Join-Path $VSROOT "VC\Tools\MSVC\$MsvcVer\bin\Hostx64\x64\cl.exe"
$nvcc  = Join-Path $CUDAROOT "bin\nvcc.exe"
foreach ($tool in @($clExe, $nvcc)) {
    if (-not (Test-Path $tool)) {
        Write-Host "ERROR: required tool not found: $tool" -ForegroundColor Red
        exit 3
    }
}

# --- de-duplicate case-variant env vars (crashes MSBuild with MSB6001) ---
foreach ($v in @("HTTP_PROXY","HTTPS_PROXY","http_proxy","https_proxy","ALL_PROXY","all_proxy")) {
    Remove-Item "Env:$v" -ErrorAction SilentlyContinue
}

$msvcBin = Join-Path $VSROOT "VC\Tools\MSVC\$MsvcVer\bin\Hostx64\x64"
$sdkBin  = "C:\Program Files (x86)\Windows Kits\10\bin\$SDK\x64"

$oldPath = $env:Path
Remove-Item Env:Path -ErrorAction SilentlyContinue
$env:Path = @($msvcBin, (Join-Path $CUDAROOT "bin"), $CMAKEDIR, $sdkBin, $oldPath) -join ";"

$env:INCLUDE = @(
    (Join-Path $VSROOT "VC\Tools\MSVC\$MsvcVer\include"),
    "C:\Program Files (x86)\Windows Kits\10\Include\$SDK\ucrt",
    "C:\Program Files (x86)\Windows Kits\10\Include\$SDK\shared",
    "C:\Program Files (x86)\Windows Kits\10\Include\$SDK\um",
    "C:\Program Files (x86)\Windows Kits\10\Include\$SDK\winrt",
    "C:\Program Files (x86)\Windows Kits\10\Include\$SDK\cppwinrt"
) -join ";"

$env:LIB = @(
    (Join-Path $VSROOT "VC\Tools\MSVC\$MsvcVer\lib\x64"),
    "C:\Program Files (x86)\Windows Kits\10\Lib\$SDK\ucrt\x64",
    "C:\Program Files (x86)\Windows Kits\10\Lib\$SDK\um\x64"
) -join ";"

$env:CUDA_PATH = $CUDAROOT
$env:CUDACXX   = $nvcc

Set-Location $repo

if ([string]::IsNullOrWhiteSpace($Arch)) {
    $mode = "upstream default (-DGGML_NATIVE=OFF, no arch override)"
} else {
    $mode = "explicit arch=$Arch"
}
Write-Host "== CUDA $CudaVer  ->  $BuildDir   $mode" -ForegroundColor Cyan

# A cached CMAKE_CUDA_ARCHITECTURES counts as DEFINED, so switching to the
# upstream default requires dropping the cache first (-Clean), otherwise the
# old explicit list silently stays in effect.
$cacheFile = Join-Path $BuildDir "CMakeCache.txt"
if ($Clean -and (Test-Path $cacheFile)) {
    Write-Host "    -Clean: removing $cacheFile (forces full reconfigure)" -ForegroundColor Yellow
    Remove-Item $cacheFile -Force
    Remove-Item (Join-Path $BuildDir "CMakeFiles") -Recurse -Force -ErrorAction SilentlyContinue
}

$configured = (Test-Path (Join-Path $BuildDir "build.ninja")) -and (-not $Reconfigure) -and (-not $Clean)

if (-not $configured) {
    Write-Host "[1/2] Configuring ($BuildDir) ..." -ForegroundColor Cyan
    $cmakeArgs = @(
        "-S", ".", "-B", $BuildDir, "-G", "Ninja",
        "-DCMAKE_BUILD_TYPE=Release",
        "-DCMAKE_C_COMPILER=cl", "-DCMAKE_CXX_COMPILER=cl",
        "-DCMAKE_CUDA_HOST_COMPILER=cl",
        "-DGGML_NATIVE=OFF",
        "-DGGML_CUDA=ON", "-DGGML_CUDA_FA_ALL_QUANTS=ON",
        "-DLLAMA_BUILD_SERVER=ON", "-DLLAMA_USE_PREBUILT_UI=ON",
        "-DLLAMA_BUILD_UI=OFF"
    )
    # Upstream release.yml sets this only for the 12.x job (temporary flag
    # until CCCL/CUB 3.2 is bundled); 13.x does not need it.
    if ($CudaVer -eq '12.4') { $cmakeArgs += "-DGGML_CUDA_CUB_3DOT2=ON" }
    if (-not [string]::IsNullOrWhiteSpace($Arch)) {
        $cmakeArgs += "-DCMAKE_CUDA_ARCHITECTURES=$Arch"
    }
    & cmake @cmakeArgs
    if ($LASTEXITCODE -ne 0) {
        Write-Host "CONFIGURE FAILED (exit $LASTEXITCODE)" -ForegroundColor Red
        exit 3
    }
} else {
    Write-Host "[1/2] Existing configuration found, skipping configure." -ForegroundColor Cyan
}

if (-not $Build) {
    Write-Host ""
    Write-Host "Configure-only run finished. Re-run with -Build to compile." -ForegroundColor Yellow
    exit 0
}

Write-Host "[2/2] Building $Targets ..." -ForegroundColor Cyan
$jobs = if ($env:NUMBER_OF_PROCESSORS) { $env:NUMBER_OF_PROCESSORS } else { "8" }
& cmake --build $BuildDir --target @($Targets.Split(" ")) -- -j $jobs
if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "BUILD FAILED (exit $LASTEXITCODE) - see errors above. Re-run to resume." -ForegroundColor Red
    exit 4
}

Write-Host ""
Write-Host "BUILD OK: $BuildDir\bin\" -ForegroundColor Green
Get-ChildItem (Join-Path $BuildDir "bin") -Filter *.exe -ErrorAction SilentlyContinue |
    ForEach-Object { Write-Host ("  " + $_.Name) }
exit 0
