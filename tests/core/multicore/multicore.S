#
# Copyright 2019 Jeff Bush
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

.include "../../asm_macros.inc"

# This test only works with 8 cores enabled
# In hardware/core/config.sv, set NUM_CORES to 8. Each core prints its
# identifier round-robin.

.set TOTAL_THREADS, 32

                    .text
                    .align 4

                    .globl _start
_start:             start_all_threads
                    getcr s1, CR_CURRENT_THREAD

                    # Wait until I am the current thread
                    lea s2, current_thread
1:                  load_32 s3, (s2)
                    cmpeq_i s3, s3, s1
                    bz s3, 1b

                    # Print a char
                    add_i s0, s1, 'A'
                    print_char

                    # Pass to next thread and exit
                    lea s1, current_thread
                    load_32 s2, (s1)
                    add_i s2, s2, 1
                    store_32 s2, (s1)
                    halt_current_thread

                    .align 4
current_thread:     .long 0
