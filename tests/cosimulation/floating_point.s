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


			.globl _start
_start:		lea s0, ops
			lea s15, end
test_loop:	load_32 s1, (s0)
			load_32 s2, 4(s0)
			add_f s3, s1, s2
			sub_f s4, s1, s2
			mul_f s5, s1, s2
			ftoi s6, s1
			ftoi s7, s2
			itof s8, s6
			itof s9, s7
			reciprocal s10, s1
			reciprocal s11, s2
			add_i s0, s0, 8
			cmpge_i s6, s0, s15
			bfalse s6, test_loop
			setcr s0, 29
done: 		goto done

ops:		.float 17.79, 19.32 			; Exponents are equal.  This will carry into the next significand bit
			.float 0.34, 44.23 				; Exponent 2 larger
			.float 44.23, 0.034 			; Exponent 1 larger
			.float -1.0, 5.0 				; First element is negative and has smaller exponent
			.float -5.0, 1.0 				; First element is negative and has larger exponent		
			.float 5.0, -1.0 				; Second element is negative and has smaller exponent
			.float 1.0, -5.0 				; Second element is negative and has larger exponent
			.float 5.0, 0.0 				; Zero identity (zero is a special case in IEEE754)
			.float 0.0, 5.0
			.float 0.0, 0.0
			.float 1.0, 1.0					; Multiplication normalized
			.float 7.0, -7.0 				; Sum is zero, positive first operand
			.float -7.0, 7.0				; Sum is zero, negative first operand
			.float -7.0, -7.0				; Difference is zero, both negative
			.float 1000000.0, 0.0000001 	; Second op is lost because of precision
			.float 0.0000001, 0.00000001 	; Very small number 
			.float 1000000.0, 10000000.0 	; Very large number
			.float -0.0, 2.323				; negative zero
			.float 2.323, -0.0				; negative zero
			.float 5.67666007898e-42, 0.0	; subnormal minus zero
			.float nan, 1
			.float 1, nan
			.float nan, nan
			.float inf, 1
			.float inf, inf
			.float 1, inf
			.float inf, 0
			.float 0, inf
			
			; Regression cases
			.long 0x3e841893, 0x40780fe1	; Multiplication round causes overflow, need to adjust exponent
			.long 0xea5d5488, 0xea5d5b5b	; Addition overflow and post normalization round
			.long 0x3b088889, 0x40c00000	; Multiplication post normalization round
			.long 0xbc91da53, 0x3f400000	; This one should not do post normalization round
			.long 0x3ebcf372, 0xbeb33333	
			.long 0x3ebcf372, 0xbd4a59cc
#			.long 0x3e3b0350, 0xbd9634dd
end: 		.long 0
			
