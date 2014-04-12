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
; When the processor boots, only one hardware thread will be enabled.  This will
; begin execution at address 0, which will jump immediately to _start.
; This thread will perform static initialization (for example, calling global
; constructors).  When it has completed, it will set a control register to enable 
; the other threads, which will also branch through _start. However, they will branch 
; over the initialization routine and go to main directly.
;

					.text
					.globl _start
					.align 4
					.type _start,@function
_start:				
					; Set up stack
					getcr s0, 0			; get my strand ID
					shl s0, s0, 16		; 64k bytes per stack
					load_32 sp, stacks_base
					sub_i sp, sp, s0	; Compute stack address

					; Set the strand enable mask to the other threads will start.
					move s0, 0xffffffff
					setcr s0, 30

skip_init:			call main
					setcr s0, 29 ; Stop thread, mostly for simulation
done:				goto done

stacks_base:		.long 0x100000
init_array_start:	.long __init_array_start
init_array_end:		.long __init_array_end
