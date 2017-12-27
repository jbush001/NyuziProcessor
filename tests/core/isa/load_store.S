#
# Copyright 2011-2017 Jeff Bush
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
# Various memory load/store combinations
#

# This assumes load_v works correctly.
.macro assert_vector_reg reg, location
            lea s20, \location
            load_v v20, (s20)
            cmpne_i s20, \reg, v20
            bz s20, 1f
            call fail_test
1:
.endmacro


           .text

           .globl    _start
           .align    4
_start:    lea s1, testvar1

            # Scalar loads (signed and unsigned, all widths and
            # valid alignments)
            load_u8 s2, (s1)    # Byte
            assert_reg s2, 0xcd
            load_u8 s3, 1(s1)
            assert_reg s3, 0xab
            load_u8 s4, 2(s1)
            assert_reg s4, 0x34
            load_u8 s5, 3(s1)
            assert_reg s5, 0x12

            load_s8 s6, (s1)    # Sign extension
            assert_reg s6, 0xffffffcd
            load_s8 s7, 1(s1)
            assert_reg s7, 0xffffffab
            load_s8 s8, 2(s1)
            assert_reg s8, 0x34
            load_s8 s9, 3(s1)
            assert_reg s9, 0x12

            load_u16 s10, (s1)    # Half word
            assert_reg s10, 0xabcd
            load_u16 s11, 2(s1)
            assert_reg s11, 0x1234

            load_s16 s12, (s1)    # Sign extension
            assert_reg s12, 0xffffabcd
            load_s16 s13, 2(s1)
            assert_reg s13, 0x00001234

            load_32 s14, (s1)    # Word
            assert_reg s14, 0x1234abcd

            # Scalar stores
            store_8 s2, 4(s1)
            store_8 s3, 5(s1)
            store_8 s4, 6(s1)
            store_8 s5, 7(s1)
            store_16 s10, 8(s1)
            store_16 s11, 10(s1)
            store_32 s14, 12(s1)

            # Reload stored words to ensure they come back correctly
            load_32 s15, 4(s1)
            assert_reg s15, 0x1234abcd
            load_32 s16, 8(s1)
            assert_reg s16, 0x1234abcd
            load_32 s17, 12(s1)
            assert_reg s17, 0x1234abcd

            # Block vector loads/store
            # Create a vector value manually (can't use load_v, since if that
            # was broken, this test might appear to work)
            move s0, 16         # Number of lanes (loop count)
            move s1, 0x1234     # Initial lane value
            move s2, 1          # Mask
            move v1, 0          # Destination vector
1:          move_mask v1, s2, s1# Load a lane
            sub_i s0, s0, 1     # Decrement loop count
            bz s0, 2f           # Done?
            shl s2, s2, 1       # Shift mask left
            add_i s1, s1, 0x15  # Increment lane value
            b 1b
2:

            # Test load_v/store_v
            # Note: here we are accessing testvar3, but use testvar2 address
            # with offset to verify it works correctly.
            lea s10, testvar2
            store_v v1, 64(s10)     # Store the value we created
            load_v v2, 64(s10)      # Load it back into another register
            cmpeq_i s0, v1, v2      # Are stored and loaded values equal?
            bnz s0, 1f              # if so, jump ahead
            call fail_test          # no, fail.

            # load_v_mask
            move v2, 0
            li s0, 0x55aa
            lea s10, testvar2
            load_v_mask v2, s0, (s10)
            lea s0, expected_result4
            load_v v3, (s0)
            cmpeq_i s0, v2, v3
            bnz s0, 1f
            call fail_test
1:

            # store_v_mask
            lea s10, testvar2
            load_v v1, (s10)
            li s0, 0x55aa
            lea s1, write_var
            store_v_mask v1, s0, (s1)
            load_v v2, (s1)
            lea s1, expected_result4
            load_v v3, (s1)
            cmpeq_i s0, v2, v3
            bnz s0, 1f
            call fail_test
1:

            # Gather load. Now that we've proved load_v works, can use that
            # to load indices.
1:          lea s0, shuffle_idx1
            load_v v4, (s0)
            lea s0, shuffle_idx2
            load_v v5, (s0)
            lea s1, testvar2
            add_i v4, v4, s1
            add_i v5, v5, s1

            load_gath v6, (v4)
            assert_vector_reg v6, expected_result1

            li s2, 0x5b03
            move v7, 0x17
            load_gath_mask v7, s2, (v4)
            assert_vector_reg v7, expected_result2

            # Scatter store
            lea s0, shuffle_idx1
            load_v v4, (s0)
            lea s0, shuffle_idx2
            load_v v5, (s0)
            lea s1, write_var
            add_i v4, v4, s1
            add_i v5, v5, s1

            store_scat v7, (v4)
            store_scat_mask v6, s2, (v5)

            # Reload destination locations
            lea s0, testvar3
            load_v v8, (s0)
            assert_vector_reg v8, expected_result3

            call pass_test

            .align 4
testvar1:   .long 0x1234abcd, 0, 0, 0
            .align 64
testvar2:   .long 0x2aa7d2c1, 0xeeb91caf, 0x304010ad, 0x96981e0d, 0x3a03b41f, 0x81363fee, 0x32d7bd42, 0xeaa8df61
            .long 0x9228d73e, 0xfcf12265, 0x2515fbeb, 0x6cd307a0, 0x2c18c1b8, 0xda8e48d5, 0x1f5c4bd2, 0xace51435
testvar3:   .long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
write_var:   .long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
shuffle_idx1:.long 56, 40, 0, 4, 24, 52, 16, 8, 12, 36, 44, 20, 32, 28, 60, 48

# Note: last lane is unaligned, but it is masked off so it shouldn't generate a fault.
shuffle_idx2: .long 12, 60, 16, 28, 48, 0, 52, 56, 40, 24, 8, 44, 4, 20, 36, 3

expected_result1: .long 0x1f5c4bd2, 0x2515fbeb, 0x2aa7d2c1, 0xeeb91caf, 0x32d7bd42, 0xda8e48d5, 0x3a03b41f, 0x304010ad
                  .long 0x96981e0d, 0xfcf12265, 0x6cd307a0, 0x81363fee, 0x9228d73e, 0xeaa8df61, 0xace51435, 0x2c18c1b8
expected_result2: .long 0x1f5c4bd2, 0x2515fbeb, 0x00000017, 0x00000017, 0x00000017, 0x00000017, 0x00000017, 0x00000017
                  .long 0x96981e0d, 0xfcf12265, 0x00000017, 0x81363fee, 0x9228d73e, 0x00000017, 0xace51435, 0x00000017
expected_result3: .long 0x1234, 0x1249, 0x125e, 0x1273, 0x1288, 0x129d, 0x12b2, 0x12c7, 0x12dc, 0x12f1, 0x1306, 0x131b, 0x1330, 0x1345, 0x135a, 0x136f
expected_result4: .long 0, 0xeeb91caf, 0, 0x96981e0d, 0, 0x81363fee, 0, 0xeaa8df61
                  .long 0x9228d73e, 0, 0x2515fbeb, 0, 0x2c18c1b8, 0, 0x1f5c4bd2, 0
