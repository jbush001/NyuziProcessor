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
// of a location to reset the PC to if there is a fault. The trap handler
// checks this when an invalid fault occurs and will jump to it instead of
// crashing if it is non-null.
//
// int user_copy(void *dest, const void *src, int length)
//

                .globl user_copy
                .type user_copy,@function

user_copy:      lea s3, fault_handler  // Base of fault handler array
                getcr s4, CR_CURRENT_HW_THREAD
                shl s4, s4, 2           // Turn into array offset
                add_i s4, s4, s3        // Now address of my fault handler ptr

                lea s3, uc_fault        // Get address of fault handler
                store_32 s3, (s4)       // Store in table

1:              bz s2, 2f               // Length == 0? break loop if so
                load_s8 s3, (s1)        // read byte
                store_8 s3, (s0)        // write it
                add_i s0, s0, 1         // increment pointers
                add_i s1, s1, 1
                sub_i s2, s2, 1
                b 1b

                // Branches here when there is an invalid fault
uc_fault:       move s0, -1 // Error return value
                b 3f

2:              move s0, 0  // Success return value

                // Clear fault handler entry.
3:              move s3, 0
                store_32 s3, (s4)
                ret


                .globl user_strlcpy
                .type user_strlcpy,@function

user_strlcpy:   lea s3, fault_handler  // Base of fault handler array
                getcr s4, CR_CURRENT_HW_THREAD
                shl s4, s4, 2           // Turn into array offset
                add_i s4, s4, s3        // Now address of fault entry

                lea s3, usc_fault       // Get my fault handler
                store_32 s3, (s4)       // Save in global pointer

                bz s2, 2f               // If length == 0, break loop

1:              sub_i s2, s2, 1         // Decrement length
                bz s2, 2f               // Break if now zero
                load_s8 s3, (s1)        // Read byte from source
                bz s3, 2f               // Break this a null terminator?
                store_8 s3, (s0)        // Store byte in dest
                add_i s0, s0, 1         // Increment src/dest pointers
                add_i s1, s1, 1
                b 1b

                // Branches here when there is an invalid fault
usc_fault:      move s0, -1 // Set return value to -1
                b 3f

2:              move s3, 0
                store_8 s3, (s0)            // Append null to dest
                move s0, 0  // Set return value to 0 for success

                // Clear fault handler pointer
3:              move s3, 0
                store_32 s3, (s4)
                ret
