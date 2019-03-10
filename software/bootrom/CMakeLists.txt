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

project(bootrom)
include(nyuzi)

add_nyuzi_binary(bootrom)
set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -Wl,--script ${CMAKE_CURRENT_SOURCE_DIR}/boot.ld -Wl,--oformat,binary")

add_executable(bootrom
    start.S
    boot.c)

# XXX hack: the result is written into the source directory instead of build, as the
# FPGA tools don't know how to find the latter.
add_custom_command(TARGET bootrom
    POST_BUILD
    COMMAND ${CMAKE_SOURCE_DIR}/tools/misc/bin2hex.py $<TARGET_FILE:bootrom> > boot.hex
    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR})
