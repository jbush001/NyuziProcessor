//
// Copyright 2018 Jeff Bush
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

// XXX there might be a cleaner way to do this with CMakeLists.txt
#include "../../../kernel/syscalls.h"

// This is for syscalls that do not return an error code
#define SYSCALL(name) \
    .globl name; \
    name: \
        syscall SYS_ ## name; \
        ret

// When a syscall fails, it indicates the error as a negative return value.
// However, the POSIX convention is to set the global variable 'errno' and
// return -1. All of the syscall functions will branch to this common function
// if there is an error to convert it. We need to use an array of errno
// values to store an error value per thread.
#define SYSCALL_WITH_ERRNO(name) \
    .globl name; \
    name: \
        syscall SYS_ ## name; \
        cmplt_i s1, s0, 0; \
        bnz s1, set_errno; \
        ret

set_errno:
    lea s1, __errno_array
    getcr s2, 0         // Current thread
    shl s2, s2, 2       // Times word size to find array offset
    add_i s1, s1, s2
    xor s0, s0, -1      // negate the error value so it's possitive
    add_i s0, s0, 1
    store_32 s0, (s1)   // Store in errno array slot for this thread
    move s0, -1
    ret

SYSCALL(write_console)
SYSCALL_WITH_ERRNO(thread_exit)
SYSCALL_WITH_ERRNO(spawn_thread)
SYSCALL_WITH_ERRNO(get_current_thread_id)
SYSCALL(create_area)
SYSCALL(get_cycle_count)
SYSCALL_WITH_ERRNO(exec)
SYSCALL_WITH_ERRNO(set_perf_counter)
SYSCALL(read_perf_counter)
SYSCALL_WITH_ERRNO(init_vga)
