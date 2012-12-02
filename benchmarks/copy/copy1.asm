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
; Bytewise copy with a single strand
;

			.regalias count s1
			.regalias source s2
			.regalias dest s3
			.regalias temp s4

_start:		count = mem_l[length]
			source = &dataStart
			dest = source + count
			
loop:		temp = mem_b[source]
			mem_b[dest] = temp
			source = source + 1
			dest = dest + 1
			count = count - 1
			if count goto loop
			
			cr31 = s0		; halt simulation

length:			.word 2048
dataStart:		.word 0
