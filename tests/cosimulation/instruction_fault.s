#
# Copyright 2015 Jeff Bush
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

.include "macros.inc"


#
# Instruction alignment fault
#

        	    .text
                .align	4

			    .globl	_start
			    .align	4
			    .type	main,@function
_start:			lea s0, fault_handler
			    setcr s0, CR_FAULT_HANDLER			# Set fault handler address

			    lea s1, branch_address
			    add_i s1, s1, 1
				move pc, s1
				move s10, 1			# Shouldn't happen (no branch)
				goto done

branch_address:	move s10, 2			# Shouldn't happen (bad address)
				goto done


fault_handler: 	getcr s11, CR_FAULT_PC
				getcr s12, CR_FAULT_REASON
				getcr s13, CR_FAULT_ADDRESS
				getcr s14, CR_FLAGS
				getcr s15, CR_SAVED_FLAGS

done:			HALT_CURRENT_THREAD
