#
# Copyright 2011-2015 Jeff Bush
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

.include "../asm_macros.inc"

#
# L2 cache stress test. Generate stores to a series of randomly generated
# addresses in a 512k region, which should generate a lot of cache misses
# and evictions.
# Each thread stores to rand() * 4 * NUM_THREADS + thread_id.  As a consequence,
# each memory location can be assigned by only one thread. This avoids a problem
# that would occur when write ordering differs between the emulator and cycle
# accurate model (note that NUM_THREADS is hardcoded to 4).
#

                .globl _start
_start:         start_all_threads

                getcr s1, CR_CURRENT_THREAD # seed for RNG (based on thread ID)
                li s5, 10000        # num iterations
                li s2, 1103515245   # A
                li s3, 12345        # C
                getcr s8, CR_CURRENT_THREAD # get thread ID
                shl s8, s8, 2       # Compute thread write offset (thread * 4)
                li s6, 0x3000       # base of write region
                add_i s8, s8, s6    # Add thread offset to this
                li s9, 0x0007fff0   # Address mask (multiple of 16, 512k range)
                move s0, 7          # Initialize value to write

main_loop:      mull_i s1, s1, s2    # Generate next random number (seed * A + C)
                add_i s1, s1, s3

                and s4, s1, s9       # Mask to constrain to memory range
                add_i s4, s4, s8     # Add to base of region
                store_32 s0, (s4)    # Write the word

                add_i s0, s0, 13     # Increment write value
                sub_i s5, s5, 1      # Decrement count
                bnz s5, main_loop

                halt_current_thread




