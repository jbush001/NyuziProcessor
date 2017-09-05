#
# Copyright 2017 Jeff Bush
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

#include "../../asm_macros.inc"

#
# This test spawns four threads. Each one has a separate data address space,
# which are mapped to physical memory in an interleaving pattern. The threads
# write to random addresses in a 128k region in their address space, which
# will cause a series of TLB hits and misses. 4 threads * 128k = 512k total,
# The default 64 entry TLB can map a maximum of 256k, therefore each memory
# access has a 50% chance of hitting the cache. The value written to
# each location consists of the virtual address in the low 24 bits and the thread
# ID in the high bits. This is using a pseudo random number generator to try
# trigger race condtions and edge cases. The number of writes is made
# sufficiently high that every location is written at least once, which allows
# the python test script to verify the contents after this has finished.
#


                .globl _start
_start:         lea s0, tlb_miss
                setcr s0, CR_TLB_MISS_HANDLER # Set miss handler

                getcr s0, CR_CURRENT_THREAD
                setcr s0, CR_CURRENT_ASID

                li s0, FLAG_MMU_EN | FLAG_SUPERVISOR_EN
                setcr s0, CR_FLAGS            # Enable MMU
                flush_pipeline

                start_all_threads

                # Set up random number generator
                getcr s1, CR_CURRENT_THREAD # seed for RNG (based on thread ID)
                li s5, 150000      # num iterations. Enough for each thread to completely write region.
                li s2, 1103515245   # A
                li s3, 12345        # C
                li s6, 0x4000       # base of write region
                move s0, 7          # Initialize value to write
                li s7, 0x1fffc      # 128k write region (512k total across all threads)

main_loop:      mull_i s1, s1, s2    # Generate next random number (seed * A + C)
                add_i s1, s1, s3

                # Compute address
                and s4, s1, s7       # Clamp to write area and align
                add_i s4, s4, s6     # Add to base of region

                # Compute value to write. Top byte is thread ID,
                # lower three bytes are the address.
                getcr s0, CR_CURRENT_THREAD
                shl s0, s0, 24
                or s0, s0, s4

                store_32 s0, (s4)    # Write the word

                add_i s0, s0, 13     # Increment write value
                sub_i s5, s5, 1      # Decrement count
                bnz s5, main_loop

                halt_current_thread

tlb_miss:       setcr s0, CR_SCRATCHPAD0    # Save s0 in scratchpad
                setcr s1, CR_SCRATCHPAD1    # Save s1
                getcr s0, CR_TRAP_ADDRESS   # Get fault virtual address
                getcr s1, CR_TRAP_CAUSE     # Get fault reason
                and s1, s1, 0x20            # Dcache bit set?
                bz s1, fill_itlb            # If no goto update ITLB

fill_dltb:      # Check if this is the high memory area, which is
                # identity mapped to expose virtual devices
                li s1, 0xffff0000
                cmpgt_u s1, s0, s1
                bz s1, in_data_area

                # Yes, is in high memory, so map directly
                and s1, s0, 0x7ff
                xor s0, s0, s1          # Clear low bits
                or s0, s0, TLB_PRESENT | TLB_WRITABLE
                getcr s1, CR_TRAP_ADDRESS
                dtlbinsert s1, s0
                b done

                # Each thread has its own data address space, with
                # pages interleaved by thread
in_data_area:   shr s0, s0, 12              # Convert to page number
                shl s0, s0, 2               # Multiply by four (num threads)
                getcr s1, CR_CURRENT_THREAD
                add_i s0, s0, s1            # Add thread index to page
                shl s0, s0, 12              # Convert back to page number
                or s0, s0, TLB_PRESENT | TLB_WRITABLE
                getcr s1, CR_TRAP_ADDRESS
                dtlbinsert s1, s0           # Put into DTLB
                b done

                # Instruction memory is identity mapped
fill_itlb:      and s1, s0, 0x7ff
                xor s0, s0, s1          # Clear low bits
                or s0, s0, TLB_PRESENT | TLB_GLOBAL | TLB_EXECUTABLE
                getcr s1, CR_TRAP_ADDRESS
                itlbinsert s1, s0           # Put into ITLB

done:           getcr s0, CR_SCRATCHPAD0    # Restore saved s0
                getcr s1, CR_SCRATCHPAD1    # Restore saved s1
                eret
