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


#define REG_ARITH_INST(__type__) (0xc0000000 | ((__type__) << 26))
#define IMM_ARITH_INST(__type__) ((__type__) << 28)
#define MEM_INST(__type__) (0x80000000 | ((__type__) << 25))

        	    .text
			    .globl	_start
			    .align	4
			    .type	main,@function
_start:			lea s0, fault_handler
			    setcr s0, 1			# Set fault handler address
				move s10, 1
				.long REG_ARITH_INST(3)
				move s10, 2
				.long REG_ARITH_INST(6)
				move s10, 3
				.long REG_ARITH_INST(7)	
				move s10, 4
				.long IMM_ARITH_INST(3)
				move s10, 5
				.long IMM_ARITH_INST(6)
				move s10, 6
				.long IMM_ARITH_INST(7)
				move s10, 7
				.long MEM_INST(9)
				move s10, 8
				.long MEM_INST(10)
				move s10, 9
				.long MEM_INST(11)
				move s10, 10
				.long MEM_INST(12)
				move s10, 11
				.long MEM_INST(15)
				move s10, 12
			    setcr s0, 29			; Halt
1: 		        goto 1b

fault_handler: 	getcr s11, 2		; Fault PC
				getcr s12, 3		; Reason
				add_i pc, s11, 4	; Jump back to next instruction

