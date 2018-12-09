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

# This module defines targets that are compiled for the Nyuzi instruction set.

macro(add_nyuzi_binary)
    set(CMAKE_C_COMPILER ${NYUZI_COMPILER_BIN}/clang)
    set(CMAKE_CXX_COMPILER ${NYUZI_COMPILER_BIN}/clang++)
    set(CMAKE_RANLIB ${NYUZI_COMPILER_BIN}/llvm-ranlib)
    set(CMAKE_AR ${NYUZI_COMPILER_BIN}/llvm-ar)
    set(CMAKE_ASM_COMPILE ${NYUZI_COMPILER_BIN}/clang)
    enable_language(ASM)
    set(CMAKE_CXX_STANDARD 11)

    # LLD does not support these flags
    string(REPLACE "-Wl,-search_paths_first" "" CMAKE_C_LINK_FLAGS "${CMAKE_C_LINK_FLAGS}")
    string(REPLACE "-Wl,-search_paths_first" "" CMAKE_CXX_LINK_FLAGS "${CMAKE_CXX_LINK_FLAGS}")
endmacro(add_nyuzi_binary)

macro(add_nyuzi_executable name)
    cmake_parse_arguments(ARG
        "" "DISPLAY_WIDTH;DISPLAY_HEIGHT;IMAGE_BASE_ADDRESS;MEMORY_SIZE" "FS_IMAGE_FILES;SOURCES" ${ARGN})

    add_nyuzi_binary()

    if(ARG_DISPLAY_WIDTH)
        add_definitions(-DFB_WIDTH=${ARG_DISPLAY_WIDTH})
        add_definitions(-DFB_HEIGHT=${ARG_DISPLAY_HEIGHT})
    endif()

    if (ARG_IMAGE_BASE_ADDRESS)
        set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -Wl,--image-base=${ARG_IMAGE_BASE_ADDRESS}")
        set(ELF2HEX_ARGS -b ${ARG_IMAGE_BASE_ADDRESS})
    endif()

    add_executable(${name} ${ARG_SOURCES})
    target_compile_options(${name} PRIVATE -O3 -Wall -Wno-unused-command-line-argument -Werror -fno-rtti)

    # Create the HEX file
    add_custom_command(TARGET ${name}
        POST_BUILD
        COMMAND ${NYUZI_COMPILER_BIN}/elf2hex ${ELF2HEX_ARGS} -o ${CMAKE_CURRENT_BINARY_DIR}/${name}.hex $<TARGET_FILE:${name}>)

    # Write a disassembly listing file
    add_custom_command(TARGET ${name}
        POST_BUILD
        COMMAND ${NYUZI_COMPILER_BIN}/llvm-objdump -d $<TARGET_FILE:${name}> -source > ${CMAKE_CURRENT_BINARY_DIR}/${name}.lst)

    # If this has an associated FS image, create that now
    if(ARG_FS_IMAGE_FILES)
        set(FS_IMAGE_PATH ${CMAKE_CURRENT_BINARY_DIR}/fsimage.bin)
        add_custom_command(OUTPUT ${FS_IMAGE_PATH}
            COMMAND mkfs ${FS_IMAGE_PATH} ${ARG_FS_IMAGE_FILES}
            DEPENDS mkfs ${ARG_FS_IMAGE_FILES}
            WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
            COMMENT "Creating filesystem image")
        add_custom_target(${name}_fsimage DEPENDS ${FS_IMAGE_PATH})
        add_dependencies(${name} ${name}_fsimage)
    endif()

    #
    # Create emulator run script (xxx should create at cmake eval time instead of
    # as a custom target).
    #
    if(ARG_DISPLAY_WIDTH)
        set(EMULATOR_ARGS "${EMULATOR_RUN_CMD} -f ${ARG_DISPLAY_WIDTH}x${ARG_DISPLAY_HEIGHT}")
    endif()

    if(ARG_FS_IMAGE_FILES)
        set(EMULATOR_ARGS "${EMULATOR_ARGS} -b ${FS_IMAGE_PATH}")
    endif()

    if(ARG_MEMORY_SIZE)
        set(EMULATOR_ARGS "${EMULATOR_ARGS} -c ${ARG_MEMORY_SIZE}")
    endif()

    # Create emulator run script
    file(GENERATE OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/run_emulator
        CONTENT "$<TARGET_FILE:nyuzi_emulator> ${EMULATOR_ARGS} ${CMAKE_CURRENT_BINARY_DIR}/${name}.hex")

    # Create debugger run script
    file(GENERATE OUTPUT  ${CMAKE_CURRENT_BINARY_DIR}/run_debug
        CONTENT "$<TARGET_FILE:nyuzi_emulator> -m gdb ${EMULATOR_ARGS} ${name}.hex \&\n${NYUZI_COMPILER_BIN}/lldb --arch nyuzi $<TARGET_FILE:${name}> -o \"gdb-remote 8000\"")

    # Create verilator run script
    if(ARG_FS_IMAGE_FILES)
        set(VERILOG_ARGS "${VERILOG_ARGS} +block=${FS_IMAGE_PATH}")
    endif()

    file(GENERATE OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/run_verilator
        CONTENT "${CMAKE_BINARY_DIR}/bin/nyuzi_vsim ${VERILOG_ARGS} +bin=${CMAKE_CURRENT_BINARY_DIR}/${name}.hex")

    # Create VCS run script (uses VERILOG_ARGS from above)
    file(GENERATE OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/run_vcs
        CONTENT "${CMAKE_SOURCE_DIR}/scripts/vcsrun.pl ${VERILOG_ARGS} +bin=${CMAKE_CURRENT_BINARY_DIR}/${name}.hex")

    # Create FPGA run script
    if(ARG_FS_IMAGE_FILES)
        set(SERIAL_BOOT_FS "${FS_IMAGE_PATH}")
    endif()

    file(GENERATE OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/run_fpga
        CONTENT "$<TARGET_FILE:serial_boot> ${SERIAL_BOOT_ARGS} \$SERIAL_PORT ${CMAKE_CURRENT_BINARY_DIR}/${name}.hex ${SERIAL_BOOT_FS}")

    # Kludge: file GENERATE doesn't allow setting permissions, so do it in the makefile
    add_custom_command(TARGET ${name}
        POST_BUILD
        COMMAND chmod +x run_*)
endmacro(add_nyuzi_executable name)

macro(add_nyuzi_library name)
    add_nyuzi_binary()
    add_library(${name} ${ARGN})
    target_compile_options(${name} PRIVATE -O3 -Wall -Wno-unused-command-line-argument -Werror)
endmacro(add_nyuzi_library name)
