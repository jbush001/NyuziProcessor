;;
;; Rasterize a triangle by hierarchial subdivision
;;


					BIN_SIZE = 64		; Pixel width/height for a bin

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
					cmdptr = mem_l[_cmdptr]
					cmdptr = mem_l[cmdptr]

					; Stack locations.  Put the vectors first, since
					; they need to be aligned
					SP_ACCEPT_STEP1 = 0
					SP_ACCEPT_STEP2 = 64
					SP_ACCEPT_STEP3 = 128
					SP_REJECT_STEP1 = 192
					SP_REJECT_STEP2 = 256
					SP_REJECT_STEP3 = 320
					SP_ACCEPT_CORNER1 = 336
					SP_ACCEPT_CORNER2 = 340
					SP_ACCEPT_CORNER3 = 344
					SP_REJECT_CORNER1 = 348
					SP_REJECT_CORNER2 = 352
					SP_REJECT_CORNER3 = 356
					SP_X1 = 360
					SP_Y1 = 364
					SP_X2 = 368
					SP_Y2 = 372
					SP_X3 = 376
					SP_Y3 = 380
					SP_OLD_SP = 384
					SP_LINK = 388
					
					;; Save the parameters
					sp = sp - (SP_LINK + 4)
					temp = 64
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
					
					call @subdivideBlock

					link = mem_l[sp + SP_LINK]
					sp = mem_l[temp + SP_OLD_SP]	; restore stack
					pc = link

_cmdptr				.word	@commandBuffer

					.exitscope


;;
;; Set up edge equations for rasterization
;;
setupEdge			.enterscope

					;; Quarter tile step sizes
					S0 = 0
					S1 = BIN_SIZE / 4
					S2 = BIN_SIZE * 2 / 4
					S3 = BIN_SIZE * 3 / 4

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
					
					xAcceptStepValues = mem_l[kXSteps]
					xRejectStepValues = xAcceptStepValues
					yAcceptStepValues = mem_l[kYSteps]
					yRejectStepValues = yAcceptStepValues
					
					temp = y2 > y1
					if !temp goto else0
					trivialAcceptX = BIN_SIZE - 1
					xAcceptStepValues = xAcceptStepValues - S3
					goto endif0
else0				trivialAcceptX = 0
					xRejectStepValues = xRejectStepValues - S3
endif0

					temp = x2 > x1
					if !temp goto else1
					trivialAcceptY = 0
					yRejectStepValues = yRejectStepValues - S3
					goto endif1
else1				trivialAcceptY = BIN_SIZE - 1
					yAcceptStepValues = yAcceptStepValues - S3
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

kXSteps .word S3, S2, S1, S0, S3, S2, S1, S0, S3, S2, S1, S0, S3, S2, S1, S0
kYSteps .word S3, S3, S3, S3, S2, S2, S2, S2, S1, S1, S1, S1, S0, S0, S0, S0

					.exitscope

					
;;
;; Recursively subdivide a block
;;
subdivideBlock		.enterscope
						
					;; Parameters
					.regalias acceptCornerValue1 s0
					.regalias acceptCornerValue2 s1
					.regalias acceptCornerValue3 s2
					.regalias rejectCornerValue1 s3
					.regalias rejectCornerValue2 s4
					.regalias rejectCornerValue3 s5
					.regalias acceptStep1 v0
					.regalias acceptStep2 v1
					.regalias acceptStep3 v2
					.regalias rejectStep1 v3
					.regalias rejectStep2 v4
					.regalias rejectStep3 v5
					.regalias tileSize s6
					.regalias left s7
					.regalias top s8

					;; Internal variables
					.regalias acceptEdgeValue1 v7
					.regalias acceptEdgeValue2 v8
					.regalias acceptEdgeValue3 v9
					.regalias rejectEdgeValue1 v10
					.regalias rejectEdgeValue2 v11
					.regalias rejectEdgeValue3 v12
					.regalias trivialAcceptMask s9
					.regalias trivialRejectMask s10
					.regalias acceptSubStep1 v13
					.regalias acceptSubStep2 v14
					.regalias acceptSubStep3 v15
					.regalias rejectSubStep1 v16
					.regalias rejectSubStep2 v17
					.regalias rejectSubStep3 v18
					.regalias recurseMask s11
					.regalias index s12
					.regalias x s13
					.regalias y s14
					.regalias subTileSize s15
					.regalias temp s16
					.regalias temp2 s17
					.regalias outptr s18

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
					mem_s[cmdptr] = temp
					mem_s[cmdptr + 2] = left
					mem_s[cmdptr + 4] = top
					mem_s[cmdptr + 6] = trivialAcceptMask
					cmdptr = cmdptr + 8
					
					goto epilogue

endif0

					;; Compute reject masks
					rejectEdgeValue1 = rejectStep1 + rejectCornerValue1
					trivialRejectMask = rejectEdgeValue1 >= 0
					rejectEdgeValue2 = rejectStep2 + rejectCornerValue2
					temp = rejectEdgeValue2 >= 0
					trivialRejectMask = trivialRejectMask | temp 
					rejectEdgeValue3 = rejectStep3 + rejectCornerValue3
					temp = rejectEdgeValue3 >= 0
					trivialRejectMask = trivialRejectMask | temp

					subTileSize = tileSize >> 2		; Divide tile size by 4

					temp = 1
					temp = temp << 16
					temp = temp - 1			; Load 0xffff into temp
					recurseMask = trivialAcceptMask | trivialRejectMask
					recurseMask = recurseMask ^ temp
					
					;; Process all trivially accepted blocks
while0				temp = clz(trivialAcceptMask)
					index = 31
					index = index - temp	; We want index from 0, perhaps clz isn't best instruction

					temp = index < 0
					if temp goto endwhile1	; no bits set, clz returned 32
					
					;; Clear bit in trivialAcceptMask
					temp = 1
					temp = temp << index
					temp = ~temp
					trivialAcceptMask = trivialAcceptMask & temp
					
					x = 15
					x = x - index
					y = x					; stash common value
					
					x = x & 3
					x = x * subTileSize
					x = x + left
					
					y = y >> 2
					y = y * subTileSize
					y = y + top
					
					;; queue command fillRect(x, y, subTileSize)
					temp = 2		; command type (fill rect)
					mem_s[cmdptr] = temp
					mem_s[cmdptr + 2] = x
					mem_s[cmdptr + 4] = y
					mem_s[cmdptr + 6] = subTileSize
					cmdptr = cmdptr + 8
					
					goto while0
endwhile0

					;; If there are blocks that are partially covered,
					;; do further subdivision on those
					if !recurseMask goto noRecurse

					;; Divide each step matrix by 4
					acceptSubStep1 = acceptStep1 >> 2;
					acceptSubStep2 = acceptStep2 >> 2;
					acceptSubStep3 = acceptStep3 >> 2;
					rejectSubStep1 = rejectStep1 >> 2;
					rejectSubStep2 = rejectStep2 >> 2;
					rejectSubStep3 = rejectStep3 >> 2;

while1				temp = clz(recurseMask)
					index = 31
					index = index - temp	; We want index from 0, perhaps clz isn't best instruction
					
					temp = index < 0
					if temp goto endwhile1	; no bits set, clz returned 32

					;; Clear bit in recurseMask
					temp = 1
					temp = temp << index
					temp = ~temp
					recurseMask = recurseMask & temp
					
					x = 15
					x = x - index
					y = x					; stash common value
					
					x = x & 3
					x = x * subTileSize
					x = x + left
					
					y = y >> 2
					y = y * subTileSize
					y = y + top
					
					;; Now call myself recursively
					;; Save registers on stack
					temp2 = 64
					temp2 = ~temp2				; create mask

					temp = sp - (64 * 6 + 24)	; reserve space for scalar registers 
					temp = sp & temp2 			; Align the stack to 64 bytes so we can save vector registers aligned
					mem_l[temp + 356] = sp	; save old SP
					sp = temp				; adjust stack
					
					; Save registers now
					mem_l[sp] = acceptEdgeValue1
					mem_l[sp + 64] = acceptEdgeValue2
					mem_l[sp + 128] = acceptEdgeValue3
					mem_l[sp + 192] = rejectEdgeValue1
					mem_l[sp + 256] = rejectEdgeValue2
					mem_l[sp + 320] = rejectEdgeValue3
					mem_l[sp + 336] = recurseMask
					mem_l[sp + 340] = left
					mem_l[sp + 344] = top
					mem_l[sp + 348] = subTileSize
					mem_l[sp + 352] = link

					;; We're going to pull lane values out of vectors we just saved on the stack
					temp = sp + index
					acceptCornerValue1 = mem_l[temp]		; acceptEdgeValue1[index]
					acceptCornerValue2 = mem_l[temp + 64]	; acceptEdgeValue2[index]
					acceptCornerValue3 = mem_l[temp + 128]	; acceptEdgeValue3[index]
					rejectEdgeValue1 = mem_l[temp + 192]	; rejectEdgeValue1[index]
					rejectEdgeValue2 = mem_l[temp + 256]	; rejectEdgeValue2[index]
					rejectEdgeValue3 = mem_l[temp + 320]	; rejectEdgeValue3[index]
					acceptStep1 = acceptSubStep1
					acceptStep2 = acceptSubStep2
					acceptStep3 = acceptSubStep3
					rejectStep1 = rejectSubStep1
					rejectStep2 = rejectSubStep2
					rejectStep3 = rejectSubStep3
					tileSize = subTileSize
					left = x
					top = y
					
					call subdivideBlock

					;; Restore registers
					acceptEdgeValue1 = mem_l[sp] 
					acceptEdgeValue2 = mem_l[sp + 64]
					acceptEdgeValue3 = mem_l[sp + 128] 
					rejectEdgeValue1 = mem_l[sp + 192] 
					rejectEdgeValue2 = mem_l[sp + 256] 
					rejectEdgeValue3 = mem_l[sp + 320] 
					recurseMask = mem_l[sp + 336]
					left = mem_l[sp + 340]
					top = mem_l[sp + 344]
					subTileSize = mem_l[sp + 348]
					link = mem_l[sp + 352] 
					sp = mem_l[sp + 356]

					goto while1
endwhile1
noRecurse
epilogue			pc = link
					.exitscope

commandBuffer		.reserve 256
					
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
