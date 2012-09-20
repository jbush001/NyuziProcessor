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
; Compute dot products of an array of vectors with a constant vector
;

;
; struct Vector {
;     float pX, pY, pZ;	
;     float dotProduct;
; };
;

							NUM_ELEMENTS=2048
							VECTOR_STRUCT_SIZE = 16
							NUM_STRANDS = 4
							NUM_LANES=16

ComputeProducts				.enterscope
							; Params
							.regalias pVector s0		
							.regalias vectorCount s1
							.regalias uX vf0
							.regalias uY vf1
							.regalias uZ vf2
						
							; Local variables
							.regalias pX vf3
							.regalias pY vf4
							.regalias pZ vf5
							.regalias sum vf6

ComputeLoop					; Load elements from 16 structures into vector regs
							pX = mem_l[pVector, VECTOR_STRUCT_SIZE]
							pVector = pVector + 4
							pY = mem_l[pVector, VECTOR_STRUCT_SIZE]
							pVector = pVector + 4
							pZ = mem_l[pVector, VECTOR_STRUCT_SIZE]
							pVector = pVector + 4

							; Compute dot product
							pX = pX * uX
							pY = pY * uY
							pZ = pZ * uZ
							sum = pX + pY
							sum = sum + pZ

							; Write back result
							mem_l[pVector, VECTOR_STRUCT_SIZE] = sum
							
							; Loop
							pVector = pVector + (NUM_STRANDS * NUM_LANES * VECTOR_STRUCT_SIZE)
							vectorCount = vectorCount - 16
							if vectorCount goto ComputeLoop

							pc = link
							.exitscope


_start						.enterscope
							.regalias strandID s2 
							.regalias structOffset s3 

							s0 = 0xf
							cr30 = s0				; Start all strands		
							strandID = cr0				; Get my strand ID

							; Load pointer and count
							s0 = &@vecStructs		; Dest
							structOffset = strandID * (NUM_LANES * VECTOR_STRUCT_SIZE)	; Block size
							s0 = s0 + structOffset			; Offset
							s1 = NUM_ELEMENTS / NUM_STRANDS

							; Load reference vector
							s5 = &refVector
							s4 = mem_l[s5]
							v2 = s4
							s4 = mem_l[s5 + 4]
							v3 = s4
							s4 = mem_l[s5 + 8]
							v4 = s4

							call ComputeProducts

							; Wait for all strands to finish
							s0 = &running_strands
retry						s1 = mem_sync[s0]
							s1 = s1 - 1
							s2 = s1
							mem_sync[s0] = s1
							if !s1 goto retry

wait_done					if s2 goto wait_done	; Will fall through on last ref (s2 = 1)
							cr31 = s0				; halt
							
running_strands				.word 4					
refVector					.float 2.5, 3.2, 5.1
							.exitscope
							

