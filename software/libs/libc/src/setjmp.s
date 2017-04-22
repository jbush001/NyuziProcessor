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

                .global setjmp
                .type setjmp,@function
setjmp:         # Align s0 to a 64 byte boundary to do vector stores
                add_i s0, s0, 63
                move s1, 63
                xor s1, s1, -1
                and s0, s0, s1

                # Copy callee-saved registers into structure
                store_v v26, 0x0(s0)
                store_v v27, 0x40(s0)
                store_v v28, 0x80(s0)
                store_v v29, 0xc0(s0)
                store_v v30, 0x100(s0)
                store_v v31, 0x140(s0)
                store_32 s24, 0x180(s0)
                store_32 s25, 0x184(s0)
                store_32 s26, 0x188(s0)
                store_32 s27, 0x18c(s0)
                store_32 s28, 0x190(s0)
                store_32 fp, 0x194(s0)
                store_32 sp, 0x198(s0)
                store_32 ra, 0x19c(s0)    # Will return to this address
                move s0, 0
                ret

                .global longjmp
                .type longjmp,@function
longjmp:        # Align s0 to a 64 byte boundary to do vector loads
                add_i s0, s0, 63
                move s2, 63
                xor s2, s2, -1
                and s0, s0, s2

                # Copy callee-saved registers out of structure
                load_v v26, 0x0(s0)
                load_v v27, 0x40(s0)
                load_v v28, 0x80(s0)
                load_v v29, 0xc0(s0)
                load_v v30, 0x100(s0)
                load_v v31, 0x140(s0)
                load_32 s24, 0x180(s0)
                load_32 s25, 0x184(s0)
                load_32 s26, 0x188(s0)
                load_32 s27, 0x18c(s0)
                load_32 s28, 0x190(s0)
                load_32 fp, 0x194(s0)
                load_32 sp, 0x198(s0)
                load_32 s2, 0x19c(s0)   # Get return address
                move s0, s1             # Set return value
                b s2                    # Jump back

