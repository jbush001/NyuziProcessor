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


_start:			s0 = 0xFFFF0000		; LED Device address
				s1 = 1				; Current display value
				s3 = 3000000		; Delay

loop0:			mem_l[s0] = s1		; Update LEDs

				; Wait 500 ms
				s4 = s3
delay0:			s4 = s4 - 1
				if s4 goto delay0

				; Rotate left
				s1 = s1 << 1

				; Check if we've wrapped
				s2 = s1 >> 18
				if !s2 goto loop0	; No, so keep updating
				s1 = 1				; Reset to beginning
				goto loop0

				.emitliteralpool
				
