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


;
; Bytewise copy with four strands
;

			.regalias count s1
			.regalias source s2
			.regalias dest s3
			.regalias temp s4

_start:		temp = 0xf
			cr30 = temp				; start all strands

			count = mem_l[length]
			source = &dataStart
			dest = source + count

			count = count >> 2		; divide by 4
			temp = cr0				; get strand ID
			temp = temp * count		; compute offset
			source = source + temp	; compute source offset for this strand
			dest = dest + temp		; compute dest offset for this strand
			
loop:		temp = mem_b[source]
			mem_b[dest] = temp
			source = source + 1
			dest = dest + 1
			count = count - 1
			if count goto loop
			
			; Update number of finished strands
			s0 = &running_strands
retry:		s1 = mem_sync[s0]
			s1 = s1 - 1
			s2 = s1
			mem_sync[s0] = s1
			if !s1 goto retry

wait_done:	if s2 goto wait_done	; Will fall through on last ref (s2 = 1)
			cr31 = s0				; halt
							
running_strands: .word 4					

length:		.word 2048
dataStart:	.word 0
