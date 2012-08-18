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

_start		s2 = 0xf
			cr30 = s2		; Enable all strands

			; load something interesting into scratchpad registers
			s3 = 4051
			s3 = s3 * 4049
			s4 = s3 * 59
			s5 = s4 * 103
			s6 = s5 ^ s4
			s7 = s6 * 17
			v3 = s3
			v4 = s4
			v5 = s5
			v6 = s6
			v7 = s7
			v3{s7} = v3 ^ v4
			v4{s6} = v4 ^ v5
			v5{s5} = v5 ^ v6
			v6{s4} = v6 ^ v7
			v7{s3} = v7 ^ v3
			
			s2 = cr0		; Get strand ID
			
			; set up address of private memory region (s0 is public and is left set to 0)
			s1 = s2 + 1	
			s1 = s1 << 17	; Multiply by 128k, so each strand starts on a new page

			; Set a vector with incrementing values
			s8 = 1
			s8 = s8 << 14
			s8 = s8 - 1			; s8 = ffff
loop0		v0{s8} = v0 + 8
			s8 = s8 >> 1
			if s8 goto loop0

			v1 = v0 + s1	; Add offsets to base pointer

			; Compute branch address			
			s2 = s2 << 10	; Multiply by 1024 bytes (256 instructions)
			pc = pc + s2	; jump to start address for this strand

