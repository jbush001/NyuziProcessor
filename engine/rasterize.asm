; Algorithm is based on:
; "A Parallel Algorithm for Polygon Rasterization" Juan Pineda, 1988
; http://people.csail.mit.edu/ericchan/bib/pdf/p17-pineda.pdf
;
; Rasterize a single edge based on an edge equation.  We test 16 pixels
; at a time using a vector register.i
;
; Memory map
;
;  0 - Start of code
;  n - end of code
;  0xfc000 Frame buffer start (frame buffer is 64x64 pixels, RGBA)
;  0x100000 Frame buffer end, top of memory
;
					NUM_COLUMNS = 4 	; Number of vector wide columns
					NUM_ROWS = 64

; Set up variables					
; For a point x, y: (x - x0) dY - (y - y0) dX > 0
#define SETUP_EDGE(x1, y1, x2, y2, edgeval, tmpvec, hstep, vstep) \
		hstep = y2 - y1 \
		vstep = x2 - x1 \
		edgeval = mem_l[step_vector] \
		edgeval = edgeval - x1 \
		edgeval = edgeval * hstep \
		tmpvec = -y1 \
		tmpvec = tmpvec * vstep \
		edgeval = edgeval - tmpvec \
		hstep = hstep * 16


#define x0 u0
#define y0 u1
#define x1 u2
#define y1 u3
#define x2 u4
#define y2 u5
#define hStep0 u6
#define vStep0 u7
#define columnCount u8
#define rowCount u9
#define mask0 u10
#define colorVal u11
#define ptr u12

; v0 is temporary
#define colorVector v1
#define edgeVal0 v2
#define leftEdgeVal0 v3



_start				u1 = mem_l[fbstart]

					x0 = 7		; point 1 x
					y0 = 31		; point 1 y
					x1 = 29		; point 2 x
					y1 = 9		; point 2 y

					SETUP_EDGE(x0, y0, x1, y1, leftEdgeVal0, v0, hStep0, vStep0)
					
					ptr = mem_l[fbstart]; output pointer
					columnCount = NUM_COLUMNS	; column counter
					rowCount = NUM_ROWS		; row counter (256)
					colorVal = mem_l[color]	; color
					colorVector = colorVal
					
					edgeVal0 = leftEdgeVal0			; stash the value at first row
loop0				mask0 = edgeVal0 < 0				; Test 16 pixels
					mem_l[ptr]{mask0} = colorVector	; color pixels
					edgeVal0 = edgeVal0 + hStep0 	; when we step x, we add u8 (dY * 16) to the vector
					ptr = ptr + 64		; update pionter
					columnCount = columnCount - 1
					if columnCount goto loop0
					leftEdgeVal0 = leftEdgeVal0 - vStep0 	; vertical step, update right term
					edgeVal0 = leftEdgeVal0
					columnCount = NUM_COLUMNS
					rowCount = rowCount - 1		; deduct row count
					if rowCount goto loop0

					cr31 = u0			; done

fbstart				.word 0xfc000
color				.byte 0xff, 0, 0, 0
					.align 64
step_vector			.word 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15




