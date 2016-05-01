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
// Verify dflush works correctly. Fill memory with known values. The test
// harness will dump system memory from the simulator and read it back to
// ensure it was flushed correctly.
//
                    .globl _start
_start:             start_all_threads

                    getcr s0, CR_CURRENT_THREAD
                    load_const s1, 0x1f0e6231
                    load_const s2, 0x400000     // Base address of region to write to
                    load_const s10, 4096        // Number of cache lines to fill
fill_loop:          add_i s3, s1, s0            // Get value to store
                    move v0, s3
                    shl s4, s0, 6               // Mult index by 64 to find offset
                    add_i s4, s4, s2            // Add offset to base address
                    store_v v0, (s4)            // store 64 bytes
                    dflush s4
                    add_i s0, s0, 4             // Increment index by num threads
                    cmplt_i s4, s0, s10         // Past end?
                    btrue s4, fill_loop         // No, so loop

                    halt_current_thread

