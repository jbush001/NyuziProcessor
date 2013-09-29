; 
; Copyright 2011-2012 Jeff Bush
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



_start:			s0 = cr0			; Get strand ID
				s0 = s0 < 4			; Am I core 0?
				if s0 goto core0	; If so, branch

core1:			s2 = 100			; loop count
				s0 = &sharedvar		; write to shared variable
				s1 = mem_l[s0]		; Make resident in my cache
				s1 = 27				; load an interesting value to start
loop1:			mem_l[s0] = s1
				s1 = s1 + 1
				s2 = s2 - 1
				if s2 goto loop1
				cr29 = s0			; halt
done1:			goto done1

core0:			s2 = 100			; loop count
				s8 = &sharedvar		; Read from shared variable
loop0:			s9 = mem_l[s8]
				s2 = s2 - 1
				if s2 goto loop0
				cr29 = s0			; halt
done2:			goto done2

				.align 64
sharedvar:		.word 0
