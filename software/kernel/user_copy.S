//
// Copyright 2015 Jeff Bush
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

#include "asm.h"

//
// Copy data between a user and kernel space buffer. If an invalid page
// fault occurs, return -1. Otherwise return 0. This sets a global variable
// of a location to reset the PC to in this case. The trap handler checks
// this when an invalid fault occurs.
//
// int user_copy(void *dest, const void *src, int length)
//

                .globl user_copy
                .type user_copy,@function

user_copy:      lea s3, fault_handler  // Base of fault handler array
                getcr s4, CR_CURRENT_HW_THREAD
                shl s4, s4, 2           // Turn into array offset
                add_i s4, s4, s3        // Now address of fault entry

                lea s3, uc_fault
                store_32 s3, (s4)

1:              bz s2, 2f
                load_s8 s3, (s1)
                store_8 s3, (s0)
                add_i s0, s0, 1
                add_i s1, s1, 1
                sub_i s2, s2, 1
                b 1b

uc_fault:       move s0, -1 // Failure
                b 3f

2:              move s0, 0  // Success

                // Reset fault handler
3:              move s3, 0
                store_32 s3, (s4)
                ret


                .globl user_strlcpy
                .type user_strlcpy,@function

user_strlcpy:   lea s3, fault_handler  // Base of fault handler array
                getcr s4, CR_CURRENT_HW_THREAD
                shl s4, s4, 2           // Turn into array offset
                add_i s4, s4, s3        // Now address of fault entry

                lea s3, usc_fault
                store_32 s3, (s4)

                bz s2, 2f

1:              sub_i s2, s2, 1
                bz s2, 2f
                load_s8 s3, (s1)
                bz s3, 2f       // Delimiter
                store_8 s3, (s0)
                add_i s0, s0, 1
                add_i s1, s1, 1
                b 1b

usc_fault:      move s0, -1 // Failure
                b 3f

2:               move s3, 0
                store_8 s3, (s0)            // Append null
                move s0, 0  // Success

                // Reset fault handler
3:              move s3, 0
                store_32 s3, (s4)
                ret
