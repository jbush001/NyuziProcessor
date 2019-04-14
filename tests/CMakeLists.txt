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

# Write the test configuration file. This is ready by test_harness.py
# to find paths of its dependencies. It is is written in the source
# directory rather than in the build directory so the test harness
# can find it even if this is an out-of-tree build.
configure_file(tests.conf.in ${CMAKE_CURRENT_SOURCE_DIR}/tests.conf)

add_subdirectory(fpga/blinky)
add_subdirectory(fpga/uart_chargen)
add_subdirectory(fpga/sdmmc_dump)
add_subdirectory(fpga/sdmmc_native)
add_subdirectory(float)

set(py_test_dirs
    unit
    jtag-debug
    core/isa/
    core/cache_control/
    core/mmu
    core/trap
    core/perf_counter
    stress/atomic
    device/sdmmc/
    device/ps2/
    device/uart
    tools/emulator
    tools/serial_boot
    tools/profile
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
# I'm not using ctest/add_test here, as I ran into some issues that
# I can't remember now. But it may be worth exploring (or at
# least documenting) later.
# Also: the test target will not rebuild any other modules as dependencies.
add_custom_target(tests)
foreach(dir ${py_test_dirs})
    add_custom_command(TARGET tests
        COMMAND ./runtest.py
        WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/${dir})
endforeach()

# XXX only run in emulator mode for now (because of execution time)
add_custom_command(TARGET tests
    COMMAND ./runtest.py --target emulator
    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/kernel)

# Save a little time by only running these in one environment
add_custom_command(TARGET tests
    COMMAND ./runtest.py --target verilator
    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/whole-program)
add_custom_command(TARGET tests
    COMMAND ./runtest.py --target emulator *noverilator.*
    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/whole-program)

set(fpga_test_dirs
    core/cache_control/
    core/isa/
    core/mmu
    core/trap
    fpga/memory_test
    whole-program)

add_custom_target(fpgatest)
foreach(dir ${fpga_test_dirs})
    add_custom_command(TARGET fpgatest
        COMMAND ./runtest.py --target fpga
        WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/${dir})
endforeach()

find_program(PYLINT_PATH pylint)
find_program(PYFLAKES_PATH pyflakes)
find_program(AUTOPEP8_PATH autopep8)

add_custom_target(pylint
    COMMAND PYTHONPATH=${CMAKE_CURRENT_SOURCE_DIR} find ${CMAKE_CURRENT_SOURCE_DIR} -iname "*.py" -exec echo \{\} \\\\; -exec ${PYLINT_PATH} \{\} \\\\;)

add_custom_target(pyflakes
    COMMAND PYTHONPATH=${CMAKE_CURRENT_SOURCE_DIR} find ${CMAKE_CURRENT_SOURCE_DIR} -iname "*.py" -exec echo \{\} \\\\; -exec ${PYFLAKES_PATH} \{\} \\\\;)

add_custom_target(pyformat
    COMMAND find ${CMAKE_CURRENT_SOURCE_DIR} -iname "*.py" | xargs ${AUTOPEP8_PATH} -i)
