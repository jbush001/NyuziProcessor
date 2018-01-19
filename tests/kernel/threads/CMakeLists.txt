#
# Copyright 2018 Jeff Bush
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

project(kernel_thread_test)
include(nyuzi)

add_nyuzi_binary()
set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -Wl,--image-base=0x1000")
add_executable(kernel_thread_test
    threads.c)
target_link_libraries(kernel_thread_test
    c
    os-kern
    compiler-rt)

# Need to bundle executable into a filesystem that the kernel will boot
# out of.
add_custom_command(TARGET kernel_thread_test
    COMMAND ${CMAKE_COMMAND} -E copy $<TARGET_FILE:kernel_thread_test> ${CMAKE_CURRENT_BINARY_DIR}/program.elf)
add_custom_command(TARGET kernel_thread_test
    COMMAND mkfs ${CMAKE_CURRENT_BINARY_DIR}/fsimage.bin ${CMAKE_CURRENT_BINARY_DIR}/program.elf
    DEPENDS mkfs
    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR})

# Create run scripts
file(GENERATE OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/run_kernel_emulator
    CONTENT "$<TARGET_FILE:nyuzi_emulator> -b ${CMAKE_CURRENT_BINARY_DIR}/fsimage.bin ${CMAKE_BINARY_DIR}/software/kernel/kernel.hex")
file(GENERATE OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/run_kernel_verilator
    CONTENT "${CMAKE_BINARY_DIR}/bin/nyuzi_vsim +block=${CMAKE_CURRENT_BINARY_DIR}/fsimage.bin +bin=${CMAKE_BINARY_DIR}/software/kernel/kernel.hex")

# Kludge: file GENERATE doesn't allow setting permissions, so do it in the
# generated makefile.
add_custom_command(TARGET kernel_thread_test
    POST_BUILD
    COMMAND chmod +x run_*)
