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


# This only works for the emulator environment, since it assumes memory 
# starts at address 0.
#
# Memory map:
# 00000000   +---------------+
#            |     code      |
# 001F0000   +---------------+
#            |     stacks    |
# 00200000   +---------------+
#            |  framebuffer  |
# 0032C000   +---------------+
#            |     heap      |
#            +---------------+

#
# When the processor boots, only one hardware thread will be enabled.  This will
# begin execution at address 0, which will jump immediately to _start.
# This thread will perform static initialization (for example, calling global
# constructors).  When it has completed, it may set a control register to enable 
# the other threads (in main), which will also branch through _start. However, 
# they will branch over the initialization routine and go to main directly.
#

					.text
					.globl _start
					.align 4
					.type _start,@function
_start:				
					# Set up stack
					getcr s0, 0			# get my strand ID
					shl s0, s0, 14		# 16k bytes per stack
					load_32 sp, stacks_base
					sub_i sp, sp, s0	# Compute stack address

					# Only thread 0 does initialization.  Skip for 
					# other threads (note that other threads will only
					# arrive here after thread 0 has completed initialization
					# and started them).
					btrue s0, do_main

					# Call global initializers
					load_32 s24, init_array_start
					load_32 s25, init_array_end
init_loop:			cmpeq_i s0, s24, s25
					btrue s0, do_main
					load_32 s0, (s24)
					add_i s24, s24, 4
					call s0
					goto init_loop

					move s0, 0	# Set argc to 0
do_main:			call main
					setcr s0, 31 # Stop all threads
1:					goto 1b

stacks_base:		.long 0x200000
init_array_start:	.long __init_array_start
init_array_end:		.long __init_array_end
