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
# Test interrupt handling
#

        	    .text
                .align	4
                
			    .globl	_start
			    .align	4
			    .type	main,@function
_start:		    lea s0, interrupt_handler
			    setcr s0, 1			# Set interrupt handler address
				move s0, 1
				setcr s0, 4			# Enable interrupts
				move s1, 1000
				move s2, 7
				move s3, 17
				move s4, 31
					
				# Main loop. Do some computations to ensure state is handled correctly.
1:	            mull_i s2, s2, s3
				add_i s2, s2, s4
				sub_i s1, s1, 1
				btrue s1, 1b

				# Disable interrupts before finishing.  This avoids a race condition
				# where the emulator can begin processing an interrupt before 
				# halting.
				move s0, 0			
				setcr s0, 4
	
				# Halt
			    setcr s0, 29	
1: 		        goto 1b


interrupt_handler: 	getcr s11, 2		# Interrupt PC
				getcr s12, 3		# Reason
				move s13, 1
				eret
