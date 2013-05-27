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
; Simple read/write memory test
; Flush a single word to memory and read it back
;

_start:			s0 = 0x10002000		; In SDRAM
				s2 = 0x55555555	
				
				mem_l[s0] = s2
				dflush(s0)
				dinvalidate(s0)
				stbar
				s3 = mem_l[s0]

				; Execute a second memory transaction to ensure state machine
				; finished the first one properly.
				mem_l[s0] = s3
				dflush(s0)
				dinvalidate(s0)
				stbar
				s4 = mem_l[s0]

				s0 = 0xFFFF0000
				mem_l[s0] = s4
done:			goto done


