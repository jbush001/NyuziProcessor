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


;
; Write a pseudo random pattern into memory, then read it back
;
TEST_LENGTH=0x8000000


_start:			s0 = 0x10000000		; Address of SDRAM
				s1 = TEST_LENGTH	; Size to copy
				s2 = 0xdeadbeef		; seed
				s3 = 1103515245		; a for generator
				s4 = 12345			; c for generator

fill_loop:		mem_l[s0] = s2
				
				; Compute next random number
				s2 = s2 * s3
				s2 = s2 + s4
				
				; Increment and loop
				s1 = s1 - 4
				s0 = s0 + 4
				if s1 goto fill_loop

				; Now check
				s0 = 0x10000000		; Address of SDRAM
				s1 = TEST_LENGTH	; Size to copy 
				s2 = 0xdeadbeef		; a pattern

check_loop:		s5 = mem_l[s0]
				s6 = s5 <> s2
				if s6 goto error
				
				; Compute next random number
				s2 = s2 * s3
				s2 = s2 + s4
				
				; Increment and loop
				s1 = s1 - 4
				s0 = s0 + 4
				if s1 goto check_loop

success:		s0 = 0xFFFF0004	; Green LEDs
				s1 = 0xFFFF
				mem_l[s0] = s1
done0:			goto done0
				
error:			s0 = 0xFFFF0000	; Red LEDS
				s1 = 0xFFFF
				mem_l[s0] = s1
done1:			goto done1
