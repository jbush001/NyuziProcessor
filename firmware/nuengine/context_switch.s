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
; Push all callee-save registers on stack (s15-s30, v15-v31).  Swap stacks.
; s0 - address to save old stack pointer
; s1 - new stack pointer
;

						.text
						.globl context_switch
						.type context_switch,@function
						.align 4

context_switch:			sub.i sp, sp, 1088
						store.32 sp, (s0)		; store old stack pointer

						; Save callee saved registers
						store.32 s15, 0(sp)
						store.32 s16, 4(sp)
						store.32 s17, 8(sp)
						store.32 s18, 12(sp)
						store.32 s19, 16(sp)
						store.32 s20, 20(sp)
						store.32 s21, 24(sp)
						store.32 s22, 28(sp)
						store.32 s23, 32(sp)
						store.32 s24, 36(sp)
						store.32 s25, 40(sp)
						store.32 s26, 44(sp)
						store.32 s27, 48(sp)
						store.32 fp, 52(sp)
						store.32 link, 56(sp)
						store.v v16, 64(sp)
						store.v v17, 128(sp)
						store.v v18, 192(sp)
						store.v v19, 256(sp)
						store.v v20, 320(sp)
						store.v v21, 384(sp)
						store.v v22, 448(sp)
						store.v v23, 512(sp)
						store.v v24, 576(sp)
						store.v v25, 640(sp)
						store.v v26, 704(sp)
						store.v v27, 768(sp)
						store.v v28, 832(sp)
						store.v v29, 896(sp)
						store.v v30, 960(sp)
						
						move sp, s1		; load new stack pointer

						; Load registers from other task
						load.32 s15, 0(sp)
						load.32 s16, 4(sp)
						load.32 s17, 8(sp)
						load.32 s18, 12(sp)
						load.32 s19, 16(sp)
						load.32 s20, 20(sp)
						load.32 s21, 24(sp)
						load.32 s22, 28(sp)
						load.32 s23, 32(sp)
						load.32 s24, 36(sp)
						load.32 s25, 40(sp)
						load.32 s26, 44(sp)
						load.32 s27, 48(sp)
						load.32 fp, 52(sp)
						load.32 link, 56(sp)
						load.v v16, 64(sp)
						load.v v17, 128(sp)
						load.v v18, 192(sp)
						load.v v19, 256(sp)
						load.v v20, 320(sp)
						load.v v21, 384(sp)
						load.v v22, 448(sp)
						load.v v23, 512(sp)
						load.v v24, 576(sp)
						load.v v25, 640(sp)
						load.v v26, 704(sp)
						load.v v27, 768(sp)
						load.v v28, 832(sp)
						load.v v29, 896(sp)
						load.v v30, 960(sp)
						add.i sp, sp, 1088
						ret

