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

project(sceneview)
include(nyuzi)

set(OBJ_FILE ${CMAKE_CURRENT_SOURCE_DIR}/dabrovik_sponza/sponza.obj)
set(RESOURCE_FILE ${CMAKE_CURRENT_BINARY_DIR}/resource.bin)

set_display_res(640 480)
set(MEMORY_SIZE 0x8000000)
set(FS_IMAGE_FILES ${RESOURCE_FILE})

add_nyuzi_executable(sceneview
    sceneview.cpp)
add_dependencies(sceneview resource_bin)

target_link_libraries(sceneview
    render
    c
    os-bare)

add_custom_command(OUTPUT ${RESOURCE_FILE}
    COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/make_resource_file.py ${OBJ_FILE}
    WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
    DEPENDS ${OBJ_FILE}
    COMMENT "converting scene geometry files...")
add_custom_target(resource_bin DEPENDS ${RESOURCE_FILE})
