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

project(libc)
include(nyuzi)

# libos-bare and libos-kern share headers, so this doesn't create a dependency
# on one.
include_directories($<TARGET_PROPERTY:os-bare,INCLUDE_DIRECTORIES>)

add_nyuzi_library(c
    src/dlmalloc.c
    src/memcmp.c
    src/memset.c
    src/setjmp.s
    src/stdlib.c
    src/time.c
    src/math.c
    src/memcpy.s
    src/qsort.c
    src/stdio.c
    src/string.c
    src/vfprintf.c
    src/cxx_runtime.cpp
    src/memcpy.s
    src/setjmp.s)

set_source_files_properties(dlmalloc.c PROPERTIES COMPILE_FLAGS "-Wno-error")

target_include_directories(c PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/include)
