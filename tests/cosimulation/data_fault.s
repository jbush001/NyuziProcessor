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
# Data alignment fault
#

        	    .text
                .align	4
                
			    .globl	_start
			    .align	4
			    .type	main,@function
_start:		    move s1, -1
				setcr s1, 30	# Start all threads
		
				lea s0, fault_handler
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

fault_handler: 	getcr s11, 2		# Fault PC
				getcr s12, 3		# Reason
				getcr s13, 5		# Access address
				add_i pc, s11, 4	# Jump back to next instruction

			   .align 4
testvar1: 	   .long 0x1234abcd, 0, 0, 0
			
