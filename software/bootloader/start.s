# 
# Copyright (C) 2011-2014 Jeff Bush
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
