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

; work in progress...
;
; Simple Euler integration n-body simulation
; Exercises:
;   - Accessing array of structures (AOS)
;   - floating point arithmetic
;

;
; struct Body {
;     float pX, pY, pZ;	// Position of the body
;     float vX, vY, vZ; // Velocity of the body
; };
;

							BODY_STRUCT_SIZE = 24
							NUM_STRANDS = 4

; Does one update
nbody						.enterscope
							; Params
							.regalias arrayBase s0
							.regalias arrayCount s1

							; Local variables
							.regalias pX vf0
							.regalias pY vf1
							.regalias pZ vf2
							.regalias vX vf3
							.regalias vY vf4
							.regalias vZ vf5
							.regalias dX vf6
							.regalias dY vf7
							.regalias dZ vf8
							.regalias fX vf9			; total force
							.regalias fY vf10
							.regalias fZ vf11
							.regalias otherX f10		; Interacting particle
							.regalias otherY f2
							.regalias otherZ f3
							.regalias pBody s4		; Pointer to body struct
							.regalias tmp s5
							.regalias interactorCount s6
							.regalias dT sf7
							.regalias updateBodyCount s8
							.regalias pOther s9
							.regalias syncPtr s10
							.regalias newCount s11

							;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
							;; Update velocities of particles
							;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

							dT = mem_l[timeIncrement]
							updateBodyCount = arrayCount
							pBody = arrayBase
UpdateVelocityLoop			; Load elements from 16 structures into vector regs
							pX = mem_l[pBody, BODY_STRUCT_SIZE]
							tmp = pBody + 4
							pY = mem_l[tmp, BODY_STRUCT_SIZE]
							tmp = pBody + 4
							pZ = mem_l[tmp, BODY_STRUCT_SIZE]
							tmp = pBody + 4
							vX = mem_l[tmp, BODY_STRUCT_SIZE]
							tmp = pBody + 4
							vY = mem_l[tmp, BODY_STRUCT_SIZE]
							tmp = pBody + 4
							vZ = mem_l[tmp, BODY_STRUCT_SIZE]

							;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
							;; Iterate through all other particles to compute 
							;; forces with this set.
							;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

							v9 = 0	; fX
							v10 = 0	; fY
							v11 = 0 ; fZ
							interactorCount = arrayCount
InteractLoop				otherX = mem_l[pOther]
							otherY = mem_l[pOther + 4]
							otherZ = mem_l[pOther + 8]	
							
							; Compute attraction between these two particles, inverse 
							; square law
							dX = pX - otherX
							dX = dX * dX
							dX = reciprocal(dX)		; dX = 1 / (pX - otherX) ** 2
							dY = pY - otherY
							dY = dY * dY
							dY = reciprocal(dY)		; dY = 1 / (pY - otherY) ** 2
							dZ = pZ - otherZ
							dZ = dZ * dZ
							dZ = reciprocal(dZ)		; dZ = 1 / (pZ - otherZ) ** 2

							; Accumulate force on the target particle
							fX = fX + dX
							fY = fY + dY
							fZ = fZ + dZ
							
							pOther = pOther + BODY_STRUCT_SIZE
							interactorCount = interactorCount - 1
							if interactorCount goto InteractLoop

							; Integrate and update velocities
							fX = fX * dT
							fX = fX * dT
							fX = fX * dT
							vX = vX + fX
							vY = vY + fY
							vZ = vZ + fZ

							; Write back new velocity
							tmp = pBody + 12
							mem_l[tmp, BODY_STRUCT_SIZE] = vX
							tmp = tmp + 4
							mem_l[tmp, BODY_STRUCT_SIZE] = vY
							tmp = tmp + 4
							mem_l[tmp, BODY_STRUCT_SIZE] = vZ
							
							; Bottom of loop
							pBody = pBody + 16 * BODY_STRUCT_SIZE * NUM_STRANDS
							updateBodyCount = updateBodyCount - 16
							if updateBodyCount goto UpdateVelocityLoop							

							; Wait for all strands to finish processing
							syncPtr = &barrierCount
barrier0					newCount = mem_sync[syncPtr]	; get current count
							newCount = newCount + 1			; next count
							tmp = newCount - NUM_STRANDS	; all strands ready
							if !tmp goto barrier0Release	; if yes, then wake
							mem_sync[syncPtr] = tmp			; try to update count
							if !tmp goto barrier0			; if race, retry
							goto barrier0Wait				; wait for everyone else
barrier0Release				tmp = 0							; reset barrier
							mem_l[syncPtr] = tmp
							goto barrier0Done
barrier0Wait				newCount = mem_l[syncPtr]		; If everyone is not done, wait
							if newCount goto barrier0Wait
barrier0Done


							;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
							;; Update positions of all bodies
							;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

							updateBodyCount = arrayCount
							pBody = arrayBase
UpdatePosLoop				; Load elements from 16 structures into vector regs
							pX = mem_l[pBody, BODY_STRUCT_SIZE]
							tmp = pBody + 4
							pY = mem_l[tmp, BODY_STRUCT_SIZE]
							tmp = pBody + 4
							pZ = mem_l[tmp, BODY_STRUCT_SIZE]
							tmp = pBody + 4
							vX = mem_l[tmp, BODY_STRUCT_SIZE]
							tmp = pBody + 4
							vY = mem_l[tmp, BODY_STRUCT_SIZE]
							tmp = pBody + 4
							vZ = mem_l[tmp, BODY_STRUCT_SIZE]

							vX = vX * dT
							vY = vY * dT
							vZ = vZ * dT
							pX = pX + vX
							pY = pY + vY
							pZ = pZ + vZ
							
							; Write back new positions
							mem_l[pBody, BODY_STRUCT_SIZE] = pX
							tmp = pBody + 4
							mem_l[tmp, BODY_STRUCT_SIZE] = pY
							tmp = tmp + 4
							mem_l[tmp, BODY_STRUCT_SIZE] = pZ

							; Bottom of loop
							pBody = pBody + 16 * BODY_STRUCT_SIZE * NUM_STRANDS
							updateBodyCount = updateBodyCount - 16
							if updateBodyCount goto UpdateVelocityLoop							

							; Wait for all strands to finish processing
							syncPtr = &barrierCount
barrier1					newCount = mem_sync[syncPtr]	; get current count
							newCount = newCount + 1			; next count
							tmp = newCount - NUM_STRANDS	; all strands ready
							if !tmp goto barrier1Release	; if yes, then wake
							mem_sync[syncPtr] = tmp			; try to update count
							if !tmp goto barrier1			; if race, retry
							goto barrier0Wait				; wait for everyone else
barrier1Release				tmp = 0							; reset barrier
							mem_l[syncPtr] = tmp
							goto barrier1Done
barrier1Wait				newCount = mem_l[syncPtr]		; If everyone is not done, wait
							if newCount goto barrier1Wait
barrier1Done

							pc = link

barrierCount				.word 0
timeIncrement				.float 0.1
							
							.exitscope


_start						s2 = 0xf
							cr30 = s2				; Start all strands		
							s2 = cr0				; Get my strand ID

							s3 = s2 * (16 * BODY_STRUCT_SIZE)	; Block size
							s0 = &bodyStructs		; Dest
							s0 = s0 + s3			; Offset
							s1 = 255
							call nbody

							;; XXX loop for some number of iterations

							cr31 = s0				; halt
							
bodyStructs					.word 0
														
