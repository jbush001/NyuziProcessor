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




					.text
					.globl _start
					.align 4
					.type _start,@function
_start:				move s0, 15
					setcr s0, 30		# Start all threads

					load_32 sp, stacks_base
					getcr s0, 0			# get my strand ID
					shl s0, s0, 13		# 8192 bytes per stack
					add_i sp, sp, s0	# Compute stack address

					call main
					setcr s0, 29		# Stop thread
done:				goto done

# end of FB + 8192 bytes
stacks_base:		.long 0x1012e000	

