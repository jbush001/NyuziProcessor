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
; Fill a 4x4 rectange of pixels with a mask
;
FillMasked:			.enterscope
					.regalias cmdPtr s0
					.regalias x u4
					.regalias y u5
					.regalias mask u12
					.regalias temp s13
					.regalias scalarBasePtr s14
					.regalias colorVec v0
					.regalias ptrVectorAtOrigin v1
					.regalias fbPtr v2

					.saveregs u12, u13, u14, link

					ptrVectorAtOrigin = mem_l[@ptrVecOffsets]
					scalarBasePtr = mem_l[@fbBaseAddress]
					ptrVectorAtOrigin = ptrVectorAtOrigin + scalarBasePtr

					; XXX hack, hard code color
					temp = mem_l[@color2]
					colorVec = temp

					x = mem_s[cmdPtr]
					y = mem_s[cmdPtr + 2]
					mask = mem_s[cmdPtr + 4]
					
					;; Determine offset of our 4x4 output 
					temp = y << 8		; y * 64 pixels/line * 4 bytes/pixel
					temp = temp + x
					temp = temp + x
					temp = temp + x
					temp = temp + x		; + x * 4
					fbPtr = ptrVectorAtOrigin + temp
					
					; XXX pixel shader should determine colorVec...
				
					mem_l[fbPtr]{mask} = colorVec

					.restoreregs u12, u13, u14, link

					pc = link
					.exitscope

;
; Fill variable sized rectangles
;
FillRects:			.enterscope
					.regalias cmdPtr s0
					.regalias x u12
					.regalias y u13
					.regalias mask u14
					.regalias temp s15
					.regalias scalarBasePtr s16
					.regalias rectSize s17
					.regalias subX s18
					.regalias subY s19
					.regalias hCounter s20
					.regalias vCounter s21
					.regalias index u22
					.regalias colorVec v0
					.regalias ptrVectorAtOrigin v1
					.regalias fbPtr v2

					.saveregs u12, u13, u14, u15, u16, u17, u18, u19, u20, u21, u22, link

					x = mem_s[cmdPtr]
					y = mem_s[cmdPtr + 2]
					rectSize = mem_s[cmdPtr + 4]
					mask = mem_s[cmdPtr + 6]

					; XXX hack, hard code color...
					temp = mem_l[@color1]
					colorVec = temp

					ptrVectorAtOrigin = mem_l[@ptrVecOffsets]
					scalarBasePtr = mem_l[@fbBaseAddress]
					ptrVectorAtOrigin = ptrVectorAtOrigin + scalarBasePtr

while1:				temp = clz(mask)
					index = 31
					index = index - temp	; We want index from 0, perhaps clz isn't best instruction
					
					; Clear bit in mask
					temp = 1
					temp = temp << index
					temp = ~temp
					mask = mask & temp

					;; Determine the coordinates of the sub rect
					subX = 15
					subX = subX - index
					subY = subX					; stash common value
					
					subX = subX & 3
					subX = subX * rectSize
					subX = subX + x
					
					subY = subY >> 2
					subY = subY * rectSize
					subY = subY + y

					;; Determine framebuffer offset 
					temp = subY << 8		; y * 64 pixels/line * 4 bytes/pixel
					temp = temp + subX
					temp = temp + subX
					temp = temp + subX
					temp = temp + subX		; + x * 4

					fbPtr = ptrVectorAtOrigin + temp
					vCounter = rectSize
while3:				hCounter = rectSize
while2:				; XXX pixel shader should determine colorVec...
					mem_l[fbPtr] = colorVec

					fbPtr = fbPtr + 16		; 4 pixels * 4 bytes
					hCounter = hCounter - 4
					if hCounter goto while2
					
					;; Step to next line
					fbPtr = fbPtr + (64 * 4)	; Next line
					fbPtr = fbPtr - rectSize
					fbPtr = fbPtr - rectSize
					fbPtr = fbPtr - rectSize
					fbPtr = fbPtr - rectSize		; Rect size * 4
					vCounter = vCounter - 4
					if vCounter goto while3
					if mask goto while1

endwhile0:			.restoreregs u12, u13, u14, u15, u16, u17, u18, u19, u20, u21, u22, link
					pc = link
					.exitscope

fbBaseAddress:		.word 0xfc000
					.align 64
ptrVecOffsets:		.word 0, 4, 8, 12, 256, 260, 264, 268, 512, 516, 520, 524, 768, 772, 776, 780
color1:				.word 0xfffffff		
color2:				.word 0xfffffff		


;
; Flush the framebuffer out of the L2 cache into system memory
;
FlushFrameBuffer:	.enterscope
					s4 = mem_l[@fbBaseAddress]
					s5 = 64 * 4		; Number of cache lines (64 rows, 4 bytes per pixel)
flushLoop:			dflush(s0)
					s4 = s4 + 64
					s5 = s5 - 1
					if s5 goto flushLoop
					pc = link
					.exitscope
;
; Clear framebuffer
;
clearFrameBuffer:	.enterscope
					s4 = mem_l[clearColor]
					v0 = s4
					s4 = mem_l[@fbBaseAddress]
					s5 = 64 * 4	; Number of cache lines in frame buffer
clearLoop:			mem_l[s4] = v0
					s4 = s4 + 64
					s5 = s5 - 1
					if s5 goto clearLoop
					pc = link

clearColor:			.word 0xff0000ff		; red, for test
					.exitscope

