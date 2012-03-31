;;
;; Rasterize a triangle by hierarchial subdivision
;;


					BIN_SIZE = 64		; Pixel width/height for a bin
					commandBuffer = 0x10000

;;
;; Rasterize a triangle
;;

					; This register is used across all functions called by
					; rasterizeTriangle
					.regalias cmdptr s27	 

rasterizeTriangle	.enterscope
					
					;; Parameters
					.regalias x1 s0
					.regalias y1 s1
					.regalias x2 s2
					.regalias y2 s3
					.regalias x3 s4
					.regalias y3 s5

					;; Internal registers
					.regalias temp s6

					; Set up the command pointer register, which will be
					; used by all called functions and is not 
					@cmdptr = mem_l[_cmdptr]

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
					SP_X1 = 408
					SP_Y1 = 412
					SP_X2 = 416
					SP_Y2 = 420
					SP_X3 = 424
					SP_Y3 = 428
					SP_OLD_SP = 432
					SP_LINK = 436
					
					;; Save the parameters
					sp = sp - (SP_LINK + 4)
					temp = 63
					temp = ~temp					; set up mask
					temp = sp & temp				; Align to 64 byte boundary
					mem_l[temp + SP_OLD_SP] = sp	; save old stack
					sp = temp
					
					mem_l[sp + SP_X1] = x1
					mem_l[sp + SP_Y1] = y1
					mem_l[sp + SP_X2] = x2
					mem_l[sp + SP_Y2] = y2
					mem_l[sp + SP_X3] = x3
					mem_l[sp + SP_Y3] = y3
					mem_l[sp + SP_LINK] = link

					;; Set up parameters
					s0 = x1
					s1 = y1
					s2 = x2
					s3 = y2

					call @setupEdge

					;; Save the return values
					mem_l[sp + SP_ACCEPT_CORNER1] = s4
					mem_l[sp + SP_REJECT_CORNER1] = s5
					mem_l[sp + SP_ACCEPT_STEP1] = v0
					mem_l[sp + SP_REJECT_STEP1] = v1

					;; Set up parameters
					s0 = mem_l[sp + SP_X2]	; x2
					s1 = mem_l[sp + SP_Y2]	; y2 
					s2 = mem_l[sp + SP_X3] ; x3
					s3 = mem_l[sp + SP_Y3] ; y3

					call @setupEdge

					;; Save the return values
					mem_l[sp + SP_ACCEPT_CORNER2] = s4
					mem_l[sp + SP_REJECT_CORNER2] = s5
					mem_l[sp + SP_ACCEPT_STEP2] = v0
					mem_l[sp + SP_REJECT_STEP2] = v1

					;; Set up parameters
					s0 = mem_l[sp + SP_X3]	; x2
					s1 = mem_l[sp + SP_Y3]	; y2 
					s2 = mem_l[sp + SP_X1] ; x3
					s3 = mem_l[sp + SP_Y1] ; y3

					call @setupEdge

					mem_l[sp + SP_ACCEPT_CORNER3] = s4
					mem_l[sp + SP_REJECT_CORNER3] = s5
					mem_l[sp + SP_ACCEPT_STEP3] = v0
					mem_l[sp + SP_REJECT_STEP3] = v1

					
					;; Unpack all of the parameters and call into our 
					;; recursion function
					
					s0 = mem_l[sp + SP_ACCEPT_CORNER1]
					s1 = mem_l[sp + SP_ACCEPT_CORNER2]
					s2 = mem_l[sp + SP_ACCEPT_CORNER3]
					s3 = mem_l[sp + SP_REJECT_CORNER1]
					s4 = mem_l[sp + SP_REJECT_CORNER2]
					s5 = mem_l[sp + SP_REJECT_CORNER3]

					v0 = mem_l[sp + SP_ACCEPT_STEP1]
					v1 = mem_l[sp + SP_ACCEPT_STEP2]
					v2 = mem_l[sp + SP_ACCEPT_STEP3]
					v3 = mem_l[sp + SP_REJECT_STEP1]
					v4 = mem_l[sp + SP_REJECT_STEP2]
					v5 = mem_l[sp + SP_REJECT_STEP3]

					s6 = BIN_SIZE
					
					; These will be parameters when we fill multiple bins
					s7 = 0			; left
					s8 = 0			; top
					
					call @subdivideTile

					link = mem_l[sp + SP_LINK]
					sp = mem_l[temp + SP_OLD_SP]	; restore stack
					pc = link

_cmdptr				.word	@commandBuffer

					.exitscope


;;
;; Set up edge equations for rasterization
;;
setupEdge			.enterscope

					;; Parameters
					.regalias x1 s0
					.regalias y1 s1
					.regalias x2 s2
					.regalias y2 s3
					
					;; Return Values
					.regalias outAcceptEdgeValue s4
					.regalias outRejectEdgeValue s5
					.regalias outAcceptStepMatrix v0 
					.regalias outRejectStepMatrix v1
					
					;; Internal variables
					.regalias xAcceptStepValues v2
					.regalias yAcceptStepValues v3
					.regalias xRejectStepValues v4
					.regalias yRejectStepValues v5
					.regalias xStep s6
					.regalias yStep s7
					.regalias trivialAcceptX s8
					.regalias trivialAcceptY s9
					.regalias trivialRejectX s10
					.regalias trivialRejectY s11
					.regalias temp s12

					;; Quarter tile step sizes
					ST0 = 0
					ST1 = BIN_SIZE / 4
					ST2 = BIN_SIZE * 2 / 4
					ST3 = BIN_SIZE * 3 / 4

					xAcceptStepValues = mem_l[kXSteps]
					xRejectStepValues = xAcceptStepValues
					yAcceptStepValues = mem_l[kYSteps]
					yRejectStepValues = yAcceptStepValues
					
					temp = y2 > y1
					if !temp goto else0
					trivialAcceptX = BIN_SIZE - 1
					xAcceptStepValues = xAcceptStepValues - ST3
					goto endif0
else0				trivialAcceptX = 0
					xRejectStepValues = xRejectStepValues - ST3
endif0

					temp = x2 > x1
					if !temp goto else1
					trivialAcceptY = 0
					yRejectStepValues = yRejectStepValues - ST3
					goto endif1
else1				trivialAcceptY = BIN_SIZE - 1
					yAcceptStepValues = yAcceptStepValues - ST3
endif1

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
				
					;; Set up xStepValues
					xAcceptStepValues = xAcceptStepValues * xStep;
					xRejectStepValues = xRejectStepValues * xStep;
				
					;; Set up yStepValues
					yAcceptStepValues = yAcceptStepValues * yStep;
					yRejectStepValues = yRejectStepValues * yStep;
					
					;; Add together
					outAcceptStepMatrix = xAcceptStepValues - yAcceptStepValues;
					outRejectStepMatrix = xRejectStepValues - yRejectStepValues;

					pc = link

					.align 64
kXSteps .word ST0, ST1, ST2, ST3, ST0, ST1, ST2, ST3, ST0, ST1, ST2, ST3, ST0, ST1, ST2, ST3
kYSteps .word ST0, ST0, ST0, ST0, ST1, ST1, ST1, ST1, ST2, ST2, ST2, ST2, ST3, ST3, ST3, ST3

					.exitscope

					
;;
;; Recursively subdivide a block
;;
subdivideTile		.enterscope
						
					;; Parameters
					.regalias acceptCornerValue1 s0
					.regalias acceptCornerValue2 s1
					.regalias acceptCornerValue3 s2
					.regalias rejectCornerValue1 s3
					.regalias rejectCornerValue2 s4
					.regalias rejectCornerValue3 s5
					.regalias tileSize s6
					.regalias left s7
					.regalias top s8
					.regalias acceptStep1 v0
					.regalias acceptStep2 v1
					.regalias acceptStep3 v2
					.regalias rejectStep1 v3
					.regalias rejectStep2 v4
					.regalias rejectStep3 v5

					;; Internal variables
					.regalias trivialAcceptMask s9
					.regalias trivialRejectMask s10
					.regalias recurseMask s11
					.regalias index s12
					.regalias x s13
					.regalias y s14
					.regalias temp s15
					.regalias temp2 s16

					.regalias acceptEdgeValue1 v6
					.regalias acceptEdgeValue2 v7
					.regalias acceptEdgeValue3 v8
					.regalias rejectEdgeValue1 v9
					.regalias rejectEdgeValue2 v10
					.regalias rejectEdgeValue3 v11

					;; Compute accept masks
					acceptEdgeValue1 = acceptStep1 + acceptCornerValue1
					trivialAcceptMask = acceptEdgeValue1 <= 0
					acceptEdgeValue2 = acceptStep2 + acceptCornerValue2
					temp = acceptEdgeValue2 <= 0
					trivialAcceptMask = trivialAcceptMask & temp
					acceptEdgeValue3 = acceptStep3 + acceptCornerValue3
					temp = acceptEdgeValue3 <= 0
					trivialAcceptMask = trivialAcceptMask & temp

					;; End recursion if we are at the smallest tile size
					temp = tileSize == 4
					if !temp goto endif0

					;; queue command fillMasked(left, top, trivialAcceptMask)
					
					temp = 1		; command type (fill masked)
					mem_s[@cmdptr] = temp
					mem_s[@cmdptr + 2] = left
					mem_s[@cmdptr + 4] = top
					mem_s[@cmdptr + 6] = trivialAcceptMask
					@cmdptr = @cmdptr + 8
					goto epilogue
endif0

					tileSize = tileSize >> 2		; Divide tile size by 4

					;; If there are trivially accepted blocks, add a command
					;; now.
					if !trivialAcceptMask goto endif1

					temp = 2		; command type (fill rects)
					mem_s[@cmdptr] = temp
					mem_s[@cmdptr + 2] = left
					mem_s[@cmdptr + 4] = top
					mem_s[@cmdptr + 6] = tileSize
					mem_s[@cmdptr + 8] = trivialAcceptMask
					@cmdptr = @cmdptr + 10
endif1

					;; Compute reject masks
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

					;; Divide matrices by 4
					acceptStep1 = acceptStep1 >> 2
					acceptStep2 = acceptStep2 >> 2
					acceptStep3 = acceptStep3 >> 2
					rejectStep1 = rejectStep1 >> 2
					rejectStep2 = rejectStep2 >> 2
					rejectStep3 = rejectStep3 >> 2

while1				temp = clz(recurseMask)
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
					;; Save registers on stack
					temp2 = 63
					temp2 = ~temp2				; create mask

					temp = sp - (12 * 64 + 24)	; reserve space for scalar registers 
					temp = temp & temp2 		; Align the stack to 64 bytes so we can save vector registers aligned

					temp2 = temp + 788
					mem_l[temp2] = sp	; save old SP
					sp = temp				; adjust stack
					
					; Save registers now
					mem_l[sp] = acceptEdgeValue1
					mem_l[sp + 64] = acceptEdgeValue2
					mem_l[sp + 128] = acceptEdgeValue3
					mem_l[sp + 192] = rejectEdgeValue1
					mem_l[sp + 256] = rejectEdgeValue2
					mem_l[sp + 320] = rejectEdgeValue3
					mem_l[sp + 384] = acceptStep1
					mem_l[sp + 448] = acceptStep2

					temp = sp + 512
					mem_l[temp + 0] = acceptStep3
					mem_l[temp + 64] = rejectStep1
					mem_l[temp + 128] = rejectStep2
					mem_l[temp + 192] = rejectStep3
					mem_l[temp + 256] = recurseMask
					mem_l[temp + 260] = left
					mem_l[temp + 264] = top
					mem_l[temp + 268] = tileSize
					mem_l[temp + 272] = link

					;; We're going to pull lane values out of vectors we just saved on the stack
					temp = 15			; lane is 15 - x
					temp = temp - index
					temp = temp << 2	; Multiply by sizeof(int)
					temp = sp + temp
					acceptCornerValue1 = mem_l[temp]		; acceptEdgeValue1[index]
					acceptCornerValue2 = mem_l[temp + 64]	; acceptEdgeValue2[index]
					acceptCornerValue3 = mem_l[temp + 128]	; acceptEdgeValue3[index]
					rejectCornerValue1 = mem_l[temp + 192]	; rejectEdgeValue1[index]
					rejectCornerValue2 = mem_l[temp + 256]	; rejectEdgeValue2[index]
					rejectCornerValue3 = mem_l[temp + 320]	; rejectEdgeValue3[index]

					; Note: acceptStepX, rejectStepX, and tile size are already set up
					; outside the loop.
					left = x
					top = y
					call subdivideTile

					;; Restore registers
					acceptEdgeValue1 = mem_l[sp] 
					acceptEdgeValue2 = mem_l[sp + 64]
					acceptEdgeValue3 = mem_l[sp + 128] 
					rejectEdgeValue1 = mem_l[sp + 192] 
					rejectEdgeValue2 = mem_l[sp + 256] 
					rejectEdgeValue3 = mem_l[sp + 320] 
					acceptStep1 = mem_l[sp + 384]
					acceptStep2 = mem_l[sp + 448]
					
					temp = sp + 512
					acceptStep3 = mem_l[temp + 0] 
					rejectStep1 = mem_l[temp + 64] 
					rejectStep2 = mem_l[temp + 128] 
					rejectStep3 = mem_l[temp + 192] 
					recurseMask = mem_l[temp + 256]
					left = mem_l[temp + 260]
					top = mem_l[temp + 264]
					tileSize = mem_l[temp + 268]
					link = mem_l[temp + 272] 
					sp = mem_l[temp + 276]

					if recurseMask goto while1
endwhile1
noRecurse
epilogue			pc = link
					.exitscope
					
_start				.enterscope
					sp = mem_l[stackPtr]
					s0 = 32
					s1 = 12
					s2 = 52
					s3 = 48
					s4 = 3
					s5 = 57
					call @rasterizeTriangle

					cr31 = s0		; Halt
stackPtr			.word 0xfaffc		
					.exitscope
