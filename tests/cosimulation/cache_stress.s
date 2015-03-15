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
# L2 cache stress test. Generate stores to a series of randomly generated
# addresses in a 512k region, which should generate a lot of cache misses
# and evictions.
# Each thread stores to rand() * 4 * NUM_THREADS + thread_id.  As a consequence,
# each memory location can be assigned by only one thread. This avoids a problem
# that would occur when write ordering differs between the emulator and cycle
# accurate model
#

				.globl _start
_start:			move s1, -1
				setcr s1, 30		# Start all threads

				getcr s1, 0			# seed for RNG (based on thread ID)
				load_32 s5, num_iterations
				load_32 s2, generator_a
				load_32 s3, generator_c
				getcr s8, 0			# get thread ID
				shl s8, s8, 2		# Compute thread write offset (thread * 4)
				move s0, 7			# Initialize value to write
				
main_loop:		mull_i s1, s1, s2	# Generate next random number
				add_i s1, s1, s3

				shr s4, s1, 17		# Chop high bits (0-32k)
				shl s4, s4, 4		# Multiply by 16 (four threads times four bytes, 512k)
				add_i s4, s4, s8	# Add thread offset (0, 4, 8, 12)
				add_i s4, s4, 512	# Add to start of write region

				store_32 s0, (s4)	# Write the word

				add_i s0, s0, 13	# Increment write value
				sub_i s5, s5, 1		# Decrement count
				btrue s5, main_loop
				
				setcr s0, 29
1: 				goto 1b

generator_a:    .long 1103515245
generator_c:    .long 12345   
num_iterations: .long 10000


				
