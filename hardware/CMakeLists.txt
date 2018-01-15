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

add_subdirectory(fpga/de2-115)

set(VERILATOR_GEN_DIR "generated")
set(VERILATOR_OPTIONS --unroll-count 512 --assert
    -Wall -Wno-unused -Wno-pinconnectempty -Wno-undriven -Wno-declfilename
    -Icore -y testbench -y fpga/common -DSIMULATION=1 -Mdir ${VERILATOR_GEN_DIR})

if(DEFINED ENV{DUMP_WAVEFORM})
    set(VERILATOR_OPTIONS ${VERILATOR_OPTIONS} --trace --trace-structs)
endif()

# XXX check verilator version

add_custom_target(verilator_model ALL
    COMMAND verilator ${VERILATOR_OPTIONS} --cc testbench/soc_tb.sv
        --exe testbench/verilator_main.cpp testbench/jtag_socket.cpp
    COMMAND make CXXFLAGS=-Wno-parentheses-equality OPT_FAST="-Os"  -C ${VERILATOR_GEN_DIR} -f Vsoc_tb.mk Vsoc_tb
    COMMAND cp ${VERILATOR_GEN_DIR}/Vsoc_tb ${CMAKE_SOURCE_DIR}/bin/verilator_model
    COMMENT "Generating verilator model")

# This will delete the generated files when the clean target is run
set_directory_properties(PROPERTY ADDITIONAL_MAKE_CLEAN_FILES
    ${VERILATOR_GEN_DIR})

add_custom_target(vcsbuild
    COMMAND ${CMAKE_SOURCE_DIR}/scripts/vcsbuild.pl)

add_custom_target(autos
    COMMAND emacs --eval '\(setq-default indent-tabs-mode nil\)'
        --eval '\(setq-default verilog-typedef-regexp \"_t$$\"\)'
	    --eval '\(setq-default verilog-auto-reset-widths `unbased\)'
		--eval '\(setq-default verilog-auto-inst-param-value t\)'
		--eval '\(setq-default verilog-library-directories `\(\"${CMAKE_CURRENT_SOURCE_DIR}/core\" \"${CMAKE_CURRENT_SOURCE_DIR}/testbench\" \"${CMAKE_CURRENT_SOURCE_DIR}/fpga/common\" \".\"\)\)'
		--batch core/*.sv testbench/*.sv fpga/common/*.sv fpga/de2-115/*.sv
		-f verilog-batch-auto -f save-buffer)

add_custom_target(fpgalint
    COMMAND verilator ${VERILATOR_OPTIONS} --lint-only fpga/de2-115/de2_115_top.sv
    COMMENT "Checking FPGA sources")

add_custom_target(srams
    COMMAND ./verilator_model +dumpmems | ../tools/misc/extract_mems.py > core/srams.inc
    DEPENDS verilator_model)
