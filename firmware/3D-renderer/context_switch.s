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


;
; Push all callee-save registers on stack.  Swap stacks.
; s0 - address to save old stack pointer
; s1 - new stack pointer
;

						.text
						.globl context_switch
						.type context_switch,@function
						.align 4

context_switch:			sub_i sp, sp, 448
						store_32 sp, (s0)		; store old stack pointer

						; Save callee saved registers
						store_32 s24, 0(sp)
						store_32 s25, 4(sp)
						store_32 s26, 8(sp)
						store_32 s27, 12(sp)
						store_32 fp, 16(sp)
						store_32 link, 20(sp)
						store_v v26, 64(sp)
						store_v v27, 128(sp)
						store_v v28, 192(sp)
						store_v v29, 256(sp)
						store_v v30, 320(sp)
						store_v v31, 384(sp)
						
						move sp, s1		; load new stack pointer

						; Load registers from other task
						load_32 s24, 0(sp)
						load_32 s25, 4(sp)
						load_32 s26, 8(sp)
						load_32 s27, 12(sp)
						load_32 fp, 16(sp)
						load_32 link, 20(sp)
						load_v v26, 64(sp)
						load_v v27, 128(sp)
						load_v v28, 192(sp)
						load_v v29, 256(sp)
						load_v v30, 320(sp)
						load_v v31, 384(sp)
						add_i sp, sp, 448
						ret

