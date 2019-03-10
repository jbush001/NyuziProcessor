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

project(console)
include(nyuzi)


add_nyuzi_library(console
    console.cpp)

target_include_directories(console PUBLIC ${CMAKE_CURRENT_SOURCE_DIR})

# libos-bare and libos-kern share headers, so this doesn't create a dependency
# on one.
target_include_directories(console PRIVATE $<TARGET_PROPERTY:os-bare,INCLUDE_DIRECTORIES>)
target_include_directories(console PRIVATE $<TARGET_PROPERTY:c,INCLUDE_DIRECTORIES>)
