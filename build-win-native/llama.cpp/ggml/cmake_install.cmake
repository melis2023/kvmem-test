# Install script for directory: I:/llama/kvmem-llama.cpp-v016/llama.cpp/ggml

# Set the install prefix
if(NOT DEFINED CMAKE_INSTALL_PREFIX)
  set(CMAKE_INSTALL_PREFIX "C:/Program Files (x86)/kvmem_llamacpp")
endif()
string(REGEX REPLACE "/$" "" CMAKE_INSTALL_PREFIX "${CMAKE_INSTALL_PREFIX}")

# Set the install configuration name.
if(NOT DEFINED CMAKE_INSTALL_CONFIG_NAME)
  if(BUILD_TYPE)
    string(REGEX REPLACE "^[^A-Za-z0-9_]+" ""
           CMAKE_INSTALL_CONFIG_NAME "${BUILD_TYPE}")
  else()
    set(CMAKE_INSTALL_CONFIG_NAME "Release")
  endif()
  message(STATUS "Install configuration: \"${CMAKE_INSTALL_CONFIG_NAME}\"")
endif()

# Set the component getting installed.
if(NOT CMAKE_INSTALL_COMPONENT)
  if(COMPONENT)
    message(STATUS "Install component: \"${COMPONENT}\"")
    set(CMAKE_INSTALL_COMPONENT "${COMPONENT}")
  else()
    set(CMAKE_INSTALL_COMPONENT)
  endif()
endif()

# Is this installation the result of a crosscompile?
if(NOT DEFINED CMAKE_CROSSCOMPILING)
  set(CMAKE_CROSSCOMPILING "FALSE")
endif()

if(NOT CMAKE_INSTALL_LOCAL_ONLY)
  # Include the install script for the subdirectory.
  include("I:/llama/kvmem-llama.cpp-v016/build-win-native/llama.cpp/ggml/src/cmake_install.cmake")
endif()

if(CMAKE_INSTALL_COMPONENT STREQUAL "Unspecified" OR NOT CMAKE_INSTALL_COMPONENT)
  file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/lib" TYPE STATIC_LIBRARY OPTIONAL FILES "I:/llama/kvmem-llama.cpp-v016/build-win-native/llama.cpp/ggml/src/ggml.lib")
endif()

if(CMAKE_INSTALL_COMPONENT STREQUAL "Unspecified" OR NOT CMAKE_INSTALL_COMPONENT)
  file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/bin" TYPE SHARED_LIBRARY FILES "I:/llama/kvmem-llama.cpp-v016/build-win-native/bin/ggml.dll")
endif()

if(CMAKE_INSTALL_COMPONENT STREQUAL "Unspecified" OR NOT CMAKE_INSTALL_COMPONENT)
  file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/include" TYPE FILE FILES
    "I:/llama/kvmem-llama.cpp-v016/llama.cpp/ggml/include/ggml.h"
    "I:/llama/kvmem-llama.cpp-v016/llama.cpp/ggml/include/ggml-cpu.h"
    "I:/llama/kvmem-llama.cpp-v016/llama.cpp/ggml/include/ggml-alloc.h"
    "I:/llama/kvmem-llama.cpp-v016/llama.cpp/ggml/include/ggml-backend.h"
    "I:/llama/kvmem-llama.cpp-v016/llama.cpp/ggml/include/ggml-blas.h"
    "I:/llama/kvmem-llama.cpp-v016/llama.cpp/ggml/include/ggml-cann.h"
    "I:/llama/kvmem-llama.cpp-v016/llama.cpp/ggml/include/ggml-cpp.h"
    "I:/llama/kvmem-llama.cpp-v016/llama.cpp/ggml/include/ggml-cuda.h"
    "I:/llama/kvmem-llama.cpp-v016/llama.cpp/ggml/include/ggml-opt.h"
    "I:/llama/kvmem-llama.cpp-v016/llama.cpp/ggml/include/ggml-metal.h"
    "I:/llama/kvmem-llama.cpp-v016/llama.cpp/ggml/include/ggml-rpc.h"
    "I:/llama/kvmem-llama.cpp-v016/llama.cpp/ggml/include/ggml-virtgpu.h"
    "I:/llama/kvmem-llama.cpp-v016/llama.cpp/ggml/include/ggml-sycl.h"
    "I:/llama/kvmem-llama.cpp-v016/llama.cpp/ggml/include/ggml-vulkan.h"
    "I:/llama/kvmem-llama.cpp-v016/llama.cpp/ggml/include/ggml-webgpu.h"
    "I:/llama/kvmem-llama.cpp-v016/llama.cpp/ggml/include/ggml-zendnn.h"
    "I:/llama/kvmem-llama.cpp-v016/llama.cpp/ggml/include/ggml-openvino.h"
    "I:/llama/kvmem-llama.cpp-v016/llama.cpp/ggml/include/gguf.h"
    )
endif()

if(CMAKE_INSTALL_COMPONENT STREQUAL "Unspecified" OR NOT CMAKE_INSTALL_COMPONENT)
  file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/lib" TYPE STATIC_LIBRARY OPTIONAL FILES "I:/llama/kvmem-llama.cpp-v016/build-win-native/llama.cpp/ggml/src/ggml-base.lib")
endif()

if(CMAKE_INSTALL_COMPONENT STREQUAL "Unspecified" OR NOT CMAKE_INSTALL_COMPONENT)
  file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/bin" TYPE SHARED_LIBRARY FILES "I:/llama/kvmem-llama.cpp-v016/build-win-native/bin/ggml-base.dll")
endif()

if(CMAKE_INSTALL_COMPONENT STREQUAL "Unspecified" OR NOT CMAKE_INSTALL_COMPONENT)
  file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/lib/cmake/ggml" TYPE FILE FILES
    "I:/llama/kvmem-llama.cpp-v016/build-win-native/llama.cpp/ggml/ggml-config.cmake"
    "I:/llama/kvmem-llama.cpp-v016/build-win-native/llama.cpp/ggml/ggml-config-version.cmake"
    )
endif()

string(REPLACE ";" "\n" CMAKE_INSTALL_MANIFEST_CONTENT
       "${CMAKE_INSTALL_MANIFEST_FILES}")
if(CMAKE_INSTALL_LOCAL_ONLY)
  file(WRITE "I:/llama/kvmem-llama.cpp-v016/build-win-native/llama.cpp/ggml/install_local_manifest.txt"
     "${CMAKE_INSTALL_MANIFEST_CONTENT}")
endif()
