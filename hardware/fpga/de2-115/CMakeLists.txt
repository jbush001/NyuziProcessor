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
# XXX it might be cleaner to have this generate the .qsf file.

find_program(QUARTUS_MAP NAMES quartus_map)
find_program(QUARTUS_FIT NAMES quartus_fit)
find_program(QUARTUS_ASM NAMES quartus_asm)
find_program(QUARTUS_STA NAMES quartus_sta)
find_program(QUARTUS_PGM NAMES quartus_pgm)

set(SOURCES
    fpga/de2-115/de2_115_top.sv
    fpga/common/vga_sequencer.sv
    fpga/common/vga_controller.sv
    fpga/common/sdram_controller.sv
    fpga/common/spi_controller.sv
    fpga/common/axi_rom.sv
    fpga/common/axi_interconnect.sv
    fpga/common/uart.sv
    fpga/common/uart_transmit.sv
    fpga/common/uart_receive.sv
    fpga/common/gpio_controller.sv
    fpga/common/ps2_controller.sv
    fpga/common/timer.sv
    core/io_request_queue.sv
    core/idx_to_oh.sv
    core/oh_to_idx.sv
    core/writeback_stage.sv
    core/thread_select_stage.sv
    core/sync_fifo.sv
    core/sram_2r1w.sv
    core/sram_1r1w.sv
    core/int_execute_stage.sv
    core/reciprocal_rom.sv
    core/performance_counters.sv
    core/operand_fetch_stage.sv
    core/fp_execute_stage5.sv
    core/fp_execute_stage4.sv
    core/fp_execute_stage3.sv
    core/fp_execute_stage2.sv
    core/fp_execute_stage1.sv
    core/l2_cache_update_stage.sv
    core/l2_cache_tag_stage.sv
    core/l2_cache_read_stage.sv
    core/l2_cache_pending_miss_cam.sv
    core/l1_l2_interface.sv
    core/l2_axi_bus_interface.sv
    core/l2_cache_arb_stage.sv
    core/l2_cache.sv
    core/l1_store_queue.sv
    core/l1_load_miss_queue.sv
    core/instruction_decode_stage.sv
    core/ifetch_tag_stage.sv
    core/ifetch_data_stage.sv
    core/nyuzi.sv
    core/dcache_tag_stage.sv
    core/dcache_data_stage.sv
    core/core.sv
    core/control_registers.sv
    core/cam.sv
    core/cache_lru.sv
    core/rr_arbiter.sv
    core/io_interconnect.sv
    core/tlb.sv
    core/jtag_tap_controller.sv
    core/on_chip_debugger.sv
    core/synchronizer.sv
    core/scoreboard.sv)

set(MAP_ARGS "-I${CMAKE_SOURCE_DIR}/hardware/core")

foreach(file ${SOURCES})
    message("append ${file}")
    list(APPEND MAP_ARGS " --source=${CMAKE_SOURCE_DIR}/hardware/${file}")
endforeach()

set(BUILD_FILES
    ${CMAKE_CURRENT_SOURCE_DIR}/de2_115.qpf
    ${CMAKE_CURRENT_SOURCE_DIR}/de2_115.qsf
    ${CMAKE_CURRENT_SOURCE_DIR}/de2_115.sdc)

add_custom_target(synthesize
    COMMAND ${CMAKE_COMMAND} -E copy ${BUILD_FILES} ${CMAKE_CURRENT_BINARY_DIR}
    COMMAND ${CMAKE_COMMAND} -E copy $<TARGET_FILE_DIR:bootrom>/boot.hex  ${CMAKE_CURRENT_BINARY_DIR}
    COMMAND ${QUARTUS_MAP} de2_115 ${MAP_ARGS}
    COMMAND ${QUARTUS_FIT} de2_115
    COMMAND ${QUARTUS_ASM} de2_115
    COMMAND ${QUARTUS_STA} de2_115
    COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/print_summary.py
    COMMENT "Synthesizing"
    DEPENDS bootrom
    WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR})

add_custom_target(program
    COMMAND ${QUARTUS_PGM} -m jtag -o \"P\;output_files/de2_115.sof\"
    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR})
