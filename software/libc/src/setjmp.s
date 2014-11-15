# 
# Copyright (C) 2011-2014 Jeff Bush
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


				.global setjmp
				.type setjmp,@function
setjmp:			# Align s0 to a 64 byte boundary to do vector stores
				add_i s0, s0, 63		
				move s1, 63
				xor s1, s1, -1
				and s0, s0, s1

				# Copy callee-saved registers into structure
				store_v v26, 0(s0)
				store_v v27, 64(s0)
				store_v v28, 128(s0)
				store_v v29, 192(s0)
				store_v v30, 256(s0)
				store_v v31, 320(s0)
				store_32 s27, 384(s0)
				store_32 fp, 388(s0)
				store_32 sp, 392(s0)
				store_32 ra, 396(s0)	# Will return to this address
				move s0, 0
				move pc, ra


				.global longjmp
				.type longjmp,@function
longjmp:		# Align s0 to a 64 byte boundary to do vector loads
				add_i s0, s0, 63		
				move s2, 63
				xor s2, s2, -1
				and s0, s0, s2

				# Copy callee-saved registers out of structure
				load_v v26, 0(s0)
				load_v v27, 64(s0)
				load_v v28, 128(s0)
				load_v v29, 192(s0)
				load_v v30, 256(s0)
				load_v v31, 320(s0)
				load_32 s27, 384(s0)
				load_32 fp, 388(s0)
				load_32 sp, 392(s0)
				load_32 s2, 396(s0)	# Get return address
				move s0, s1		    # Set return value
				move pc, s2			# Jump back

