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


#
# This validates the memory subsystem by writing a pseudorandom memory pattern
# across all of SDRAM, then reading it back to verify it is unchanged.  It 
# assumes SDRAM starts at address 0x10000000 and is 128Mb.  The test takes 
# around 30 seconds to run, during which there isn't any feedback.  When it 
# completes, it will light up all of the green LEDs to indicate success and
# all of the red LEDs to indicate failure.
#

                .global _start
_start:			load_32     s0, sdram_addr		# Address of SDRAM
				load_32     s1, test_length	# Size to copy
                load_32     s2, seed
                load_32     s3, generator_a
                load_32     s4, generator_c

fill_loop:		store_32    s2, (s0)
				
				# Compute next random number
                mull_i       s2, s2, s3
                add_i       s2, s2, s4
				
				# Increment and loop
                add_i       s0, s0, 4      # Increment pionter
                sub_i       s1, s1, 4      # Decrement count
                btrue       s1, fill_loop

				# Now check the pattern
                load_32     s0, sdram_addr	# Address of SDRAM
				load_32     s1, test_length	# Size to copy
                load_32     s2, seed

check_loop:		load_32 s5, (s0)
                cmpne_i s6, s5, s2
                btrue s6, error
				
				# Compute next random number
                mull_i       s2, s2, s3
                add_i       s2, s2, s4
				
				# Increment and loop
                add_i       s0, s0, 4      # Increment pionter
                sub_i       s1, s1, 4      # Decrement count
                btrue       s1, check_loop

success:		load_32 s0, device_base
                move s1, 0xffff
                store_32 s1, 4(s0)          # Green LEDs
done0:			goto done0
				
error:			load_32 s0, device_base
                move s1, 0xffff
                store_32 s1, 0(s0)          # Red LEDs
done1:			goto done1

sdram_addr:     .long 0x10000000
test_length:    .long 0x8000000
seed:           .long 0xdeadbeef
generator_a:    .long 1103515245
generator_c:    .long 12345   
device_base:    .long 0xffff0000

