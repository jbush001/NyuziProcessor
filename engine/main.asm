;
; Memory map
;
;  0 - Start of code
;  n - end of code
;  0x10000 General purpose memory (heap)
;  0xf7fff
;  0xf8000 strand 0 stack
;  0xf9000 strand 1 stack
;  0xfa000 strand 2 stack
;  0xfb000 strand 3 stack
;  0xfc000 Frame buffer start (frame buffer is 64x64 pixels, RGBA)
;  0x100000 Frame buffer end, top of memory
;
; All registers are caller save
;

_start				.enterscope
					sp = mem_l[stackPtr]
					s0 = 32
					s1 = 12
					s2 = 52
					s3 = 48
					s4 = 3
					s5 = 57
					s6 = mem_l[cmdBuffer]
					call @rasterizeTriangle
					
					s0 = mem_l[cmdBuffer]
					call @fillPixels
					
					cr31 = s0		; Halt

stackPtr			.word 0xf7ffc		
cmdBuffer			.word 0x10000
					.exitscope

;;
;; Given a command buffer, fill the pixels in the framebuffer
;;
fillPixels			.enterscope

					;; Parameters
					.regalias cmdPtr s0
					
					;; Internal registers
					.regalias temp s1
					.regalias cmd s2
					.regalias x u3
					.regalias y u4
					.regalias mask u5
					.regalias rectSize s6
					.regalias subX s7
					.regalias subY s8
					.regalias scalarFbPtr s9
					.regalias scalarBasePtr s10
					.regalias hCounter s11
					.regalias vCounter s12
					.regalias scalarColor s13
					.regalias index u14
					.regalias ptrVectorAtOrigin v0
					.regalias fbPtr v1
					.regalias colorVec v3

					scalarColor = mem_l[outputColor]
					colorVec = scalarColor
					
					ptrVectorAtOrigin = mem_l[ptrVecOffsets]
					scalarBasePtr = mem_l[fbBaseAddress]
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

					scalarFbPtr = scalarBasePtr + temp
					vCounter = rectSize
while3				hCounter = rectSize
while2				mem_l[scalarFbPtr] = scalarColor
					scalarFbPtr = scalarFbPtr + 4
					hCounter = hCounter - 1
					if hCounter goto while2
					
					;; Step to next line
					scalarFbPtr = scalarFbPtr + 256		; framebuffer stride (64 * 4)
					scalarFbPtr = scalarFbPtr - rectSize
					scalarFbPtr = scalarFbPtr - rectSize
					scalarFbPtr = scalarFbPtr - rectSize
					scalarFbPtr = scalarFbPtr - rectSize		; Rect size * 4
					vCounter = vCounter - 1
					if vCounter goto while3
					
					if mask goto while1

					goto while0


endwhile0			pc = link

outputColor			.word 0xff0000ff
fbBaseAddress		.word 0xfc000

					.align 64
ptrVecOffsets		.word 0, 4, 8, 12, 256, 260, 264, 268, 512, 516, 520, 524, 768, 772, 776, 780

					.exitscope
					
					
					