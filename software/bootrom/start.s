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


# Execution starts here. Set up the stack and call into the serial bootloader.
# When other threads are started (which will be done by the program that was
# loaded, they will start here, but skip execution of the serial bootloader and
# jump directly to address 0, where the new program will dispatch them 
# appropriately.

					.text
					.globl _start
					.align 4
					.type _start,@function
_start:				getcr s0, 0
					btrue s0, jump_to_zero

					# Set up stack
					load_32 sp, temp_stack
					call main

jump_to_zero: 		move s0, 0
					move pc, s0					

temp_stack:			.long 0x400000
