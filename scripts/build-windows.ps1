# ============================================================
# kvmem-llama.cpp - native Windows build (MSVC 2022 + CUDA 13.1)
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File scripts\build-windows.ps1            # configure only
#   powershell -ExecutionPolicy Bypass -File scripts\build-windows.ps1 -Build     # configure + compile
#
# Output: build-win-native\bin\llama-kvmem-server.exe / llama-kvmem-cli.exe
# Re-running is incremental: ninja only rebuilds what changed.
#
# Web UI: the server embeds the stock llama.cpp UI. Two ways to provision it,
# selected by the -D flags in the configure step below:
#   LLAMA_USE_PREBUILT_UI=ON, LLAMA_BUILD_UI=OFF  <- default here: download the
#       prebuilt dist.tar.gz from the ggml-org/llama-ui HF bucket (sha256
#       verified). No node toolchain needed.
#   LLAMA_BUILD_UI=ON                             <- build tools/ui from source
#       with `npm ci && npm run build`. Much slower and needs network to npm.
#
# Exit codes: 0 = ok, 2 = bad repo path, 3 = configure failed, 4 = build failed
# ============================================================

[CmdletBinding()]
param(
    [switch]$Build,
    [switch]$Reconfigure,
    [string]$BuildDir = "build-win-native",
    [string]$Targets  = "llama-kvmem-server llama-kvmem-cli"
)

$ErrorActionPreference = "Continue"

# --- toolchain locations (edit these if your install paths differ) -------------
$VSROOT   = "D:\Program Files\Microsoft Visual Studio\2022\Professional"
$MsvcVer  = "14.44.35207"
$SDK      = "10.0.26100.0"
$CUDAROOT = "C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v13.1"
$CMAKEDIR = "C:\Program Files\CMake\bin"

$repo = Split-Path -Parent $PSScriptRoot
if (-not (Test-Path (Join-Path $repo "CMakeLists.txt"))) {
    Write-Host "ERROR: cannot find repository root (no CMakeLists.txt at $repo)" -ForegroundColor Red
    exit 2
}

# --- sanity-check the toolchain before doing anything --------------------------
$clExe = Join-Path $VSROOT "VC\Tools\MSVC\$MsvcVer\bin\Hostx64\x64\cl.exe"
$nvcc  = Join-Path $CUDAROOT "bin\nvcc.exe"
foreach ($tool in @($clExe, $nvcc)) {
    if (-not (Test-Path $tool)) {
        Write-Host "ERROR: required tool not found: $tool" -ForegroundColor Red
        Write-Host "       Edit the paths at the top of this script." -ForegroundColor Yellow
        exit 3
    }
}

# --- de-duplicate case-variant env vars ---------------------------------------
# HTTP_PROXY vs http_proxy and Path vs PATH both crash the MSVC/.NET build chain
# with MSB6001 "duplicate key". Clearing the proxy vars and rebuilding PATH below
# leaves exactly one spelling of each.
foreach ($v in @("HTTP_PROXY","HTTPS_PROXY","http_proxy","https_proxy","ALL_PROXY","all_proxy")) {
    Remove-Item "Env:$v" -ErrorAction SilentlyContinue
}

$msvcBin = Join-Path $VSROOT "VC\Tools\MSVC\$MsvcVer\bin\Hostx64\x64"
$sdkBin  = "C:\Program Files (x86)\Windows Kits\10\bin\$SDK\x64"

# Rebuild PATH with a single literal spelling so no case-variant duplicate exists.
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

# -Reconfigure re-runs cmake even if build.ninja exists (needed after changing
# -D options) Object files are kept, so only the changed parts rebuild.
$configured = (Test-Path (Join-Path $BuildDir "build.ninja")) -and (-not $Reconfigure)

if (-not $configured) {
    Write-Host "[1/2] Configuring ($BuildDir) ..." -ForegroundColor Cyan
    & cmake -S . -B $BuildDir -G Ninja `
        -DCMAKE_BUILD_TYPE=Release `
        -DCMAKE_C_COMPILER=cl -DCMAKE_CXX_COMPILER=cl `
        -DCMAKE_CUDA_HOST_COMPILER=cl `
        -DCMAKE_CUDA_ARCHITECTURES=120a-real `
        -DGGML_CUDA=ON -DGGML_CUDA_FA_ALL_QUANTS=ON `
        -DLLAMA_BUILD_SERVER=ON -DLLAMA_USE_PREBUILT_UI=ON `
        -DLLAMA_BUILD_UI=OFF
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
    Write-Host "BUILD FAILED (exit $LASTEXITCODE) - see the errors above. Re-run to resume." -ForegroundColor Red
    exit 4
}

Write-Host ""
Write-Host "BUILD OK: $BuildDir\bin\" -ForegroundColor Green
Get-ChildItem (Join-Path $BuildDir "bin") -Filter *.exe -ErrorAction SilentlyContinue |
    ForEach-Object { Write-Host ("  " + $_.Name) }
exit 0
