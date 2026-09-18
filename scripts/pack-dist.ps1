# ============================================================
# pack-dist.ps1 - assemble a redistributable package
#
# Mirrors upstream llama.cpp (.github/workflows/release.yml lines 1046-1066):
#   main zip   : build-cuda<ver>\bin\*.exe + *.dll   (+ VC runtime)
#   cudart zip : cudart64_*.dll cublas64_*.dll cublasLt64_*.dll
#                taken from the CUDA toolkit that produced the build
# Both are ALSO merged into <OutDir>, so you can just rar the folder and
# hand it to someone who has no CUDA installed at all.
#
# Usage (normal CMD):
#   powershell -ExecutionPolicy Bypass -File scripts\pack-dist.ps1 -CudaVer 12.4
#   powershell -ExecutionPolicy Bypass -File scripts\pack-dist.ps1 -CudaVer 12.4 -Zip
#   powershell -ExecutionPolicy Bypass -File scripts\pack-dist.ps1 -CudaVer 12.4 -Verify
#
# Exit codes: 0 ok, 2 no build output, 3 CUDA dlls not found
# ============================================================

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [ValidateSet('12.4','13.1','13.4')]
    [string]$CudaVer,

    [string]$OutDir     = "",
    [string]$CudaDllSrc = "",
    [switch]$Zip,
    [switch]$Verify,
    [switch]$NoVCRedist
)

$ErrorActionPreference = "Stop"

$repo = Split-Path -Parent $PSScriptRoot
$bin  = Join-Path $repo "build-cuda$CudaVer\bin"

if (-not (Test-Path $bin)) {
    Write-Host "ERROR: $bin not found - build the variant first." -ForegroundColor Red
    exit 2
}
if ([string]::IsNullOrWhiteSpace($OutDir)) { $OutDir = Join-Path $repo "dist-cuda$CudaVer" }

Write-Host "== pack-dist: CUDA $CudaVer  ->  $OutDir" -ForegroundColor Cyan

# --- 0. sanity: did the build actually finish? --------------------------
$exes = @(Get-ChildItem $bin -Filter *.exe -ErrorAction SilentlyContinue)
if ($exes.Count -eq 0) {
    Write-Host ""
    Write-Host "WARNING: no .exe in $bin" -ForegroundColor Yellow
    Write-Host "         The previous build did not finish (it stopped inside the"
    Write-Host "         fattn template instances). Only .dll files will be packed."
    Write-Host "         Re-run scripts\build-cuda-variant.ps1 -CudaVer $CudaVer -Build -Clean"
    Write-Host "         before packing a real release." -ForegroundColor Yellow
} else {
    Write-Host ("   binaries: " + ($exes.Name -join ", "))
}

# --- 1. locate the CUDA runtime dlls ------------------------------------
#   The portable toolkits in C:\Temp\CUDA only carry cudart (no cublas),
#   so for 12.4 / 13.1 we take them from the installed toolkit instead.
if ([string]::IsNullOrWhiteSpace($CudaDllSrc)) {
    switch ($CudaVer) {
        '12.4' { $CudaDllSrc = "C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v12.4\bin" }
        '13.1' { $CudaDllSrc = "C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v13.1\bin" }
        '13.4' { $CudaDllSrc = "C:\Temp\CUDA\v13.4.1" }
    }
}

$dllNames = @('cudart64_*.dll','cublas64_*.dll','cublasLt64_*.dll')

function Find-CudaDlls([string]$root, [string[]]$names) {
    if (-not (Test-Path $root)) { return @() }
    $found = @()
    foreach ($n in $names) {
        $hit = @(Get-ChildItem -Path $root -Filter $n -File -ErrorAction SilentlyContinue | Select-Object -First 1)
        if ($hit.Count -eq 0) {
            # installer payload layout (CUDARuntimes\...\bin) - search one level down
            $hit = @(Get-ChildItem -Path $root -Recurse -Filter $n -File -ErrorAction SilentlyContinue |
                     Sort-Object Length -Descending | Select-Object -First 1)
        }
        if ($hit.Count -gt 0) { $found += $hit[0] }
    }
    return $found
}

$cudaDlls = Find-CudaDlls $CudaDllSrc $dllNames

if ($cudaDlls.Count -lt 3) {
    Write-Host ""
    Write-Host "NOTE: only $($cudaDlls.Count)/3 CUDA runtime dlls found under:" -ForegroundColor Yellow
    Write-Host "      $CudaDllSrc" -ForegroundColor Yellow
    if ($CudaVer -eq '13.4') {
        Write-Host "      Falling back to the installed v13.1 runtime ..." -ForegroundColor Yellow
        $fallback = "C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v13.1\bin"
        $cudaDlls = Find-CudaDlls $fallback $dllNames
        if ($cudaDlls.Count -ge 3) { $CudaDllSrc = $fallback }
    }
}
if ($cudaDlls.Count -eq 0) {
    Write-Host "ERROR: no CUDA runtime dlls found anywhere. Pass -CudaDllSrc <dir>." -ForegroundColor Red
    exit 3
}

# --- 2. main package ----------------------------------------------------
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

foreach ($pat in @('*.exe','*.dll','*.bat')) {
    Get-ChildItem -Path $bin -Filter $pat -File -ErrorAction SilentlyContinue |
        ForEach-Object { Copy-Item $_.FullName -Destination $OutDir -Force }
}

# --- 3. CUDA runtime dlls -----------------------------------------------
$parent    = Split-Path $OutDir -Parent
$leaf      = Split-Path $OutDir -Leaf
$cudartDir = Join-Path $parent ("cudart-" + $leaf)
New-Item -ItemType Directory -Force -Path $cudartDir | Out-Null

Write-Host ""
Write-Host "   CUDA runtime dlls (from $CudaDllSrc):" -ForegroundColor Cyan
foreach ($d in $cudaDlls) {
    $mb = [math]::Round($d.Length / 1MB, 1)
    Write-Host ("     " + $d.Name + "  " + $mb + " MB")
    Copy-Item $d.FullName -Destination $cudartDir -Force
    Copy-Item $d.FullName -Destination $OutDir    -Force   # merged, ready-to-run copy
}

# --- 4. VC++ runtime ----------------------------------------------------
if (-not $NoVCRedist) {
    $vc = @('msvcp140.dll','vcruntime140.dll','vcruntime140_1.dll','concrt140.dll')
    $got = 0
    foreach ($v in $vc) {
        $src = Join-Path "C:\Windows\System32" $v
        if (Test-Path $src) {
            Copy-Item $src -Destination $OutDir -Force
            $got++
        }
    }
    Write-Host "   VC++ runtime: $got / $($vc.Count) dll(s) copied" -ForegroundColor Cyan
}

# --- 5. verify real dependencies ----------------------------------------
if ($Verify) {
    $dumpbin = "D:\Program Files\Microsoft Visual Studio\2022\Professional\VC\Tools\MSVC\14.44.35207\bin\Hostx64\x64\dumpbin.exe"
    if (Test-Path $dumpbin) {
        Write-Host ""
        Write-Host "   ggml-cuda.dll depends on:" -ForegroundColor Cyan
        & $dumpbin /dependents (Join-Path $OutDir "ggml-cuda.dll") 2>$null |
            Select-String -Pattern '\.dll$' | ForEach-Object {
                $n = ($_ -split '\s+')[-1]
                $present = Test-Path (Join-Path $OutDir $n)
                $mark = if ($present) { "ok      " } else { "MISSING " }
                $col  = if ($present) { "Gray" } else { "Red" }
                Write-Host ("     " + $mark + $n) -ForegroundColor $col
            }
    } else {
        Write-Host "   (dumpbin not found - skipped dependency check)"
    }
}

# --- 6. zip -------------------------------------------------------------
if ($Zip) {
    $7z = "C:\Program Files\7-Zip\7z.exe"
    if (Test-Path $7z) {
        $stamp = Get-Date -Format "yyyyMMdd"
        $z1 = Join-Path $parent ("kvmem-cuda$CudaVer-$stamp.zip")
        $z2 = Join-Path $parent ("cudart-kvmem-cuda$CudaVer-$stamp.zip")
        Write-Host ""
        Write-Host "   packing $z1 ..." -ForegroundColor Cyan
        & $7z a -mx=5 -y -- $z1 (Join-Path $OutDir "\*") | Out-Null
        Write-Host "   packing $z2 ..." -ForegroundColor Cyan
        & $7z a -mx=5 -y -- $z2 (Join-Path $cudartDir "\*") | Out-Null
        Write-Host ("   " + [math]::Round((Get-Item $z1).Length/1MB,1) + " MB + " +
                    [math]::Round((Get-Item $z2).Length/1MB,1) + " MB")
    } else {
        Write-Host "   7-Zip not found at $7z - skipped zipping (folders are ready)." -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "DONE" -ForegroundColor Green
Write-Host "  merged folder (ready to rar as-is) : $OutDir"
Write-Host "  cuda-only folder (official style)  : $cudartDir"
exit 0
