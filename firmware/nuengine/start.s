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

; Stacks:
; 0x1c000 - 0x1fffc  thread 0
; 0x18000 - 0x1bffc  thread 1
; 0x14000 - 0x17ffc  thread 2
; 0x10000 - 0x13ffc  thread 3

					.text
					.globl _start
					.align 4
					.type _start,@function
_start:				move s0, 15
					setcr s0, 30		; Start all threads

					load.32 sp, stacks_base
					getcr s0, 0			; get my strand ID
					shl s0, s0, 14		; 16k bytes per stack
					sub.i sp, sp, s0	; Compute stack address

					call main
					setcr s0, 29		; Stop thread
done:				goto done

stacks_base:		.word 0x20000

