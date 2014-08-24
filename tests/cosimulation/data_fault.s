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
# Data alignment fault
#

        	    .text
                .align	4
                
			    .globl	_start
			    .align	4
			    .type	main,@function
_start:		    lea s0, fault_handler
			    setcr s0, 1			# Set fault handler address
			    lea s1, testvar1
			    add_i s1, s1, 1
			    load_32 s2, (s1)	# Invalid word alignment, load
				move s10, 1
			    store_32 s2, (s1)	# Invalid word alignment, store
				move s10, 2
			    load_s16 s2, (s1)	# Invalid short alignment, load
				move s10, 3
			    load_u16 s2, (s1)	# Invalid unsigned short alignment, load
				move s10, 4
			    store_16 s2, (s1)	# Invalid short alignment, store
				move s10, 5
				load_v v2, (s1)		# Invalid vector alignment, load
				move s10, 6
				store_v v2, (s1)	# Invalid vector alignment, store
			    setcr s0, 29		# Halt
1: 		        goto 1b

fault_handler: 	getcr s11, 2		# Fault address
				getcr s12, 3		# Reason
				add_i pc, s11, 4	# Jump back to next instruction

			   .align 4
testvar1: 	   .long 0x1234abcd, 0, 0, 0
			