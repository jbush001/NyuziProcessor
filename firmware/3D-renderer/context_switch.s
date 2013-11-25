; 
; Copyright 2013 Jeff Bush
; 
; Licensed under the Apache License, Version 2.0 (the "License");
; you may not use this file except in compliance with the License.
; You may obtain a copy of the License at
; 
;     http://www.apache.org/licenses/LICENSE-2.0
; 
; Unless required by applicable law or agreed to in writing, software
; distributed under the License is distributed on an "AS IS" BASIS,
; WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
; See the License for the specific language governing permissions and
; limitations under the License.
; 


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

