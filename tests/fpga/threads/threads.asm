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


_start:			u0 = cr0			; get strand ID
				u0 = u0 << 2	; Multiply by 4 to get offset
				u1 = &pc_ptr
				u1 = u1 + u0	; index into table
				pc = mem_l[u1]

pc_ptr:			.word start0, start1, start2, start3


start0:			u0 = 15
				cr30 = u0			; Start all hardware threads
				s0 = 0xFFFF0008		; Device address
				s1 = 600000		; Delay value
				goto display_common

start1: 		s0 = 0xFFFF000C		; Device address
				s1 = 900000		; Delay value
				goto display_common

start2:			s0 = 0xFFFF0010		; Device address
				s1 = 1200000		; Delay value
				goto display_common


start3:			s0 = 0xFFFF0014		; Device address
				s1 = 1500000		; Delay value

display_common:	s2 = 0
display_loop:	s4 = &segment
				s4 = s4 + s2		; pointer into segment table
				s4 = mem_b[s4]		; look up digits
				mem_l[s0] = s4		; write to display

				s4 = s1
delayloop:		s4 = s4 - 1
				if s4 goto delayloop

				s2 = s2 + 1
				s4 = s2 > 9		; Has this wrapped around?
				if !s4 goto display_loop	; If not, draw next one
				s2 = 0			; start over
				goto display_loop

				.emitliteralpool

segment:		.byte 0x40
				.byte 0x79
				.byte 0x24
				.byte 0x30
				.byte 0x19
				.byte 0x12
				.byte 0x02
				.byte 0x78
				.byte 0x00
				.byte 0x10
				
		
				
