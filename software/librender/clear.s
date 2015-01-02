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

#
# Clear a 64x64 section of surface memory to a given value
#
# void fast_clear64x64(void *ptr, int stride, int value);
#


					.globl fast_clear64x64
					.type fast_clear64x64,@function
					.text

fast_clear64x64:	move v0, s2			# put value in vector register
					move s3, 64			# row count
loop0: 				store_v v0, (s0)	# Write entire row unrolled
					store_v v0, 64(s0)
					store_v v0, 128(s0)
					store_v v0, 192(s0)		
					add_i s0, s0, s1	# Next row	
					sub_i s3, s3, 1		# Decrement row count
					btrue s3, loop0		# Branch if not done
					ret
