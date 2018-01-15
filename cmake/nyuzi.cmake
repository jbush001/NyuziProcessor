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

macro(strict_warnings)
    if ("${CMAKE_CXX_COMPILER_ID}" STREQUAL "Clang")
    	# -Weverything is only supported on clang
        set(CLANG_WARN_FLAGS "-Weverything -Wno-padded -Wno-float-equal -Wno-covered-switch-default \
		-Wno-switch-enum -Wno-bad-function-cast -Wno-documentation -Wno-documentation-unknown-command \
		-Wno-missing-prototypes -Wno-reserved-id-macro -Wno-strict-prototypes -Wno-expansion-to-defined -Wno-c++98-compat -Werror")
        set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} ${CLANG_WARN_FLAGS}")
        set(CMAKE_C_FLAGS "${CMAKE_CXX_FLAGS} ${CLANG_WARN_FLAGS}")
    elseif ("${CMAKE_CXX_COMPILER_ID}" STREQUAL "GNU")
        set(GCC_WARN_FLAGS "-Wall -W -Werror")
        set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} ${GCC_WARN_FLAGS}")
        set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} ${GCC_WARN_FLAGS}")
    endif()
endmacro()

macro(add_nyuzi_binary)
    set(COMPILER_BIN /usr/local/llvm-nyuzi/bin/)
    set(CMAKE_C_COMPILER ${COMPILER_BIN}/clang)
    set(CMAKE_CXX_COMPILER ${COMPILER_BIN}/clang++)
    set(CMAKE_RANLIB ${COMPILER_BIN}/llvm-ranlib)
    set(CMAKE_AR ${COMPILER_BIN}/llvm-ar)
    set(CMAKE_ASM_COMPILE ${COMPILER_BIN}/clang)
    enable_language(ASM)
    set(CMAKE_CXX_STANDARD 11)
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -O3")
    set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -O3")

    # LLD does not support these flags
    string(REPLACE "-Wl,-search_paths_first" "" CMAKE_C_LINK_FLAGS "${CMAKE_C_LINK_FLAGS}")
    string(REPLACE "-Wl,-search_paths_first" "" CMAKE_CXX_LINK_FLAGS "${CMAKE_CXX_LINK_FLAGS}")
endmacro(add_nyuzi_binary)

macro(set_display_res width height)
    set(DISPLAY_WIDTH ${width})
    set(DISPLAY_HEIGHT ${height})
endmacro()

macro(add_nyuzi_executable name)
    add_nyuzi_binary()

    if(DISPLAY_WIDTH)
        add_definitions(-DFB_WIDTH=${DISPLAY_WIDTH})
        add_definitions(-DFB_HEIGHT=${DISPLAY_HEIGHT})
    endif()

    if (IMAGE_BASE_ADDRESS)
        set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -Wl,--image-base=${IMAGE_BASE_ADDRESS}")
        set(ELF2HEX_ARGS -b ${IMAGE_BASE_ADDRESS})
    endif()

    add_executable(${name} ${ARGN})

    # Create the HEX file
    add_custom_command(TARGET ${name}
        POST_BUILD
        COMMAND ${COMPILER_BIN}/elf2hex ${ELF2HEX_ARGS} -o ${CMAKE_CURRENT_BINARY_DIR}/${name}.hex $<TARGET_FILE:${name}>)

    # Write a disassembly listing file
    add_custom_command(TARGET ${name}
        POST_BUILD
        COMMAND ${COMPILER_BIN}/llvm-objdump -d $<TARGET_FILE:${name}> -source > ${CMAKE_CURRENT_BINARY_DIR}/${name}.lst)

    # If this has an associated FS image, create that now
    if(FS_IMAGE_FILES)
        add_custom_command(OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/fsimage.bin
            COMMAND mkfs ${CMAKE_CURRENT_BINARY_DIR}/fsimage.bin ${FS_IMAGE_FILES}
            DEPENDS mkfs ${FS_IMAGE_FILES}
            WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
            COMMENT "Creating filesystem image")
        add_custom_target(${name}_fsimage DEPENDS ${CMAKE_CURRENT_BINARY_DIR}/fsimage.bin)
        add_dependencies(${name} ${name}_fsimage)
    endif()

    #
    # Create emulator run script (xxx should create at cmake eval time instead of
    # as a custom target).
    #
    if(DISPLAY_WIDTH)
        set(EMULATOR_ARGS "${EMULATOR_RUN_CMD} -f ${DISPLAY_WIDTH}x${DISPLAY_HEIGHT}")
    endif()

    if(FS_IMAGE_FILES)
        set(EMULATOR_ARGS "${EMULATOR_ARGS} -b ${CMAKE_CURRENT_BINARY_DIR}/fsimage.bin")
    endif()

    if(MEMORY_SIZE)
        set(EMULATOR_ARGS "${EMULATOR_ARGS} -c ${MEMORY_SIZE}")
    endif()

    add_custom_command(TARGET ${name}
        POST_BUILD
        COMMAND echo "$<TARGET_FILE:nyuzi_emulator> ${EMULATOR_ARGS} ${CMAKE_CURRENT_BINARY_DIR}/${name}.hex" > ${CMAKE_CURRENT_BINARY_DIR}/run_emulator
        COMMAND chmod +x run_emulator)

#    add_custom_command(TARGET ${name}
#        POST_BUILD
#        COMMAND echo "$<TARGET_FILE:nyuzi_emulator> -m gdb ${EMULATOR_ARGS} ${name}.hex \&" > run_debug
#        COMMAND echo "${COMPILER_BIN}/lldb --arch nyuzi $<TARGET_FILE:${name}> -o \"gdb-remote 8000\"" > ${CMAKE_CURRENT_BINARY_DIR}/run_debug
#        COMMAND chmod +x run_debug)

    #
    # Create verilator run script
    #
    if(FS_IMAGE_FILES)
        set(VERILOG_ARGS "${VERILOG_ARGS} +block=${CMAKE_CURRENT_BINARY_DIR}/fsimage.bin")
    endif()

    add_custom_command(TARGET ${name}
        POST_BUILD
        COMMAND echo "${CMAKE_SOURCE_DIR}/bin/nyuzi_vsim ${VERILOG_ARGS} +bin=${CMAKE_CURRENT_BINARY_DIR}/${name}.hex" > ${CMAKE_CURRENT_BINARY_DIR}/run_verilator
        COMMAND chmod +x run_verilator)

    #
    # Create VCS run script (uses VERILOG_ARGS from above)
    #
    add_custom_command(TARGET ${name}
        POST_BUILD
        COMMAND echo "${CMAKE_SOURCE_DIR}/scripts/vcsrun.pl ${VERILOG_ARGS} +bin=${CMAKE_CURRENT_BINARY_DIR}/${name}.hex" > ${CMAKE_CURRENT_BINARY_DIR}/run_vcs
        COMMAND chmod +x run_vcs)

    #
    # Create FPGA run script
    #
    if(FS_IMAGE_FILES)
        set(${SERIAL_BOOT_FS} "${CMAKE_CURRENT_BINARY_DIR}/fsimage.bin")
    endif()

    add_custom_command(TARGET ${name}
        POST_BUILD
        COMMAND echo "$<TARGET_FILE:serial_boot> ${SERIAL_BOOT_ARGS} \\$$SERIAL_PORT ${CMAKE_CURRENT_BINARY_DIR}/${name}.hex ${SERIAL_BOOT_FS}" > ${CMAKE_CURRENT_BINARY_DIR}/run_fpga
        COMMAND chmod +x run_fpga)
endmacro(add_nyuzi_executable name)

macro(add_nyuzi_library name)
    add_nyuzi_binary()

    add_library(${name} ${ARGN})
endmacro(add_nyuzi_library name)
