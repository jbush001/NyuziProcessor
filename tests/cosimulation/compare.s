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
			cmpeq_i s0, v0, v1
			cmpne_i s1, v0, v1
			cmpgt_i s2, v0, v1
			cmplt_i s3, v0, v1
			cmpge_i s4, v0, v1
			cmple_i s5, v0, v1
			cmpgt_u s6, v0, v1
			cmplt_u s7, v0, v1
			cmpge_u s8, v0, v1
			cmple_u s9, v0, v1

			; Vector/scalar integer comparison
			load_32 s20, ival3
			cmpeq_i s0, v0, s20
			cmpne_i s1, v0, s20
			cmpgt_i s2, v0, s20
			cmplt_i s3, v0, s20
			cmpge_i s4, v0, s20
			cmple_i s5, v0, s20
			cmpgt_u s6, v0, s20
			cmplt_u s7, v0, s20
			cmpge_u s8, v0, s20
			cmple_u s9, v0, s20
			
			// Scalar integer comparison
			load_32 s21, ival4
			cmpeq_i s0, s21, s20
			cmpne_i s1, s21, s20
			cmpgt_i s2, s21, s20
			cmplt_i s3, s21, s20
			cmpge_i s4, s21, s20
			cmple_i s5, s21, s20
			cmpgt_u s6, s21, s20
			cmplt_u s7, s21, s20
			cmpge_u s8, s21, s20
			cmple_u s9, s21, s20

			// Vector floating point comparison
			lea s0, fvec1
			load_v v0, (s0)
			load_v v1, 64(s0)
			cmpgt_f s2, v0, v1
			cmplt_f s3, v0, v1
			cmpge_f s4, v0, v1
			cmple_f s5, v0, v1

			// vector/scalar floating point comparison
			load_32 s10, fval3
			load_32 s11, fval4
			cmpgt_f s2, v0, s10
			cmplt_f s3, v0, s10
			cmpge_f s4, v0, s10
			cmple_f s5, v0, s10
			cmpgt_f s6, v0, s11
			cmplt_f s7, v0, s11
			cmpge_f s8, v0, s11
			cmple_f s9, v0, s11

			// sclar floating point comparison
			cmpgt_i s0, s10, s11
			cmplt_i s1, s10, s11
			cmple_i s2, s10, s11
			cmpge_i s3, s10, s11
			cmpgt_i s4, s11, s10
			cmplt_i s5, s11, s10
			cmple_i s6, s11, s10
			cmpge_i s7, s11, s10

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

