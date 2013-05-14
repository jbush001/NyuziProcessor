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
; Rasterize a triangle by hierarchical subdivision
;
; Based on: http://drdobbs.com/architecture-and-design/217200602
;  


					BIN_SIZE = 64		; Pixel width/height for a bin

RasterizeTriangle:	.enterscope
					
					;; Parameters
					.regalias x1 s12
					.regalias y1 s13
					.regalias x2 s14
					.regalias y2 s15
					.regalias x3 s16
					.regalias y3 s17
					.regalias ptr s18	; Where to put resulting commands

					;; Internal registers
					.regalias temp s19
					.regalias newStackBase s20
					.regalias job s21

					; Stack locations.  Put the vectors first, since
					; they need to be aligned
					SP_ACCEPT_STEP1 = 0
					SP_ACCEPT_STEP2 = 64
					SP_ACCEPT_STEP3 = 128
					SP_REJECT_STEP1 = 192
					SP_REJECT_STEP2 = 256
					SP_REJECT_STEP3 = 320
					SP_ACCEPT_CORNER1 = 384
					SP_ACCEPT_CORNER2 = 388
					SP_ACCEPT_CORNER3 = 392
					SP_REJECT_CORNER1 = 396
					SP_REJECT_CORNER2 = 400
					SP_REJECT_CORNER3 = 404
					SP_OLD_SP = 408
					SP_OLD_S12 = 412
					SP_OLD_S13 = 416
					SP_OLD_S14 = 420
					SP_OLD_S15 = 424
					SP_OLD_S16 = 428
					SP_OLD_S17 = 432
					SP_OLD_S18 = 436
					SP_LINK = 440
					
					job = s0
					
					;; Save the parameters
					newStackBase = sp - (SP_LINK + 4)
					temp = 63
					temp = ~temp					; set up mask
					newStackBase = newStackBase & temp			; Align to 64 byte boundary
					mem_l[newStackBase + SP_OLD_SP] = sp	; save old stack
					sp = newStackBase
					
					mem_l[sp + SP_OLD_S12] = s12
					mem_l[sp + SP_OLD_S13] = s13
					mem_l[sp + SP_OLD_S14] = s14
					mem_l[sp + SP_OLD_S15] = s15
					mem_l[sp + SP_OLD_S16] = s16
					mem_l[sp + SP_OLD_S17] = s17
					mem_l[sp + SP_OLD_S18] = s18
					mem_l[sp + SP_LINK] = link

					s0 = mem_l[job]		; x1
					s1 = mem_l[job + 4]	; y1
					s2 = mem_l[job + 8]	; x2
					s3 = mem_l[job + 12] ; y2

					call @SetupEdge

					;; Save the return values
					mem_l[sp + SP_ACCEPT_CORNER1] = s0
					mem_l[sp + SP_REJECT_CORNER1] = s1
					mem_l[sp + SP_ACCEPT_STEP1] = v0
					mem_l[sp + SP_REJECT_STEP1] = v1

					;; Set up parameters
					s0 = mem_l[job + 8]	; x2
					s1 = mem_l[job + 12] ; y2 
					s2 = mem_l[job + 16] ; x3
					s3 = mem_l[job + 20] ; y3

					call @SetupEdge

					;; Save the return values
					mem_l[sp + SP_ACCEPT_CORNER2] = s0
					mem_l[sp + SP_REJECT_CORNER2] = s1
					mem_l[sp + SP_ACCEPT_STEP2] = v0
					mem_l[sp + SP_REJECT_STEP2] = v1

					;; Set up parameters
					s0 = mem_l[job + 16]	; x3
					s1 = mem_l[job + 20]	; y3 
					s2 = mem_l[job] ; x1
					s3 = mem_l[job + 4] ; y1

					call @SetupEdge

					mem_l[sp + SP_ACCEPT_CORNER3] = s0
					mem_l[sp + SP_REJECT_CORNER3] = s1
					mem_l[sp + SP_ACCEPT_STEP3] = v0
					mem_l[sp + SP_REJECT_STEP3] = v1
					
					;; Unpack all of the parameters and call into our 
					;; recursion function
					
					s12 = mem_l[sp + SP_ACCEPT_CORNER1]
					s13 = mem_l[sp + SP_ACCEPT_CORNER2]
					s14 = mem_l[sp + SP_ACCEPT_CORNER3]
					s15 = mem_l[sp + SP_REJECT_CORNER1]
					s16 = mem_l[sp + SP_REJECT_CORNER2]
					s17 = mem_l[sp + SP_REJECT_CORNER3]

					v0 = mem_l[sp + SP_ACCEPT_STEP1]
					v1 = mem_l[sp + SP_ACCEPT_STEP2]
					v2 = mem_l[sp + SP_ACCEPT_STEP3]
					v3 = mem_l[sp + SP_REJECT_STEP1]
					v4 = mem_l[sp + SP_REJECT_STEP2]
					v5 = mem_l[sp + SP_REJECT_STEP3]

					s18 = BIN_SIZE
					
					; These will be parameters when we fill multiple bins
					s19 = 0			; left
					s20 = 0			; top
					
					call @SubdivideTile

					s12 = mem_l[sp + SP_OLD_S12]
					s13 = mem_l[sp + SP_OLD_S13]
					s14 = mem_l[sp + SP_OLD_S14]
					s15 = mem_l[sp + SP_OLD_S15]
					s16 = mem_l[sp + SP_OLD_S16]
					s17 = mem_l[sp + SP_OLD_S17]
					s18 = mem_l[sp + SP_OLD_S18]
					link = mem_l[sp + SP_LINK]
					sp = mem_l[sp + SP_OLD_SP]	; restore stack

					pc = link

					.exitscope


;
; Set up edge equations for rasterization
; Result will be copied into s0/s1 (accept edge value, reject edge value)
; and v0/v1 (accept step vector/reject step vector)
;
SetupEdge:			.enterscope

					;; Parameters
					.regalias x1 s0
					.regalias y1 s1
					.regalias x2 s2
					.regalias y2 s3
					
					;; Return Values
					.regalias outAcceptStepVector v0 
					.regalias outRejectStepVector v1
					
					;; Internal variables
					.regalias xAcceptStepValues v2
					.regalias yAcceptStepValues v3
					.regalias xRejectStepValues v4
					.regalias yRejectStepValues v5
					.regalias xStep s4
					.regalias yStep s5
					.regalias trivialAcceptX s6
					.regalias trivialAcceptY s7
					.regalias trivialRejectX s8
					.regalias trivialRejectY s9
					.regalias temp s10
					.regalias outAcceptEdgeValue s11
					.regalias outRejectEdgeValue s12

					;; Quarter tile step sizes
					ST0 = 0
					ST1 = BIN_SIZE / 4
					ST2 = BIN_SIZE * 2 / 4
					ST3 = BIN_SIZE * 3 / 4

					.saveregs s12

					xAcceptStepValues = mem_l[kXSteps]
					xRejectStepValues = xAcceptStepValues
					yAcceptStepValues = mem_l[kYSteps]
					yRejectStepValues = yAcceptStepValues
					
					temp = y2 > y1
					if !temp goto else0
					trivialAcceptX = BIN_SIZE - 1
					xAcceptStepValues = xAcceptStepValues - ST3
					goto endif0
else0:				trivialAcceptX = 0
					xRejectStepValues = xRejectStepValues - ST3
endif0:

					temp = x2 > x1
					if !temp goto else1
					trivialAcceptY = 0
					yRejectStepValues = yRejectStepValues - ST3
					goto endif1
else1:				trivialAcceptY = BIN_SIZE - 1
					yAcceptStepValues = yAcceptStepValues - ST3
endif1:

					trivialRejectX = BIN_SIZE - 1
					trivialRejectX = trivialRejectX - trivialAcceptX
					trivialRejectY = BIN_SIZE - 1
					trivialRejectY = trivialRejectY - trivialAcceptY

					xStep = y2 - y1;
					yStep = x2 - x1;

					;; Set up accept edge value				
					outAcceptEdgeValue = trivialAcceptX - x1 
					outAcceptEdgeValue = outAcceptEdgeValue * xStep
					temp = trivialAcceptY - y1
					temp = temp * yStep;
					outAcceptEdgeValue = outAcceptEdgeValue - temp

					;; Set up reject edge value
					outRejectEdgeValue = trivialRejectX - x1
					outRejectEdgeValue = outRejectEdgeValue * xStep
					temp = trivialRejectY - y1
					temp = temp * yStep;
					outRejectEdgeValue = outRejectEdgeValue - temp
					
					;; Adjust for top-left fill convention
					temp = y1 < y2
					if temp goto notTopLeft
					temp = y2 <> y1
					if temp goto notTopLeft
					temp = x2 < x1 
					if temp goto notTopLeft

					; Adjust by one pixel to compensate
					outAcceptEdgeValue = outAcceptEdgeValue + 1
					outRejectEdgeValue = outRejectEdgeValue + 1
					
notTopLeft:
				
					;; Set up xStepValues
					xAcceptStepValues = xAcceptStepValues * xStep;
					xRejectStepValues = xRejectStepValues * xStep;
				
					;; Set up yStepValues
					yAcceptStepValues = yAcceptStepValues * yStep;
					yRejectStepValues = yRejectStepValues * yStep;
					
					;; Add together
					outAcceptStepVector = xAcceptStepValues - yAcceptStepValues;
					outRejectStepVector = xRejectStepValues - yRejectStepValues;
					s0 = outAcceptEdgeValue
					s1 = outRejectEdgeValue

					.restoreregs s12

					pc = link

					.align 64
kXSteps: .word ST0, ST1, ST2, ST3, ST0, ST1, ST2, ST3, ST0, ST1, ST2, ST3, ST0, ST1, ST2, ST3
kYSteps: .word ST0, ST0, ST0, ST0, ST1, ST1, ST1, ST1, ST2, ST2, ST2, ST2, ST3, ST3, ST3, ST3

					.exitscope

					
;
; Recursively subdivide a block
; Doesn't follow normal register save conventions (since it calls itself recursively)
;
SubdivideTile:		.enterscope
						
					;; Parameters
					.regalias acceptCornerValue1 s12
					.regalias acceptCornerValue2 s13
					.regalias acceptCornerValue3 s14
					.regalias rejectCornerValue1 s15
					.regalias rejectCornerValue2 s16
					.regalias rejectCornerValue3 s17
					.regalias tileSize s18
					.regalias left s19
					.regalias top s20
					.regalias acceptStep1 v0
					.regalias acceptStep2 v1
					.regalias acceptStep3 v2
					.regalias rejectStep1 v3
					.regalias rejectStep2 v4
					.regalias rejectStep3 v5

					;; Internal variables
					.regalias trivialAcceptMask s21
					.regalias trivialRejectMask s22
					.regalias recurseMask s23
					.regalias index s24
					.regalias x s25
					.regalias y s26
					.regalias temp s27
					.regalias temp2 s28

					.regalias acceptEdgeValue1 v6
					.regalias acceptEdgeValue2 v7
					.regalias acceptEdgeValue3 v8
					.regalias rejectEdgeValue1 v9
					.regalias rejectEdgeValue2 v10
					.regalias rejectEdgeValue3 v11

					.saveregs link

					;; Compute accept masks
					acceptEdgeValue1 = acceptStep1 + acceptCornerValue1
					trivialAcceptMask = acceptEdgeValue1 < 0
					acceptEdgeValue2 = acceptStep2 + acceptCornerValue2
					temp = acceptEdgeValue2 < 0
					trivialAcceptMask = trivialAcceptMask & temp
					acceptEdgeValue3 = acceptStep3 + acceptCornerValue3
					temp = acceptEdgeValue3 < 0
					trivialAcceptMask = trivialAcceptMask & temp

					;; End recursion if we are at the smallest tile size
					temp = tileSize == 4
					if !temp goto endif0

					;; Queue a FillMasked command.
					call @AllocateJob
					mem_s[s0 + 8] = left
					mem_s[s0 + 10] = top
					mem_s[s0 + 12] = trivialAcceptMask
					u1 = 3				; FillMasked
					call @EnqueueJob
					goto epilogue

endif0:				tileSize = tileSize >> 2		; Divide tile size by 4

					if !trivialAcceptMask goto endif1

					;; There are trivially accepted blocks.  Queue a FillRects command.
					call @AllocateJob
					mem_s[s0 + 8] = left
					mem_s[s0 + 10] = top
					mem_s[s0 + 12] = tileSize
					mem_s[s0 + 14] = trivialAcceptMask
					u1 = 4				; FillRects
					call @EnqueueJob

endif1:				;; Compute reject masks
					rejectEdgeValue1 = rejectStep1 + rejectCornerValue1
					trivialRejectMask = rejectEdgeValue1 >= 0
					rejectEdgeValue2 = rejectStep2 + rejectCornerValue2
					temp = rejectEdgeValue2 >= 0
					trivialRejectMask = trivialRejectMask | temp 
					rejectEdgeValue3 = rejectStep3 + rejectCornerValue3
					temp = rejectEdgeValue3 >= 0
					trivialRejectMask = trivialRejectMask | temp

					temp = 1
					temp = temp << 16
					temp = temp - 1			; Load 0xffff into temp
					recurseMask = trivialAcceptMask | trivialRejectMask
					recurseMask = recurseMask ^ temp

					;; If there are blocks that are partially covered,
					;; do further subdivision on those
					if !recurseMask goto noRecurse

					;; Divide step vectors by 4
					acceptStep1 = acceptStep1 >> 2
					acceptStep2 = acceptStep2 >> 2
					acceptStep3 = acceptStep3 >> 2
					rejectStep1 = rejectStep1 >> 2
					rejectStep2 = rejectStep2 >> 2
					rejectStep3 = rejectStep3 >> 2

while1:				temp = clz(recurseMask)
					index = 31
					index = index - temp	; We want index from 0, perhaps clz isn't best instruction
					
					;; Clear bit in recurseMask
					temp = 1
					temp = temp << index
					temp = ~temp
					recurseMask = recurseMask & temp
					
					x = 15
					x = x - index
					y = x					; stash common value
					
					x = x & 3
					x = x * tileSize
					x = x + left
					
					y = y >> 2
					y = y * tileSize
					y = y + top
					
					;; Now call myself recursively
					.saveregs acceptEdgeValue1, acceptEdgeValue2, acceptEdgeValue3,
						rejectEdgeValue1, rejectEdgeValue2, rejectEdgeValue3,
						acceptStep1, acceptStep2, acceptStep3, rejectStep1,
						rejectStep2, rejectStep3, recurseMask, left, top,
						tileSize, link

					acceptCornerValue1 = getlane(acceptEdgeValue1, index)
					acceptCornerValue2 = getlane(acceptEdgeValue2, index)
					acceptCornerValue3 = getlane(acceptEdgeValue3, index)
					rejectCornerValue1 = getlane(rejectEdgeValue1, index)
					rejectCornerValue2 = getlane(rejectEdgeValue2, index)
					rejectCornerValue3 = getlane(rejectEdgeValue3, index)

					; Note: acceptStepX, rejectStepX, and tile size are already set up
					; outside the loop.
					left = x
					top = y
					call SubdivideTile

					.restoreregs acceptEdgeValue1, acceptEdgeValue2, acceptEdgeValue3,
						rejectEdgeValue1, rejectEdgeValue2, rejectEdgeValue3,
						acceptStep1, acceptStep2, acceptStep3, rejectStep1,
						rejectStep2, rejectStep3, recurseMask, left, top,
						tileSize, link

					if recurseMask goto while1
endwhile1:
noRecurse:
epilogue:			.restoreregs link
					pc = link
					.exitscope
					
