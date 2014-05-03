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
# Test various comparisions
#

.equ BU, 0xc0800018	
.equ BS, 0x60123498	
.equ SM, 1

			.globl _start
_start:		lea s0, ivec1
			load_v v0, (s0)
			load_v v1, 64(s0)

			; Vector integer comparisons
			seteq_i s0, v0, v1
			setne_i s1, v0, v1
			setgt_i s2, v0, v1
			setlt_i s3, v0, v1
			setge_i s4, v0, v1
			setle_i s5, v0, v1
			setgt_u s6, v0, v1
			setlt_u s7, v0, v1
			setge_u s8, v0, v1
			setle_u s9, v0, v1

			; Vector/scalar integer comparison
			load_32 s20, ival3
			seteq_i s0, v0, s20
			setne_i s1, v0, s20
			setgt_i s2, v0, s20
			setlt_i s3, v0, s20
			setge_i s4, v0, s20
			setle_i s5, v0, s20
			setgt_u s6, v0, s20
			setlt_u s7, v0, s20
			setge_u s8, v0, s20
			setle_u s9, v0, s20
			
			// Scalar integer comparison
			load_32 s21, ival4
			seteq_i s0, s21, s20
			setne_i s1, s21, s20
			setgt_i s2, s21, s20
			setlt_i s3, s21, s20
			setge_i s4, s21, s20
			setle_i s5, s21, s20
			setgt_u s6, s21, s20
			setlt_u s7, s21, s20
			setge_u s8, s21, s20
			setle_u s9, s21, s20

			// Vector floating point comparison
			lea s0, fvec1
			load_v v0, (s0)
			load_v v1, 64(s0)
			setgt_f s2, v0, v1
			setlt_f s3, v0, v1
			setge_f s4, v0, v1
			setle_f s5, v0, v1

			// vector/scalar floating point comparison
			load_32 s10, fval3
			load_32 s11, fval4
			setgt_f s2, v0, s10
			setlt_f s3, v0, s10
			setge_f s4, v0, s10
			setle_f s5, v0, s10
			setgt_f s6, v0, s11
			setlt_f s7, v0, s11
			setge_f s8, v0, s11
			setle_f s9, v0, s11

			// sclar floating point comparison
			setgt_i s0, s10, s11
			setlt_i s1, s10, s11
			setle_i s2, s10, s11
			setge_i s3, s10, s11
			setgt_i s4, s11, s10
			setlt_i s5, s11, s10
			setle_i s6, s11, s10
			setge_i s7, s11, s10

			setcr s0, 29
done: 		goto done

			.align 64
fvec1: .float -7.5, -6.5, -5.5, -4.5, -3.5, -2.5, -1.5, -0.5, 0.5, 1.5, 2.5, 3.5, 4.5, 5.5, 6.5, 7.5
fvec2: .float 7.5, 6.5, 5.5, 4.5, 3.5, 2.5, 1.5, 0.5, -0.5, -1.5, -2.5, -3.5, -4.5, -5.5, -6.5, -7.5
ivec1: .long BU, BS, BU, BS, BU, SM, BS, SM, BU, BS, BU, BS, BU, SM, BS, SM 
ivec2: .long BU, BS, BS, BU, SM, BU, SM, BS, BU, BS, BS, BU, SM, BU, SM, BS
ival3: .long BU
ival4: .long BS
fval3: .float 1.0
fval4: .float -1.0

