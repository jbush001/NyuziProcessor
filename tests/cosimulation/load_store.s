# 
# Copyright (C) 2014 Jeff Bush
# 
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Library General Public
# License as published by the Free Software Foundation; either
# version 2 of the License, or (at your option) any later version.
# 
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Library General Public License for more details.
# 
# You should have received a copy of the GNU Library General Public
# License along with this library; if not, write to the
# Free Software Foundation, Inc., 51 Franklin St, Fifth Floor,
# Boston, MA  02110-1301, USA.
# 

#
# Test simple load stores
#

		.text
		.align	4

		.globl	_start
		.align	4
		.type	main,@function
_start:	lea s1, testvar1
		
		# Scalar loads (signed and unsigned, all widths and valid alignments)
		load_u8 s2, (s1)	# Byte
		load_u8 s3, 1(s1)
		load_u8 s4, 2(s1)
		load_u8 s5, 3(s1)

		load_s8 s6, (s1)	# Sign extension
		load_s8 s7, 1(s1)
		load_s8 s8, 2(s1)
		load_s8 s9, 3(s1)

		load_u16 s2, (s1)	# Half word
		load_u16 s3, 2(s1)

		load_s16 s4, (s1)	# Sign extension
		load_s16 s5, 2(s1)

		load_32 s8, (s1)	# Word

		# Scalar stores
		store_8 s2, 4(s1)
		store_8 s3, 5(s1)
		store_8 s4, 6(s1)
		store_8 s5, 7(s1)
		store_16 s6, 8(s1)
		store_16 s7, 10(s1)
		store_32 s8, 12(s1)
		
		# Reload stored words to ensure they come back correctly
		load_32 s10, 4(s1)
		load_32 s11, 8(s1)
		load_32 s12, 12(s1)

		# Block vector loads/store
		lea s10, testvar2
		load_v v1, (s10)
		store_v v1, 64(s10)
		load_v v2, 64(s10)
		
		# Gather load
		load_v v4, shuffleIdx
		lea s1, testvar2
		add_i v4, v4, s1
		load_gath v3, (v4)
		
		# Scatter store
		load_v v5, testvar2
		load_v v4, shuffleIdx
		lea s1, testvar4
		add_i v4, v4, s1
		store_scat v5, (v4)
		
		# Synchronized
		lea s0, test_sync
		load_sync s1, (s0)
		store_sync s2, (s0)
		move s3, s2		# Check return value
		load_sync s3, (s0)
		store_32 s4, (s0)	# Should invalidate cache line
		store_sync s4, (s0)	# should fail
		move s5, s4		# Check return value

		setcr s0, 29		; Halt
done: goto done

			.align 4
testvar1: 	.long 0x1234abcd, 0, 0, 0
test_sync:  .long 0
			.align 64
testvar2:	.long 0x2aa7d2c1, 0xeeb91caf, 0x304010ad, 0x96981e0d, 0x3a03b41f, 0x81363fee, 0x32d7bd42, 0xeaa8df61
			.long 0x9228d73e, 0xfcf12265, 0x2515fbeb, 0x6cd307a0, 0x2c18c1b8, 0xda8e48d5, 0x1f5c4bd2, 0xace51435
testvar3:	.long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
testvar4:   .long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
shuffleIdx: .long 56, 40, 0, 4, 24, 52, 16, 8, 12, 36, 44, 20, 32, 28, 60, 48

			