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

_start:				s0 = &sort_array
					s1 = mem_l[arraylen]
					s1 = s1 + s0				; s1 is now the end pointer
outer_loop:			s2 = s0 + 1
inner_loop:			s3 = mem_b[s0]
					s4 = mem_b[s2]
					s5 = s3 > s4
					if !s5 goto no_swap
					mem_b[s0] = s4
					mem_b[s2] = s3
no_swap:			s2 = s2 + 1
					s5 = s2 == s1
					if !s5 goto inner_loop
					s0 = s0 + 1
					s5 = s0 + 1
					s5 = s5 == s1
					if !s5 goto outer_loop

					cr31 = s0
					
sort_array:			.byte 10, 15, 31, 32, 29, 9, 17, 16, 11, 30, 24, 26, 14 
					.byte 28, 27, 23, 20, 12, 7, 4, 22, 13, 6, 8, 5, 21, 25 
					.byte 18, 1, 19, 2, 3
arraylen:			.word	32
