# 
# Copyright 2011-2015 Jeff Bush
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#     http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
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
