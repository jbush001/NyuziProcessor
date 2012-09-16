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



;;
;; Given a command buffer, fill the pixels in the framebuffer
;; This is a placeholder for now.
;;
fillPixels			.enterscope

					;; Parameters
					.regalias cmdPtr s0
					.regalias scalarColor s1
					
					;; Internal registers
					.regalias cmd s2
					.regalias x u3
					.regalias y u4
					.regalias mask u5
					.regalias rectSize s6
					.regalias subX s7
					.regalias subY s8
					.regalias scalarBasePtr s10
					.regalias hCounter s11
					.regalias vCounter s12
					.regalias temp s13
					.regalias index u14
					.regalias ptrVectorAtOrigin v0
					.regalias fbPtr v1
					.regalias colorVec v3

					sp = sp - 4
					mem_l[sp] = link

					ptrVectorAtOrigin = mem_l[ptrVecOffsets]
					scalarBasePtr = mem_l[@fbBaseAddress]
					ptrVectorAtOrigin = ptrVectorAtOrigin + scalarBasePtr

					
while0				cmd = mem_s[cmdPtr]		; Get command
					temp = cmd == 1
					if temp goto fill_pixels
					temp = cmd == 2
					if temp goto fill_rects
					goto endwhile0

					;;
					;; Fill a 4x4 rectange of pixels with a mask
					;;
fill_pixels			x = mem_s[cmdPtr + 2]
					y = mem_s[cmdPtr + 4]
					mask = mem_s[cmdPtr + 6]
					cmdPtr = cmdPtr + 8
					
					;; Determine offset of our 4x4 output 
					temp = y << 8		; y * 64 pixels/line * 4 bytes/pixel
					temp = temp + x
					temp = temp + x
					temp = temp + x
					temp = temp + x		; + x * 4
					fbPtr = ptrVectorAtOrigin + temp
					
					call @pixelShader
					mem_l[fbPtr]{mask} = colorVec

					goto while0

					;;
					;; Up to 16 rectangles, with a mask
					;;
fill_rects			x = mem_s[cmdPtr + 2]
					y = mem_s[cmdPtr + 4]
					rectSize = mem_s[cmdPtr + 6]
					mask = mem_s[cmdPtr + 8]
					cmdPtr = cmdPtr + 10

while1				temp = clz(mask)
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
while3				hCounter = rectSize
while2				
					call @pixelShader
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
					goto while0

endwhile0			link = mem_l[sp]
					sp = sp + 4
					pc = link

					.align 64
ptrVecOffsets		.word 0, 4, 8, 12, 256, 260, 264, 268, 512, 516, 520, 524, 768, 772, 776, 780

					.exitscope

fbBaseAddress		.word 0xfc000


;
; Stand-in for real pixel shader.  Right now it just picks flat colors
;  Input parameter: s1 - color to use (uniform)
;  Output parameter: v3 - color for each of 16 pixels in a 4x4 quad.
;
pixelShader			.enterscope
					.regalias colorVec v3
					.regalias scalarColor s1

					colorVec = scalarColor
					pc = link
					
					.exitscope

;
; Flush the framebuffer out of the L2 cache into system memory
;
flushFrameBuffer	.enterscope
					s0 = mem_l[@fbBaseAddress]
					s1 = 64 * 4		; Number of cache lines (64 rows, 4 bytes per pixel)
flushLoop			dflush(s0)
					s0 = s0 + 64
					s1 = s1 - 1
					if s1 goto flushLoop
					pc = link
					.exitscope
;
; Clear framebuffer
;
clearFrameBuffer	.enterscope
					s0 = mem_l[clearColor]
					v0 = s0
					s0 = mem_l[@fbBaseAddress]
					s1 = 64 * 4	; Number of cache lines in frame buffer
clearLoop			mem_l[s0] = v0
					s0 = s0 + 64
					s1 = s1 - 1
					if s1 goto clearLoop
					pc = link

clearColor			.word 0xff0000ff		; red, for test
					.exitscope

