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

include(ProcessorCount)

project(hardware)
add_subdirectory(fpga/de2-115)

set(ENABLE_VERILATOR_THREADS 0 CACHE BOOL "Enable multithreaded verilator model (improves performance on multiprocessor host machines)")

if(${ENABLE_VERILATOR_THREADS})
    ProcessorCount(NUM_THREADS)
    message("Configure verilator with ${NUM_THREADS} threads")
else()
    set(NUM_THREADS 0)
    message("Configure verilator with 1 thread")
endif()

find_program(VERILATOR NAMES verilator)

set(VERILATOR_GEN_DIR "${CMAKE_CURRENT_BINARY_DIR}/generated")
set(VERILATOR_OPTIONS --unroll-count 512
    --assert
    -Wall
    -Wno-unused
    -Wno-pinconnectempty
    -Wno-declfilename
    -Wno-importstar
    -DSIMULATION=1
    -I${CMAKE_CURRENT_SOURCE_DIR}/core
    -y ${CMAKE_CURRENT_SOURCE_DIR}/testbench
    -y ${CMAKE_CURRENT_SOURCE_DIR}/fpga/common
    -Mdir ${VERILATOR_GEN_DIR}
    --threads ${NUM_THREADS})

set(DUMP_WAVEFORM 0 CACHE BOOL "Enable dumping VCD waveforms from Verilog simulator.")

if(${DUMP_WAVEFORM})
    set(VERILATOR_OPTIONS ${VERILATOR_OPTIONS} --trace --trace-structs)
endif()

set(VERILATOR_MIN_VERSION "12")

# Version string looks like this:
# "Verilator 3.920 2018-02-01 rev verilator_3_920"
execute_process(COMMAND ${VERILATOR} --version OUTPUT_VARIABLE verilator_version_str)
string(REGEX MATCH "Verilator ([0-9])\\.([0-9]+)" verilator_version ${verilator_version_str})
if(NOT CMAKE_MATCH_0)
    message("Couldn't get verilator version")
elseif(CMAKE_MATCH_2 LESS ${VERILATOR_MIN_VERSION} OR CMAKE_MATCH_1 LESS 4)
    message(FATAL_ERROR "Need at least verilator 4.${VERILATOR_MIN_VERSION}")
endif()

add_custom_target(nyuzi_vsim ALL
    COMMAND ${VERILATOR} ${VERILATOR_OPTIONS}
        --cc ${CMAKE_CURRENT_SOURCE_DIR}/testbench/soc_tb.sv
        --exe ${CMAKE_CURRENT_SOURCE_DIR}/testbench/verilator_main.cpp
        ${CMAKE_CURRENT_SOURCE_DIR}/testbench/jtag_socket.cpp
    COMMAND make CXXFLAGS=-Wno-parentheses-equality OPT_FAST="-Os"  -C ${VERILATOR_GEN_DIR} -f Vsoc_tb.mk Vsoc_tb
    COMMAND cp ${VERILATOR_GEN_DIR}/Vsoc_tb ${CMAKE_BINARY_DIR}/bin/nyuzi_vsim
    WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
    COMMENT "Generating hardware simulator")

# When the clean target is run, this will delete source code files generated
# by Verilator.
set_directory_properties(PROPERTY ADDITIONAL_MAKE_CLEAN_FILES
    ${VERILATOR_GEN_DIR})

# Target for VCS simulator
add_custom_target(vcsbuild
    COMMAND ${CMAKE_COMMAND} -E env "DUMP_WAVEFORM=${DUMP_WAVEFORM}" ${CMAKE_SOURCE_DIR}/scripts/vcsbuild.pl
    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR})

find_program(EMACS NAMES emacs)

# The 'autos' target expands Verilog Mode macros using emacs in batch mode.
# https://www.veripool.org/wiki/verilog-mode
add_custom_target(autos
    COMMAND ${EMACS} --eval '\(setq-default indent-tabs-mode nil\)'
        --eval '\(setq-default verilog-typedef-regexp \"_t$$\"\)'
        --eval '\(setq-default verilog-auto-reset-widths `unbased\)'
        --eval '\(setq-default verilog-auto-inst-param-value t\)'
        --eval '\(setq-default verilog-library-directories `\(\"${CMAKE_CURRENT_SOURCE_DIR}/core\" \"${CMAKE_CURRENT_SOURCE_DIR}/testbench\" \"${CMAKE_CURRENT_SOURCE_DIR}/fpga/common\" \".\"\)\)'
        --batch core/*.sv testbench/*.sv fpga/common/*.sv fpga/de2-115/*.sv
        -f verilog-batch-auto -f save-buffer
    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR})

# FPGA target isn't built as part of other targets, but run a lint pass to
# ensure they are at least syntactically correct.
add_custom_target(fpgalint
    COMMAND ${VERILATOR} ${VERILATOR_OPTIONS} --lint-only fpga/de2-115/de2_115_top.sv
    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
    COMMENT "Checking FPGA sources")

# This extracts all SRAMs from the design and creates separate instances for each
# unique width/size configuration. This is intended for ASIC memory compiler tools.
add_custom_target(srams
    COMMAND ${CMAKE_BINARY_DIR}/bin/nyuzi_vsim +dumpmems | ../tools/misc/extract_mems.py > ${CMAKE_CURRENT_BINARY_DIR}/srams.inc
    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
    DEPENDS nyuzi_vsim)
