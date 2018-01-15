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

include(nyuzi)

# XXX need to create resource.bin

set_display_res(640 480)
set(MEMORY_SIZE 0x8000000)
set(FS_IMAGE_FILES resource.bin)

add_nyuzi_executable(sceneview
    sceneview.cpp)

target_link_libraries(sceneview
    render
    c
    os-bare
    compiler-rt)
