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

user_copy:      load_32 s3, fault_handler_addr  // Base of fault handler array
                getcr s4, CR_CURRENT_HW_THREAD
                shl s4, s4, 2           // Turn into array offset
                add_i s4, s4, s3        // Now address of fault entry

                lea s3, cfu_fault
                store_32 s3, (s4)

copy_loop:      bfalse s2, copy_done
                load_s8 s3, (s1)
                store_8 s3, (s0)
                add_i s0, s0, 1
                add_i s1, s1, 1
                sub_i s2, s2, 1
                goto copy_loop

cfu_fault:      move s0, -1 // Failure
                goto done

copy_done:      move s0, 0  // Success

                // Reset fault handler
done:           move s3, 0
                store_32 s3, (s4)
                ret

fault_handler_addr:  .long fault_handler
