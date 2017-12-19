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

#include "../../asm_macros.inc"

#
# This validates the memory subsystem by writing a pseudorandom memory pattern
# across all of SDRAM, then reading it back to verify it is unchanged.  It
# assumes 128MB of SDRAM, starting at address 0. It skips the first 8k, which
# contains this code. The test takes around 30 seconds to run, during which
# there isn't any feedback.  When it completes, it will print PASS or FAIL
# to the serial port.
#

#define BASE_ADDR 0x2000
#define TEST_LENGTH (0x8000000 - 0x2000)
#define SEED 0xdeadbeef
#define GENERATOR_A 1103515245
#define GENERATOR_C 12345
#define DEVICE_BASE 0xffff0000


                .global _start
_start:         li s0, BASE_ADDR
                li s1, TEST_LENGTH
                li s2, SEED
                li s3, GENERATOR_A
                li s4, GENERATOR_C

fill_loop:      store_32 s2, (s0)

                # Compute next random number
                mull_i s2, s2, s3
                add_i s2, s2, s4

                # Increment and loop
                add_i s0, s0, 4      # Increment pionter
                sub_i s1, s1, 4      # Decrement count
                bnz s1, fill_loop

                # Now check the pattern
                li s0, BASE_ADDR
                li s1, TEST_LENGTH    # Size to copy
                li s2, SEED

check_loop:     load_32 s5, (s0)
                cmpne_i s6, s5, s2
                bnz s6, error

                # Compute next random number
                mull_i       s2, s2, s3
                add_i       s2, s2, s4

                # Increment and loop
                add_i s0, s0, 4      # Increment pointer
                sub_i s1, s1, 4      # Decrement count
                bnz s1, check_loop
                call pass_test

error:          call fail_test
