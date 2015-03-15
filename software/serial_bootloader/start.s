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
_start:				getcr s0, 0
					btrue s0, launch2nd

					; Set up stack
					load_32 sp, stack_base
					call main

launch2nd:			load_32 s0, startAddress
					move pc, s0					

stack_base:			.long 0x2000

					.globl startAddress
startAddress: 		.long 0
