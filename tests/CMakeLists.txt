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

set(py_test_dirs
	unit
	remote-gdb
	jtag-debug
	core/isa/
	core/cache_control/
	core/mmu
	core/trap
	core/perf_counters
	stress/atomic
	shared_memory
	device/sdmmc/
	device/ps2/
	device/uart
	libc
	compiler-rt
	cosimulation
    render/clip
    render/fill
    render/teapot
    render/triangle
    render/blend
    render/depthbuffer
    render/mipmap
    render/texture)

# This is called 'tests' because 'test' is reserved by cmake.
add_custom_target(tests)
foreach (dir ${py_test_dirs})
    add_custom_command(TARGET tests
        COMMAND ./runtest.py
        WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/${dir})
endforeach(dir)

add_custom_command(TARGET tests
    COMMAND ./runtest.py --target verilator
    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/whole-program)
add_custom_command(TARGET tests
    COMMAND ./runtest.py --target emulator *noverilator.*
    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/whole-program)

add_subdirectory(fpga/blinky)
add_subdirectory(fpga/uart_chargen)
add_subdirectory(fpga/sdmmc_dump)
add_subdirectory(fpga/sdmmc_native)

set(fpga_test_dirs
	core/cache_control/
	core/isa/
	core/mmu
	core/trap
	fpga/memory_test
	whole-program)

add_custom_target(fpgatest)
foreach (dir ${fpga_test_dirs})
    add_custom_command(TARGET fpgatest
        COMMAND ./runtest.py --target fpga
        WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/${dir})
endforeach(dir)

add_custom_target(pylint
    COMMAND PYTHONPATH=${CMAKE_CURRENT_SOURCE_DIR} find . -iname "*.py" -exec echo \{\} \\\\; -exec pylint \{\} \\\\;)

add_custom_target(pyflakes
    COMMAND PYTHONPATH=$(CURDIR) find . -iname "*.py" -exec echo \{\} \\\\; -exec pyflakes \{\} \\\\;)

add_custom_target(format
    COMMAND find . -iname "*.py" | xargs autopep8 -i)




