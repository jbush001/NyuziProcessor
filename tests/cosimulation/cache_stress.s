# 
# Copyright (C) 2011-2014 Jeff Bush
# 
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
# 


#
# L2 cache stress test
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


				
