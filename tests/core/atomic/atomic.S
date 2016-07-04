//
// Copyright 2011-2015 Jeff Bush
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

#include "../../asm_macros.inc"

//
// Verify atomic operations work correctly. Threads cycle through incrementing
// a series of array values. Each thread increments a shared counter atomically
// to find the next slot to increment, then uses an atomic operation to increment
// that slot.
//
                    .set NUM_SLOTS, 512

// Clobbers s25
.macro sync_fetch_and_increment oldval, ptr
1:  load_sync s25, (\ptr )
    move \oldval, s25
    add_i s25, s25, 1
    store_sync s25, (\ptr )
    bfalse s25, 1b
.endm

                    .globl _start
_start:             start_all_threads

                    load_const s0, (NUM_SLOTS * 10)       // Total writes
                    lea s1, current_index               // Pointer to shared index
                    load_const s2, 0x100000             // Pointer to array base

fill_loop:          sync_fetch_and_increment s3, s1     // Find next slot
                    cmpge_i s4, s3, s0                  // Done?
                    btrue s4, exit_loop                 // If so, exit
                    and s3, s3, NUM_SLOTS - 1           // Mask so it wraps
                    shl s3, s3, 2                       // Multiply index by four
                    add_i s3, s3, s2                    // Add to array base
                    sync_fetch_and_increment s4, s3     // Increment array index (s4 is ignored)
                    goto fill_loop

exit_loop:          halt_current_thread
current_index:      .long 0
