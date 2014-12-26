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


        	    .text
			    .globl	_start
			    .align	4
			    .type	main,@function
_start:			lea s0, fault_handler
			    setcr s0, 1			# Set fault handler address
				move s10, 1
				.long 0xcc000000		; Register arith, fmt 3
				move s10, 2
				.long 0xd8000000		; Register arith, fmt 6
				move s10, 3
				.long 0xdc000000		; Register arith, fmt 7
				move s10, 4
			    setcr s0, 29			; Halt
1: 		        goto 1b

fault_handler: 	getcr s11, 2		; Fault PC
				getcr s12, 3		; Reason
				getcr s13, 5		; Access address
				add_i pc, s11, 4	; Jump back to next instruction

