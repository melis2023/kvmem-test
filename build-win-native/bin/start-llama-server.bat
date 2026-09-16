@echo off
setlocal

REM ====================================================================
REM  llama.cpp-style launcher for the KVMem server binary
REM
REM  Plain "llama-server.exe -m model.gguf ..." form: ONE command line,
REM  every parameter written out inline. Edit a value, save, run it.
REM
REM      start-llama-server.bat            this file (plain CLI style)
REM      I:\llama\kvmem-llama.cpp-v016\build-win-native\bin\   fixed binary dir
REM      start-windows.bat                 older action-based launcher
REM                                        (run / detach / status / stop)
REM
REM  The server binary is always taken from the FIXED absolute path below
REM  (variable BIN), independent of where this script is started from.
REM
REM  Ctrl+C stops the server.
REM
REM  Optional extras - append them anywhere on the command line below:
REM  Vision is ON: --mmproj (Q5_K-MIX projector) + --mmproj-offload + --image-max-tokens 512.
REM  Other vision knobs you can append to the command line:
REM      --image-max-tokens N            per-image token cap (currently 512)
REM      --image-min-tokens N            native minimum image tokens
REM      --no-mmproj-offload             run the vision encoder on the CPU instead of the GPU
REM      --mmproj "I:\model\mmproj-Qwen3.8-27B-BF16.gguf"    higher-precision projector (931 MB)
REM  Chat template is ON: --chat-template-file below overrides the template embedded in
REM  the GGUF. The levels THIS template accepts (verified in the file):
REM      none | off                                -> thinking disabled
REM      minimal | low                             -> low
REM      high | xhigh | max | ultracode | extreme  -> xhigh
REM      anything else, including medium/default   -> medium
REM  It never refuses to start on an unknown level; it falls back to medium.
REM      --chat-template STR             inline template string instead of a file
REM  Load mode is ON: -lm none = no special loading mode. Documented values are
REM  auto | none | mmap | mlock | mmap+mlock | dio (default auto). Deprecated aliases:
REM  --mlock, --mmap / --no-mmap, --direct-io / --no-direct-io.
REM  --jinja is accepted for compatibility only; Jinja is always enabled.
REM      --kvmem-cpu-gb 8 --kvmem-nvme-gb 32 --kvmem-nvme-dir "D:\kvmem_nvme"
REM      --kvmem-recent-tokens 4096 --kvmem-query-last 64 --kvmem-query-max-tokens 512
REM      --seed 1234
REM  Thinking: this template also defaults to medium when a request sends no
REM  reasoning_effort, so --reasoning-effort medium below matches that default.
REM  FIXED FLAG NAME: the server has NO --thinking-level option. The correct
REM  flag is --reasoning-effort LEVEL (none disables thinking; the value is
REM  passed to the chat template). --enable-thinking / --no-think are separate.
REM  NOTE: the old caveat is gone. The embedded Qwen template rejected "high" and
REM  made the server refuse to start; this external template maps high to xhigh.
REM ====================================================================

title KVMem llama-server - Qwen3.8-27B-IQ3_S-mtp

REM Fixed install directory of the KVMem server build (absolute, not relative
REM to this script). Change BIN here if the build tree ever moves.
set "BIN=I:\llama\kvmem-llama.cpp-v016\build-win-native\bin"
set "EXE=%BIN%\llama-kvmem-server.exe"
if not exist "%EXE%" (
    echo ERROR: llama-kvmem-server.exe not found:
    echo   %EXE%
    echo.
    echo Build it first:  scripts\build-windows.bat build
    pause
    exit /b 2
)

cd /d "%BIN%"

"%EXE%" ^
  -m "I:\model\Qwen3.8-27B-GSQ-RCO-IQ3_S-mtp.gguf" ^
  --mmproj "I:\model\mmproj-Qwen3.8-27B-Q5_K-MIX.gguf" --mmproj-offload --image-max-tokens 512 ^
  --jinja ^
  --chat-template-file "I:\templates\chat_template.jinja" ^
  -lm none ^
  --host 127.0.0.1 --port 8080 ^
  -c 262144 -n 16384 -b 512  -ngl 99 ^
  --kvmem-budget 36864 --kvmem-gen-reserve 16384  ^
  --kv-dtype q8_0 ^
  --spec-type draft-mtp --spec-draft-n-max 2 --spec-kv-dtype f16 ^
  --enable-thinking --reasoning-effort medium --reasoning-budget 8192 ^
  --temp 1.0 --top-p 0.95 --top-k 20 --min-p 0.0 ^
  --presence-penalty 0.0 --frequency-penalty 0.0 --repeat-penalty 1.0  --webui

set "RC=%ERRORLEVEL%"
echo.
echo Server exited with code %RC%.
pause
endlocal & exit /b %RC%
