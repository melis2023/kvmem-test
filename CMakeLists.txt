cmake_minimum_required(VERSION 3.16)
project(kvmem_llamacpp LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)

# The source tree is UTF-8 (llama.cpp/common/jinja/utils.h embeds '↵' in a
# string literal). With MSVC's default code page on zh-CN Windows (936) those
# bytes are misparsed and the build fails with C2001 "newline in constant".
# Force UTF-8 for every language, including the nvcc host compiler.
if (MSVC)
    add_compile_options("$<$<COMPILE_LANGUAGE:C>:/utf-8>")
    add_compile_options("$<$<COMPILE_LANGUAGE:CXX>:/utf-8>")
    add_compile_options("$<$<COMPILE_LANGUAGE:CUDA>:-Xcompiler=/utf-8>")
endif()

enable_testing()
add_subdirectory(kvmem)

option(KVMEM_BUILD_LLAMA "Build llama.cpp with the KVMem adapter" ON)
if (KVMEM_BUILD_LLAMA)
    if (NOT CMAKE_CUDA_COMPILER AND EXISTS "/home/leye/kvmem_qw3/.cu13-env/bin/nvcc")
        set(CMAKE_CUDA_COMPILER "/home/leye/kvmem_qw3/.cu13-env/bin/nvcc" CACHE FILEPATH "nvcc")
    endif()

    # --- CUDA architecture auto-detection (mirrors ggml-cuda logic) --------
    # CMAKE_CUDA_ARCHITECTURES must be defined at THIS scope so it propagates
    # to ALL subdirectories (llama.cpp/src, llama.cpp/ggml, etc.).
    # ggml-cuda sets it in its own subdirectory scope which doesn't propagate
    # back to sibling targets like the "llama" library.
    option(GGML_CUDA "ggml: use CUDA" ON)
    if (GGML_CUDA AND NOT DEFINED CMAKE_CUDA_ARCHITECTURES)
        find_package(CUDAToolkit QUIET)
        if (CUDAToolkit_FOUND)
            option(GGML_NATIVE "ggml: use native CPU/GPU" ON)
            if (GGML_NATIVE AND CUDAToolkit_VERSION VERSION_GREATER_EQUAL "11.6" AND CMAKE_VERSION VERSION_GREATER_EQUAL "3.24")
                # native == detect GPU at build time (single-arch binary)
                set(CMAKE_CUDA_ARCHITECTURES "native")
            else()
                # GGML_NATIVE=OFF: build for ALL common architectures with hardware acceleration (real only)
                # Only keep real architectures for hardware-accelerated GPUs (no virtual/PTX)
                if (CUDAToolkit_VERSION VERSION_LESS "13")
                    list(APPEND CMAKE_CUDA_ARCHITECTURES 70-real)   # V100/Titan V (Volta)
                endif()
                if (CUDAToolkit_VERSION VERSION_GREATER_EQUAL "11.0")
                    list(APPEND CMAKE_CUDA_ARCHITECTURES 75-real)   # RTX 2060/2070/2080 (Turing)
                endif()
                list(APPEND CMAKE_CUDA_ARCHITECTURES 86-real)   # RTX 3060/3070/3080/3090 (Ampere)
                if (CUDAToolkit_VERSION VERSION_GREATER_EQUAL "11.8")
                    list(APPEND CMAKE_CUDA_ARCHITECTURES 89-real)   # RTX 4060/4070/4080/4090 (Ada Lovelace)
                endif()
                if (CUDAToolkit_VERSION VERSION_GREATER_EQUAL "12.8")
                    list(APPEND CMAKE_CUDA_ARCHITECTURES 120a-real) # RTX 5050/5060/5060 Ti/5070/5070 Ti/5080/5090 (Blackwell)
                endif()
            endif()
            # Force as CACHE so ALL subdirectories (including llama.cpp/ggml) inherit
            set(CMAKE_CUDA_ARCHITECTURES ${CMAKE_CUDA_ARCHITECTURES} CACHE STRING "" FORCE)
        endif()
        message(STATUS "KVMem: CMAKE_CUDA_ARCHITECTURES=${CMAKE_CUDA_ARCHITECTURES} (GGML_NATIVE=${GGML_NATIVE})")
    endif()
    # Default llama.cpp FA vec kernels are only F16/Q4_0/Q8_0/BF16. q5_0 KV
    # (and q4_1/q5_1) need this or FlashAttention refuses those types and
    # Qwen3.8 hybrid prefill collapses (~75 t/s vs ~500).
    set(GGML_CUDA_FA_ALL_QUANTS ON CACHE BOOL
        "compile all FlashAttention KV quants (needed for --kv-dtype q5_0)" FORCE)
    set(LLAMA_KVMEM ON CACHE BOOL "" FORCE)
    set(LLAMA_KVMEM_ROOT "${CMAKE_SOURCE_DIR}" CACHE PATH "" FORCE)
    set(LLAMA_BUILD_TESTS OFF CACHE BOOL "" FORCE)
    set(LLAMA_BUILD_EXAMPLES OFF CACHE BOOL "" FORCE)
    set(LLAMA_BUILD_SERVER OFF CACHE BOOL "" FORCE)
    set(LLAMA_BUILD_APP OFF CACHE BOOL "" FORCE)
    set(LLAMA_BUILD_TOOLS ON CACHE BOOL "")
    set(LLAMA_BUILD_COMMON ON CACHE BOOL "")

    add_subdirectory(llama.cpp)

    # kvmem-mtp-kv-test references internal llama symbols (llama_memory_kvmem_mtp::*,
    # llama_memory_hybrid::*, kvmem_stagein_*) that are not part of the LLAMA_API
    # surface. On Linux the .so exports them by default; on Windows a DLL does not,
    # so linking fails with LNK2019. Export everything from the llama DLL to match
    # the Linux behavior.
    if (WIN32 AND TARGET llama)
        set_property(TARGET llama PROPERTY WINDOWS_EXPORT_ALL_SYMBOLS ON)
    endif()

    # Upstream only adds tools/ui (the stock Web UI) when LLAMA_BUILD_SERVER is
    # ON, which this project deliberately forces OFF. Pull the UI in directly so
    # we can embed the original llama.cpp UI without also defining llama-server.
    # LLAMA_BUILD_UI=ON builds it from source with npm; LLAMA_USE_PREBUILT_UI=ON
    # (the upstream default) downloads prebuilt assets from the HF bucket, which
    # needs no node toolchain.
    if (LLAMA_BUILD_UI OR LLAMA_USE_PREBUILT_UI)
        add_subdirectory(llama.cpp/tools/ui)
    endif()

    add_executable(llama-kvmem-cli tools/llama-kvmem-cli.cpp tools/kvmem-spec.cpp)
    target_include_directories(llama-kvmem-cli PRIVATE
        src/adapter
        llama.cpp/include
        llama.cpp/common)
    target_link_libraries(llama-kvmem-cli PRIVATE llama llama-common)
    target_compile_features(llama-kvmem-cli PRIVATE cxx_std_17)

    add_executable(llama-kvmem-server tools/llama-kvmem-server.cpp tools/kvmem-spec.cpp
        tools/kvmem-vision.cpp llama.cpp/tools/server/server-common.cpp)
    target_include_directories(llama-kvmem-server PRIVATE
        src/adapter
        llama.cpp/include
        llama.cpp/common
        llama.cpp/tools/server
        llama.cpp/tools/mtmd
        llama.cpp/vendor
        llama.cpp/vendor/cpp-httplib)
    target_link_libraries(llama-kvmem-server PRIVATE llama llama-common cpp-httplib mtmd)
    target_compile_features(llama-kvmem-server PRIVATE cxx_std_17)

    # Stock llama.cpp Web UI (tools/ui, SvelteKit). When LLAMA_BUILD_UI=ON the
    # assets are embedded into the `llama-ui` static library; linking it here
    # makes LLAMA_UI_HAS_ASSETS visible to the server so it can serve the
    # original UI instead of the bundled fallback page.
    if (TARGET llama-ui)
        target_link_libraries(llama-kvmem-server PRIVATE llama-ui)
        # LLAMA_UI_HAS_ASSETS is defined *inside* the generated ui.h, so it
        # cannot guard the #include. This macro tells the source that ui.h is
        # reachable at all; it then checks LLAMA_UI_HAS_ASSETS for the assets.
        target_compile_definitions(llama-kvmem-server PRIVATE KVMEM_HAVE_LLAMA_UI=1)
    endif()

    # Run manually with an MTP GGUF path; no model is downloaded by CTest.
    add_executable(kvmem-mtp-kv-test tests/mtp-kv-test.cpp tools/kvmem-spec.cpp)
    target_include_directories(kvmem-mtp-kv-test PRIVATE src/adapter tools llama.cpp/src)
    target_link_libraries(kvmem-mtp-kv-test PRIVATE llama llama-common kvmem)
    add_test(NAME kvmem-mtp-kv-test COMMAND kvmem-mtp-kv-test)
    set_tests_properties(kvmem-mtp-kv-test PROPERTIES SKIP_RETURN_CODE 77)

    add_executable(kvmem-gdn-replay-test tests/gdn-replay-test.cpp)
    target_link_libraries(kvmem-gdn-replay-test PRIVATE ggml)
    add_test(NAME kvmem-gdn-replay-test COMMAND kvmem-gdn-replay-test)
    set_tests_properties(kvmem-gdn-replay-test PROPERTIES SKIP_RETURN_CODE 77)

    add_executable(kvmem-reasoning-budget-test tests/reasoning-budget-test.cpp)
    target_include_directories(kvmem-reasoning-budget-test PRIVATE tools)
    target_link_libraries(kvmem-reasoning-budget-test PRIVATE llama-common)
    add_test(NAME kvmem-reasoning-budget-test COMMAND kvmem-reasoning-budget-test)

    add_executable(kvmem-chat-template-test tests/chat-template-test.cpp)
    target_include_directories(kvmem-chat-template-test PRIVATE tools)
    target_link_libraries(kvmem-chat-template-test PRIVATE llama-common)
    add_test(NAME kvmem-chat-template-test COMMAND kvmem-chat-template-test)

    add_executable(kvmem-chat-id-test tests/chat-id-test.cpp)
    target_include_directories(kvmem-chat-id-test PRIVATE tools)
    target_link_libraries(kvmem-chat-id-test PRIVATE llama-common)
    add_test(NAME kvmem-chat-id-test COMMAND kvmem-chat-id-test)
endif()
