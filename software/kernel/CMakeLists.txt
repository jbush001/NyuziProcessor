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

project(kernel)
include(nyuzi)

add_nyuzi_executable(kernel
    IMAGE_BASE_ADDRESS 0xc0000000
    SOURCES
    main.c
    start.S
    libc.c
    rwlock.c
    uart.c
    trap_entry.S
    trap.c
    kernel_heap.c
    slab.c
    context_switch.S
    thread.c
    loader.c
    fs.c
    sd_card.c
    vm_translation_map.c
    vm_page.c
    vm_area_map.c
    vm_address_space.c
    vm_cache.c
    syscall.c
    user_copy.S
    vga.c
    util.c)

target_include_directories (kernel PUBLIC ${CMAKE_CURRENT_SOURCE_DIR})
