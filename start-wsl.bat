@echo off
title KVMem Server - WSL
wsl bash -c "cd /mnt/i/llama/kvmem-llama.cpp-v016/kvmem-test && bash scripts/start-wsl.sh"
pause
