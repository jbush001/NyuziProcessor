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

_start:					v0 = mem_l[first_matrix]
						v1 = mem_l[second_matrix]
						v2 = mem_l[permute0]
						v4 = mem_l[permute1]
						v3 = shuffle(v0, v2)
						v5 = shuffle(v1, v4)
						vf6 = vf3 * vf5

						v2 = v2 - 1
						v4 = v4 - 4
						v3 = shuffle(v0, v2)
						v5 = shuffle(v1, v4)
						vf3 = vf3 * vf5
						vf6 = vf6 + vf3

						v2 = v2 - 1
						v4 = v4 - 4
						v3 = shuffle(v0, v2)
						v5 = shuffle(v1, v4)
						vf3 = vf3 * vf5
						vf6 = vf6 + vf3

						v2 = v2 - 1
						v4 = v4 - 4
						v3 = shuffle(v0, v2)
						v5 = shuffle(v1, v4)
						vf3 = vf3 * vf5
						vf6 = vf6 + vf3	; result is in v6
						
						cr31 = s0
		
						; 15 14 13 12
						; 11 10  9  8
						;  7  6  5  4
						;  3  2  1  0
						.align 64
first_matrix: .float 1.0, 5.0, 0.0, 9.0, 7.0, 3.0, 3.0, 1.0, 0.0, 0.0, 2.0, 3.0, 1.0, 0.0, 5.0, 7.0					
second_matrix:  .float 2.0, 0.0, 1.0, 0.0, 1.0, 2.0, 3.0, 4.0, 9.0, 0.0, 8.0, 0.0, 1.0, 1.0, 1.0, 1.0
permute0: .word 3, 3, 3, 3, 7, 7, 7, 7, 11, 11, 11, 11, 15, 15, 15, 15 
permute1: .word 12, 13, 14, 15, 12, 13, 14, 15, 12, 13, 14, 15, 12, 13, 14, 15
		