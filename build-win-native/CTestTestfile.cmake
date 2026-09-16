# CMake generated Testfile for 
# Source directory: I:/llama/kvmem-llama.cpp-v016
# Build directory: I:/llama/kvmem-llama.cpp-v016/build-win-native
# 
# This file includes the relevant testing commands required for 
# testing this directory and lists subdirectories to be tested as well.
add_test(kvmem-mtp-kv-test "I:/llama/kvmem-llama.cpp-v016/build-win-native/bin/kvmem-mtp-kv-test.exe")
set_tests_properties(kvmem-mtp-kv-test PROPERTIES  SKIP_RETURN_CODE "77" _BACKTRACE_TRIPLES "I:/llama/kvmem-llama.cpp-v016/CMakeLists.txt;96;add_test;I:/llama/kvmem-llama.cpp-v016/CMakeLists.txt;0;")
add_test(kvmem-gdn-replay-test "I:/llama/kvmem-llama.cpp-v016/build-win-native/bin/kvmem-gdn-replay-test.exe")
set_tests_properties(kvmem-gdn-replay-test PROPERTIES  SKIP_RETURN_CODE "77" _BACKTRACE_TRIPLES "I:/llama/kvmem-llama.cpp-v016/CMakeLists.txt;101;add_test;I:/llama/kvmem-llama.cpp-v016/CMakeLists.txt;0;")
add_test(kvmem-reasoning-budget-test "I:/llama/kvmem-llama.cpp-v016/build-win-native/bin/kvmem-reasoning-budget-test.exe")
set_tests_properties(kvmem-reasoning-budget-test PROPERTIES  _BACKTRACE_TRIPLES "I:/llama/kvmem-llama.cpp-v016/CMakeLists.txt;107;add_test;I:/llama/kvmem-llama.cpp-v016/CMakeLists.txt;0;")
add_test(kvmem-chat-template-test "I:/llama/kvmem-llama.cpp-v016/build-win-native/bin/kvmem-chat-template-test.exe")
set_tests_properties(kvmem-chat-template-test PROPERTIES  _BACKTRACE_TRIPLES "I:/llama/kvmem-llama.cpp-v016/CMakeLists.txt;112;add_test;I:/llama/kvmem-llama.cpp-v016/CMakeLists.txt;0;")
add_test(kvmem-chat-id-test "I:/llama/kvmem-llama.cpp-v016/build-win-native/bin/kvmem-chat-id-test.exe")
set_tests_properties(kvmem-chat-id-test PROPERTIES  _BACKTRACE_TRIPLES "I:/llama/kvmem-llama.cpp-v016/CMakeLists.txt;117;add_test;I:/llama/kvmem-llama.cpp-v016/CMakeLists.txt;0;")
subdirs("kvmem")
subdirs("llama.cpp")
subdirs("llama.cpp/tools/ui")
