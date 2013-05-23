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


_start:			s0 = &hello_str
				call print_string
done:			goto done
hello_str:		.string "Hello World"

; s0 = string to print
print_string:	s1 = 0xFFFF0018		; Serial device base
print_char:		s2 = mem_b[s0]
				if !s2 goto end_of_str	; Null terminator?
				s0 = s0 + 1
				
wait_ready:		s3 = mem_l[s1]			; Read status register
				if !s3 goto wait_ready	; If is busy, wait
				
				mem_l[s1 + 4] = s2		; write character
				goto print_char
				
end_of_str:		pc = link

				.emitliteralpool
				
