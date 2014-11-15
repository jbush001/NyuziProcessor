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
# Write a pseudo random pattern into SDRAM, then read it back
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

