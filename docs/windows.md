# Windows 原生构建与运行指南

本仓库原本只支持 Linux（官方构建/启动脚本均基于 bash/WSL）。本文档描述在 Windows 上
原生构建和运行 kvmem-llama.cpp 的方法，以及本机新增的 Qwen 思考等级参数。

## 一、构建

前置条件（本机已满足）：
- Visual Studio 2022 Professional（MSVC 14.44，安装在 D 盘）
- CUDA Toolkit 13.1（C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v13.1）
- CMake 4.x、Ninja（Python Scripts 目录）
- Windows SDK 10.0.26100.0
- GPU：RTX 5060 Ti 16GB（CUDA arch 120a）

在普通 CMD/PowerShell 中运行（不要在 WorkBuddy 会话内运行）：

```bat
cd /d I:\llama\kvmem-llama.cpp
scripts\build-windows.bat build
```

`build-windows.bat` 只是薄启动器，真正逻辑在同目录 `build-windows.ps1`
（把逻辑放 .ps1 是为了能直接调试/断言）。也可以直接调用：

```powershell
powershell -ExecutionPolicy Bypass -File scripts\build-windows.ps1 -Build
```

产物：`build-win-native\bin\llama-kvmem-server.exe`、`llama-kvmem-cli.exe`

注意：本仓库根 `CMakeLists.txt` 设了 `LLAMA_BUILD_SERVER OFF`，所以**不会**产出上游原版
`llama-server.exe`。KVMem 服务端是独立 target，直接编译
`llama.cpp/tools/server/server-common.cpp`。

首次全量编译（含 GGML_CUDA_FA_ALL_QUANTS）约 30-60 分钟。
带 `-Build` 重跑是增量的；但**改动编译选项会触发全量重编**（ninja 认为所有 obj 的命令行都变了）。

## 二、Windows 移植改动清单

1. `kvmem/src/host/raw_kv_store.cpp`：`clock_gettime(CLOCK_MONOTONIC)` →
   `std::chrono::steady_clock`（跨平台单调时钟）。
2. `kvmem/include/kvmem/nvme_kv_tier.hpp`：Windows 下编译为禁用桩（`enabled()==false`），
   与上游"NVMe offload 未实现"的现状一致；POSIX 版本（pwrite/pread/fallocate）保留给
   Linux。运行时所有 NVMe 调用都有 `enabled()` 守卫，桩不影响 CPU/GPU 路径。
3. `kvmem/CMakeLists.txt`：Windows 下跳过 host 单测（依赖 unistd.h 与真实 NVMe 层），
   测试请在 WSL 构建中运行。
4. `llama-kvmem-cli.cpp`：`setenv()`（POSIX）→ `_putenv_s()`；用 `#ifdef _WIN32` 分支。
5. `CMakeLists.txt`（根）：加 `/utf-8` 编译选项（C/CXX 用 `/utf-8`，CUDA 用
   `-Xcompiler=/utf-8`）。`llama.cpp/common/jinja/utils.h` 里有 UTF-8 字符 `↵`，
   在简中 Windows 的代码页 936 下会被 MSVC 误解析，报 C2001「常量中有换行符」。
6. `scripts/build-windows.ps1` + `scripts/build-windows.bat`：一键配置+编译。
7. `scripts/start-windows.ps1`：IQ3 配方的原生 Windows 启动器（对标 start-iq3.sh）。

## 二·五、Windows 环境坑（重要）

本机进程环境块里同时存在大小写变体的同名变量：`Path` 和 `PATH`，
以及 `HTTP_PROXY` / `http_proxy` / `HTTPS_PROXY` / `https_proxy`。

- `[System.Environment]::GetEnvironmentVariables()` 返回的是**大小写敏感**的 Hashtable，
  所以两个拼写会作为两个不同的 key 出现；
- 而 `Start-Process` 会把它们拷进大小写**不敏感**的 StringDictionary → 抛
  「已添加项。字典中的关键字:"PATH"所添加的关键字:"Path"」；
- 同样的重复 key 会让 MSBuild 崩 MSB6001。
- 该报错**只在 `Start-Process` 带 `-RedirectStandardOutput/-RedirectStandardError` 时触发**，
  不带重定向时可以正常工作。

因此 `start-windows.ps1` **不使用 `Start-Process`**，改为自己构造
`System.Diagnostics.ProcessStartInfo`，用 `$env:ComSpec` 包一层命令处理器来做输出重定向，
并且**完全不碰 `EnvironmentVariables`**：在本机 Windows PowerShell 5.1 上该属性恒为 `$null`
（即使 `UseShellExecute=$false`），保持 `$null` 反而正好让子进程原样继承环境块。
CUDA 运行时 DLL 目录已在机器级 PATH 中，无需再改 PATH。

构建脚本则采取另一条路：显式清掉代理变量并重建 `PATH`，让环境块里每种变量只剩一个拼写。

## 三、新增 Qwen 思考等级与 Jinja 参数

服务端（llama-kvmem-server）新增：

- `--thinking-level low|medium|high|xhigh|default`（别名 `--reasoning-effort`）：
  服务端默认思考等级，请求级参数可覆盖。
- `--chat-template STR` / `--chat-template-file FILE`：覆盖模型内置 Jinja 模板
  （例如 Qwen3.8 的 froggeric 模板）。
- `--jinja`：仅为 llama-server 命令行兼容而接受（本服务 Jinja 恒开）。

请求级（/v1/chat/completions body）：

```json
{
  "messages": [...],
  "reasoning_effort": "high",            // low | medium | high | xhigh | default
  "enable_thinking": false,              // 关闭思考（原有支持）
  "thinking_budget_tokens": 4096,        // 思考 token 预算（原有支持）
  "chat_template_kwargs": {              // 任意 Jinja 变量透传
    "reasoning_effort": "low",
    "enable_thinking": true
  }
}
```

机制：`reasoning_effort` 经 `chat_template_kwargs` → `extra_context` 传入模板引擎，
模板内 `{%- if reasoning_effort == 'xhigh' %}` 等分支与 caps 调整生效；
`enable_thinking` 走原生输入字段。

### ⚠️ 可取值由模型模板决定，不是固定四档

服务端命令行/请求体接受 `low | medium | high | xhigh | default`，但**模板才是最终裁判**。
`raise_exception` 抛出的异常会被转成 **400 + 模板原文**，例如本机
`Qwen3.8-27B-GSQ-RCO-IQ3_S-mtp.gguf` 的内置模板只认三档：

```jinja
{%- if resolved_reasoning_effort not in ('xhigh', 'medium', 'low') %}
    {{- raise_exception('Unexpected reasoning effort ' ~ reasoning_effort
        ~ '. Supported types are xhigh (default), medium, and low.') }}
{%- endif %}
```

所以对本模型传 `high` 会得到：

```json
{"error":"chat template failed: Unexpected reasoning effort high. Supported types are xhigh (default), medium, and low."}
```

本模型实际可用的档位是：`default`（= xhigh）、`xhigh`、`medium`、`low`，以及
`enable_thinking:false` 完全关闭思考。

并且 `--thinking-level` 的服务端默认值会在**启动时**就做一次模板试渲染校验：
若该等级不被模板接受，进程直接退出并打印原因，而不是让之后每个请求都 400。

## 四、启动

启动方式是 `scripts\start-windows.bat`（对标原版 llama-server 的用法：参数摆在文件开头，
想改哪项就改哪项）。它内部调用 `build-win-native\bin\llama-kvmem-server.exe`。

```bat
REM 改完上面的 CONFIG 块后，直接在资源管理器双击，或在命令行里：
scripts\start-windows.bat            :: 前台运行，日志就在当前窗口，Ctrl+C 停
scripts\start-windows.bat run        :: 同上（显式写法）
scripts\start-windows.bat detach     :: 另开一个窗口后台跑，日志写文件
scripts\start-windows.bat status     :: 查服务是否响应
scripts\start-windows.bat stop       :: 停止服务
scripts\start-windows.bat dryrun     :: 只打印拼好的命令行，不启动（排错用）
scripts\start-windows.bat help
```

CONFIG 块里可改的项：`MODEL` / `MMPROJ` / `CHAT_TEMPLATE_FILE` / `SRV_HOST` / `SRV_PORT` /
`NGL` / `CTX` / `PREDICT` / `BATCH` / `KV_DTYPE` / `KVMEM_*`（method、budget、reserve、
block-tokens、query-replay、query-policy）/ `SPEC_*`（draft-mtp）/ `THINKING_LEVEL` /
`REASONING_BUDGET` / 采样各项（`SAMPLE_TEMP`、`TOP_P`、`TOP_K`、`MIN_P`、penalty）/ `EXTRA_ARGS`。

留空的项不会拼进命令行（例如不填 `MMPROJ` 就不加 `--mmproj`，因此不会出现空参数）。
命令行上追加的参数会拼在最后，可以直接透传任意服务端 flag：

```bat
scripts\start-windows.bat detach --verbose
```

`detach` 模式把 stdout/stderr 重定向到仓库根目录的 `kvmem_server.log` /
`kvmem_server.err.log`（**有内容的是 .err.log**）。关掉那个最小化窗口即停止服务。

端口、KVMem 配方等参数与官方 start-iq3.sh 对齐（KV q8_0、budget 36864、reserve 16384、
block 128、draft-mtp、显式采样）。27B 模型 + 256K 上下文加载需要几分钟，
加载完成前 `/health` 不通属于正常现象。

> `scripts\start-windows.ps1` 是早先的 PowerShell 版启动器，功能已被 .bat 覆盖
> （额外提供加载等待与超时）。两者参数各自独立，配置项请以 .bat 的 CONFIG 块为准。

## 五、已知限制

- **服务端是单线程的**：正在生成时 `/health` 会挂起排队，不会立即返回。
  所以别把 `/health` 探测间隔设得太短，也别在长生成期间判定服务端已死。
- NVMe KV 层在 Windows 上为桩（未移植 POSIX 定位 I/O）；CPU 主机内存层完整可用。
- 生成超过 `--kvmem-gen-reserve`（本配方 16384）会硬报错退出——上游已知问题。
- 仓库主补丁（patches/llama-kvmem-current.patch）针对钉住的 llama.cpp b81c99b，
  Windows 构建与 Linux 构建使用同一套补丁。
- Windows 下不构建 host 层单测（依赖 unistd.h 与真实 NVMe），需在 WSL/Linux 下跑。
