;
;
; Rendering proceeds in two phases.
; The geometry phase is single-threaded.  Vertices are rotated by a
; modelview/projection matrix and converted to screen coordinates.
; The pixel phase uses multiple threads, with each one filling a vertical
; strip of the screen.  They use the vector unit to compute edge equations
; for 16 pixels in parallel.
; Rasterization algorithm is based on:
; "A Parallel Algorithm for Polygon Rasterization" Juan Pineda, 1988
; http://people.csail.mit.edu/ericchan/bib/pdf/p17-pineda.pdf
;
; Memory map
;
;  0 - Start of code
;  n - end of code
;  0xf8000 strand 0 stack
;  0xf9000 strand 1 stack
;  0xfa000 strand 2 stack
;  0xfb000 strand 3 stack
;  0xfc000 Frame buffer start (frame buffer is 64x64 pixels, RGBA)
;  0x100000 Frame buffer end, top of memory
;
; All registers are caller save
;

#define PUSH_REG(x) sp = sp - 4  mem_l[sp] = x
#define POP_REG(x) x = mem_l[sp] sp = sp + 4


_start				s0 = cr0		; get my strand ID

					; Set up my stack
					u1 = &stackPtrs
					u2 = s0 << 2
					u1 = u1 + u2
					sp = mem_l[u1]

					if s0 goto rasterize
					

#define vertexCount u11
#define triangleCount u12
					
					u10 = &geometry
					triangleCount = mem_l[numTriangles]
					
triLoop0			u0 = mem_l[u10]			; grab color
					PUSH_REG(u10)	
					PUSH_REG(triangleCount)
					call queueColor
					POP_REG(triangleCount)
					POP_REG(u10)
					u10 = u10 + 4
					vertexCount = 3
vertexLoop			f0 = mem_l[u10]			; x
					f1 = mem_l[u10 + 4]		; y
					f2 = mem_l[u10 + 8]		; z
					f3 = mem_l[fpOne]		; w
					PUSH_REG(u10)
					PUSH_REG(vertexCount)
					PUSH_REG(triangleCount)
					call queueVertex
					POP_REG(triangleCount)
					POP_REG(vertexCount)
					POP_REG(u10)
					u10 = u10 + 12
					vertexCount = vertexCount - 1
					if vertexCount goto vertexLoop
					triangleCount = triangleCount - 1
					if triangleCount goto triLoop0
	
					s0 = 15
					cr30 = s0		; Start all strands
					goto rasterize

numTriangles		.word 4


; Make a pyramid
geometry			.word 0x0000ff00		; green
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

stackPtrs			.word 0xf7ffc, 0xf8ffc, 0xf9ffc, 0xfaffc
fpOne				.float 1.0


; Set up variables					
; For a point x, y: (x - x0) dY - (y - y0) dX > 0
#define SETUP_EDGE(x1, y1, x2, y2, edgeval, tmpvec, hstep, vstep) \
		hstep = y2 - y1 \
		vstep = x2 - x1 \
		edgeval = mem_l[stepVector] \
		edgeval = edgeval - x1 \
		edgeval = edgeval * hstep \
		tmpvec = -y1 \
		tmpvec = tmpvec * vstep \
		edgeval = edgeval - tmpvec \
		hstep = hstep * 16

		
rasterize			.enterscope
					
					.regalias x0 u0
					.regalias y0 u1
					.regalias x1 u2
					.regalias y1 u3
					.regalias x2 u4
					.regalias y2 u5
					.regalias hStep0 u6
					.regalias vStep0 u7
					.regalias rowCount u9
					.regalias mask0 u10
					.regalias colorVal u11
					.regalias ptr u12
					.regalias mask1 u13
					.regalias hStep1 u14
					.regalias vStep1 u15
					.regalias hStep2 u16
					.regalias vStep2 u17
					.regalias strandId u19
					.regalias tmp1 u20
					.regalias cmdPtr u21
					.regalias tmp2 u22

					; v0 is temporary
					.regalias colorVector v1
					.regalias edgeVal0 v2
					.regalias edgeVal1 v3
					.regalias edgeVal2 v4


					strandId = cr0

					cmdPtr = &@cmdFifo

					NUM_ROWS = 64

triangleLoop		colorVal = mem_l[cmdPtr]
					x0 = mem_l[cmdPtr + 4]	
					y0 = mem_l[cmdPtr + 8]	
					x1 = mem_l[cmdPtr + 12]	
					y1 = mem_l[cmdPtr + 16]
					x2 = mem_l[cmdPtr + 20]
					y2 = mem_l[cmdPtr + 24]
					cmdPtr = cmdPtr + 28

					SETUP_EDGE(x0, y0, x1, y1, edgeVal0, v0, hStep0, vStep0)
					SETUP_EDGE(x1, y1, x2, y2, edgeVal1, v0, hStep1, vStep1)
					SETUP_EDGE(x2, y2, x0, y0, edgeVal2, v0, hStep2, vStep2)

					rowCount = NUM_ROWS		; row counter (256)
					colorVector = colorVal

					ptr = mem_l[fbstart]; output pointer

					; Each strand fills one vertical strip.  Compute
					; the offsets here.
					tmp1 = strandId << 6	; multiply * 64
					ptr = ptr + tmp1

					tmp1 = hStep0 * strandId
 					edgeVal0 = edgeVal0 + tmp1
					tmp1 = hStep1 * strandId
 					edgeVal1 = edgeVal1 + tmp1
					tmp1 = hStep2 * strandId
 					edgeVal2 = edgeVal2 + tmp1

rowLoop				mask0 = edgeVal0 < 0				; Test 16 pixels
					mask1 = edgeVal1 < 0
					mask0 = mask0 & mask1
					mask1 = edgeVal2 < 0
					mask0 = mask0 & mask1
					mem_l[ptr]{mask0} = colorVector	; color pixels
					ptr = ptr + 256		; update pointer
					edgeVal0 = edgeVal0 - vStep0 
					edgeVal1 = edgeVal1 - vStep1
					edgeVal2 = edgeVal2 - vStep2 
					rowCount = rowCount - 1		; deduct row count
					if rowCount goto rowLoop

					; Are there more commands in the FIFO?
					tmp1 = mem_l[cmdFifoLength]
					tmp1 = tmp1 << 2	; multiply times 4
					tmp2 = &@cmdFifo
					tmp1 = tmp1 + tmp2
					tmp2 = cmdPtr < tmp1
					if tmp2 goto triangleLoop
					
					; No, falls through

					nop
					nop
					nop
					nop
					nop
					nop
					nop
					nop
					cr31 = u0

					.align 64
stepVector			.word 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15
fbstart				.word 0xfc000

					.exitscope


; f0 - x
; f1 - y
; f2 - z
; f3 - w
queueVertex			PUSH_REG(link)

					; Rotate
					u4 = &mvpMatrix
					call mulMatrixVec

					u4 = &@cmdFifo
					u5 = mem_l[@cmdFifoLength]
					u5 = u5 << 2	; multiply times 4
					u4 = u4 + u5

					; Convert from screen space to raster coordinates...
					; -1 to 1 -> 0 to 63
					f6 = mem_l[halfTileSizeF]
					u7 = mem_l[halfTileSizeI]

					f9 = reciprocal(f3)
					
					f0 = f0 * f9				; perspective divide
					u8 = sftoi(f0, f6)			; x
					u8 = u8 + u7
					mem_l[u4] = u8

					f1 = f1 * f9				; perspective divide
					u8 = sftoi(f1, f6)			; y
					u8 = u7 - u8 
					mem_l[u4 + 4] = u8

					u5 = mem_l[cmdFifoLength]
					u5 = u5 + 2
					mem_l[cmdFifoLength] = u5
					
					POP_REG(link)
					pc = link

halfTileSizeF		.float 32.0
halfTileSizeI		.word 32
mvpMatrix			.float 0.965925826, 0.06698729805, 0.2499999998, 0.0
					.float 0.0, 1.0329131240, -0.258819045, 0.0
					.float -0.258819045, 0.24999999982, 0.933012701, 0.0
					.float 0.0, 0.0, 2.0, 0.0

; u0 - color
queueColor			u1 = &cmdFifo
					u2 = mem_l[@cmdFifoLength]
					u2 = u2 << 2	; multiply times 4
					u1 = u1 + u2
					mem_l[u1] = u0

					u2 = mem_l[@cmdFifoLength]
					u2 = u2 + 1
					mem_l[@cmdFifoLength] = u2

					pc = link

cmdFifoLength		.word 0			; Number of words
cmdFifo				.reserve 256


;
; Multiply a matrix times a vector
; f0, f1, f2, f3 vector.  Results copied back to here.
; u4 Pointer to matrix, row major
; 

mulMatrixVec		.enterscope

					.regalias mulTmp f6
					.regalias x f0
					.regalias y f1
					.regalias z f2
					.regalias w f3
					.regalias matrixCell f5

					matrixCell = mem_l[u4]
					f7 = matrixCell * x
					matrixCell = mem_l[u4 + 4]
					mulTmp = matrixCell * y
					f7 = f7 + mulTmp
					matrixCell = mem_l[u4 + 8]
					mulTmp = matrixCell * z
					f7 = f7 + mulTmp
					matrixCell = mem_l[u4 + 12]
					mulTmp = matrixCell * w
					f7 = f7 + mulTmp

					matrixCell = mem_l[u4 + 16]
					f8 = matrixCell * x
					matrixCell = mem_l[u4 + 20]
					mulTmp = matrixCell * y
					f8 = f8 + mulTmp
					matrixCell = mem_l[u4 + 24]
					mulTmp = matrixCell * z
					f8 = f8 + mulTmp
					matrixCell = mem_l[u4 + 28]
					mulTmp = matrixCell * w
					f8 = f8 + mulTmp

					matrixCell = mem_l[u4 + 32]
					f9 = matrixCell * x
					matrixCell = mem_l[u4 + 36]
					mulTmp = matrixCell * y
					f9 = f9 + mulTmp
					matrixCell = mem_l[u4 + 40]
					mulTmp = matrixCell * z
					f9 = f9 + mulTmp
					matrixCell = mem_l[u4 + 44]
					mulTmp = matrixCell * w
					f9 = f9 + mulTmp

					matrixCell = mem_l[u4 + 48]
					f10 = matrixCell * x
					matrixCell = mem_l[u4 + 52]
					mulTmp = matrixCell * y
					f10 = f10 + mulTmp
					matrixCell = mem_l[u4 + 56]
					mulTmp = matrixCell * z
					f10 = f10 + mulTmp
					matrixCell = mem_l[u4 + 60]
					mulTmp = matrixCell * w
					f10 = f10 + mulTmp

					f0 = f7
					f1 = f8
					f2 = f9
					f3 = f10

					pc = link

					.exitscope
					






