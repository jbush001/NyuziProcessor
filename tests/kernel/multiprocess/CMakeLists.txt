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

# This is not currently automatically tested, although it probably could be

project(kernel_multiprocess_test)
include(nyuzi)

add_nyuzi_binary()
set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -Wl,--image-base=0x1000")

add_executable(memtest.elf
    memtest.c)
target_link_libraries(memtest.elf
    c
    os-kern
    compiler-rt)

# This is the 'init' program that the kernel launches at startup.
add_executable(kernel_multiprocess_init
    init.c)
target_link_libraries(kernel_multiprocess_init
    c
    os-kern
    compiler-rt)
add_custom_command(TARGET kernel_multiprocess_init
    COMMAND cp $<TARGET_FILE:kernel_multiprocess_init> ${CMAKE_CURRENT_BINARY_DIR}/program.elf)

# Bundle everything into a filesystem image
add_custom_target(kernel_multiprocess_test ALL
    COMMAND mkfs ${CMAKE_CURRENT_BINARY_DIR}/fsimage.bin $<TARGET_FILE:memtest.elf>
        ${CMAKE_CURRENT_BINARY_DIR}/program.elf
    DEPENDS kernel_multiprocess_init memtest.elf mkfs)

# Create run scripts
file(GENERATE OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/run_kernel_emulator
    CONTENT "$<TARGET_FILE:nyuzi_emulator> -b ${CMAKE_CURRENT_BINARY_DIR}/fsimage.bin ${CMAKE_BINARY_DIR}/software/kernel/kernel.hex")
file(GENERATE OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/run_kernel_verilator
    CONTENT "${CMAKE_BINARY_DIR}/bin/nyuzi_vsim +block=${CMAKE_CURRENT_BINARY_DIR}/fsimage.bin +bin=${CMAKE_BINARY_DIR}/software/kernel/kernel.hex")

# Kludge: file GENERATE doesn't allow setting permissions, so do it in the makefile
add_custom_command(TARGET kernel_multiprocess_test
    POST_BUILD
    COMMAND chmod +x run_*)

