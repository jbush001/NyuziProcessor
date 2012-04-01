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


;;
;; Entry point.  Initialize machine
;;

_start				.enterscope
					.regalias geometryPointer u7
					.regalias vertexCount u8
					.regalias triangleCount u9
					.regalias tvertPtr u10
					.regalias color u11
					
					sp = mem_l[stackPtr]
					
					goto drawTriangles



;;
;; Draw triangles
;;
drawTriangles		.enterscope
					triangleCount = mem_l[numTriangles]
					geometryPointer = &pyramid
triLoop0			vertexCount = 3
					tvertPtr = &tvertBuffer 
					color = mem_l[geometryPointer]
					mem_l[outputColor] = color
					geometryPointer = geometryPointer + 4

vertexLoop			f0 = mem_l[geometryPointer]			; x
					f1 = mem_l[geometryPointer + 4]		; y
					f2 = mem_l[geometryPointer + 8]		; z
					geometryPointer = geometryPointer + 12
					
					;; Save registers
					sp = sp - 16
					mem_l[sp] = geometryPointer
					mem_l[sp + 4] = triangleCount
					mem_l[sp + 8] = vertexCount
					mem_l[sp + 12] = tvertPtr

					call @transformVertex

					;; Restore registers
					geometryPointer = mem_l[sp]
					triangleCount = mem_l[sp + 4]
					vertexCount = mem_l[sp + 8]
					tvertPtr = mem_l[sp + 12]
					sp = sp + 16

					;; Save the return values
					mem_l[tvertPtr] = u0		; Save X
					mem_l[tvertPtr + 4] = u1	; Save Y
					tvertPtr = tvertPtr + 8
					
					vertexCount = vertexCount - 1
					if vertexCount goto vertexLoop

					;; Save registers
					sp = sp - 8
					mem_l[sp] = geometryPointer
					mem_l[sp + 4] = triangleCount


					;; We have transformed 3 vertices, now we can render
					;; the triangle.  Set up parameters
					tvertPtr = &tvertBuffer 
					s0 = mem_l[tvertPtr]		; x1
					s1 = mem_l[tvertPtr + 4]	; y1
					s2 = mem_l[tvertPtr + 8]	; x2
					s3 = mem_l[tvertPtr + 12]	; y2
					s4 = mem_l[tvertPtr + 16]	; x3
					s5 = mem_l[tvertPtr + 20]	; y3
					s6 = mem_l[cmdBuffer]

					call @rasterizeTriangle
					
					;; No return values, the pixel data is now in the command
					;; buffer.  Draw to framebuffer.
					
					s0 = mem_l[cmdBuffer]
					s1 = mem_l[outputColor]	
					call @fillPixels

					;; Restore registers
					geometryPointer = mem_l[sp]
					triangleCount = mem_l[sp + 4]
					sp = sp + 8

					triangleCount = triangleCount - 1
					if triangleCount goto triLoop0

					cr31 = s0		; Halt

stackPtr			.word 0xf7ffc		
cmdBuffer			.word 0x10000
outputColor			.word 0
tvertBuffer			.word 0, 0, 0, 0, 0, 0		; Transformed vertices

numTriangles		.word 4
pyramid				.word 0x0000ff00		; green
					.float 0.0, 0.0, -0.5
					.float 0.5, 0.5, 0.5
					.float 0.5, -0.5, 0.5
					
					.word 0x000000ff		; red
					.float 0.0, 0.0, -0.5
					.float 0.5, -0.5, 0.5
					.float -0.5, -0.5, 0.5
					
					.word 0x00ff0000		; blue
					.float 0.0, 0.0, -0.5
					.float -0.5, -0.5, 0.5
					.float -0.5, 0.5, 0.5
					
					.word 0x00ff00ff		; yellow
					.float 0.0, 0.0, -0.5
					.float -0.5, 0.5, 0.5
					.float 0.5, 0.5, 0.5
					.exitscope


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
					.regalias scalarFbPtr s9
					.regalias scalarBasePtr s10
					.regalias hCounter s11
					.regalias vCounter s12
					.regalias temp s13
					.regalias index u14
					.regalias ptrVectorAtOrigin v0
					.regalias fbPtr v1
					.regalias colorVec v3

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

fbBaseAddress		.word 0xfc000

					.align 64
ptrVecOffsets		.word 0, 4, 8, 12, 256, 260, 264, 268, 512, 516, 520, 524, 768, 772, 776, 780

					.exitscope
					
					
					