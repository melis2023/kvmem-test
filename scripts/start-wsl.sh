#!/usr/bin/env bash
# WSL launcher for KVMem server
BIN="/mnt/i/llama/kvmem-llama.cpp-v016/kvmem-test/build-win-native/bin"
EXE="$BIN/llama-kvmem-server.exe"
MODEL_DIR_WIN="\\\\wsl.localhost\\Ubuntu-22.04\\home\\melis\\kvmem-build\\models"
MODEL_DIR_WSL="/home/melis/kvmem-build/models"

if [[ ! -f "$EXE" ]]; then
    echo "ERROR: $EXE not found"
    exit 2
fi

cd "$BIN"

"$EXE" -m "$MODEL_DIR_WIN/Qwen3.8-27B-GSQ-RCO-IQ3_S-mtp.gguf" --mmproj "$MODEL_DIR_WIN/mmproj-Qwen3.8-27B-Q5_K-MIX.gguf" --no-mmproj-offload --image-max-tokens 512 --jinja --chat-template-file "$MODEL_DIR_WIN/chat_template_oneline.txt" -lm none --host 127.0.0.1 --port 8080 -c 256000 -n 16384 -b 512 -ngl 99 --kvmem-budget 36864 --kvmem-gen-reserve 16384 --kvmem-gpu-ratio 0.8 --kvmem-block-tokens 32 --kv-dtype q8_0 --spec-type draft-mtp --spec-draft-n-max 3 --spec-kv-dtype f16 --enable-thinking --reasoning-effort medium --reasoning-budget 8192 --temp 1.0 --top-p 0.95 --top-k 20 --min-p 0.0 --presence-penalty 0.0 --frequency-penalty 0.0 --repeat-penalty 1.0 --webui