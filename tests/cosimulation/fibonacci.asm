;
; Copyright 2011-2013 Jeff Bush
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


_start:		u29 = mem_l[initial_sp]
			u0 = 9					; depth
			
			call	fib
			
			cr31 = s0				; Halt
	
fib:		sp = sp - 12
			mem_l[sp] = link
			mem_l[sp + 4] = s1		; save this
			mem_l[sp + 8] = s2		; save this

			if s0 goto notzero
			goto return				; return 0
notzero:	s0 = s0 - 1
			if s0 goto notone
			s0 = s0 + 1
			goto return				; return 1
notone:		s2 = s0	- 1				; save next value
			call fib				; call fib with n - 1
			s1 = s0					; save the return value
			s0 = s2					; restore parameter
			call fib				; call fib with n - 2
			s0 = s0 + s1			; add the two results
return:		link = mem_l[sp]
			s2 = mem_l[sp + 8]
			s1 = mem_l[sp + 4]
			sp = sp + 12
			pc = link	
				
initial_sp: .word 0x10000