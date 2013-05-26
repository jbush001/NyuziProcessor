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

				TOTAL_CHARS = 89
				LINE_LENGTH = 72

_start:			.regalias pat_base s0
				.regalias start_offset s1
				.regalias current_index s2
				.regalias ptr s3
				.regalias char s4
				.regalias status s5
				.regalias device_base s6
				.regalias line_count s7
				.regalias tmp s8

				pat_base = &pattern
				device_base = 0xffff0018

				line_count = 0
				current_index = 0
				start_offset = 0

loop0:			ptr = pat_base + current_index
				char = mem_b[ptr]

wait_ready0:	status = mem_l[device_base]	; Read status register
				status = status & 1
				if !status goto wait_ready0	; If is busy, wait

				mem_l[device_base + 4] = char		; write character
				
				current_index = current_index + 1
				tmp = current_index < TOTAL_CHARS
				if tmp goto skip1
				current_index = 0
skip1:			line_count = line_count + 1
				tmp = line_count < LINE_LENGTH
				if tmp goto loop0

				line_count = 0

				; CR/NL
wait_ready1:	status = mem_l[device_base]	; Read status register
				status = status & 1
				if !status goto wait_ready1	; If is busy, wait
				char = 10
				mem_l[device_base + 4] = char				

				start_offset = start_offset + 1
				tmp = start_offset < TOTAL_CHARS
				if tmp goto skip2
				start_offset = 0
skip2:			current_index = start_offset
				goto loop0

				.emitliteralpool
pattern: .string "!#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\]^_`abcdefghijklmnopqrstuvwxyz"
				
