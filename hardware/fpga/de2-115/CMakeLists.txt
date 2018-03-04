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

project(de2_115)

# The working directory for these is the source dir, which means these will
# put output files in the source hierarchy even if this is an out-of-tree
# build. This is because the Quartus project file specifies relative paths.
# XXX it might be cleaner to have this generate the .qsf file, or perhaps
# expand a template QSF file.
set(OUTPUT_DIR ${CMAKE_CURRENT_SOURCE_DIR}/output_files/)

find_program(QUARTUS_MAP NAMES quartus_map)
find_program(QUARTUS_FIT NAMES quartus_fit)
find_program(QUARTUS_ASM NAMES quartus_asm)
find_program(QUARTUS_STA NAMES quartus_sta)
find_program(QUARTUS_PGM NAMES quartus_pgm)
find_program(QUARTUS_CPF NAMES quartus_cpf)

add_custom_target(synthesize
    COMMAND ${QUARTUS_MAP} de2_115
    COMMAND ${QUARTUS_FIT} de2_115
    COMMAND ${QUARTUS_ASM} de2_115
    COMMAND ${QUARTUS_STA} de2_115
    COMMAND ${QUARTUS_CPF} -c -d EPCS64 ${OUTPUT_DIR}/de2_115.sof ${OUTPUT_DIR}/de2_115.pof
    COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/print_summary.py
    COMMENT "Synthesizing"
    DEPENDS bootrom
    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR})

# This loads the SOF (SRAM Object File), which can be loaded onto the board in JTAG
# mode.
add_custom_target(program
    COMMAND ${QUARTUS_PGM} -m jtag -o \"P\;output_files/de2_115.sof\"
    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR})

# Load a POF (Program Object File) into the board, which is loaded automatically in
# active serial mode every time the board boots.
add_custom_target(asprogram
    COMMAND ${QUARTUS_PGM} -m jtag -o \"P\;output_files/de2_115.pof\"
    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR})
