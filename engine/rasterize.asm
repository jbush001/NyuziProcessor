; Algorithm is based on:
; "A Parallel Algorithm for Polygon Rasterization" Pineda
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


_start				u1 = mem_l[fbstart]

					; edge 1
					u3 = 7		; point 1 x
					u4 = 31	; point 1 y
					u5 = 29	; point 2 x
					u6 = 9		; point 2 y

					; Set up variables					
					; For a point x, y: (x - x0) dY - (y - y0) dX > 0
					u7 = u6 - u4		; dY
					u8 = u5 - u3		; dX

					; compute the value of the edge function at 0,0,
					; which is -x0 dY, -y0 dX
					v0 = mem_l[step_vector]	; x 
					v0 = v0 - u3		; x - x0
					v0 = v0 * u7		; (x - x0) * dY

					v1 = -u4			; y - y0
					v1 = v1 * u8		; (y - y0) * dX
					v0 = v0 - v1		; full equation

					u7 = u7 * 16		; Compute horizontal step, 16 elements
					u10 = mem_l[fbstart]; output pointer
					u11 = NUM_COLUMNS	; column counter
					u12 = NUM_ROWS		; row counter (256)
					u13 = mem_l[color]	; color
					v2 = u13
					
					v1 = v0				; stash the value at first row
loop0				u9 = v0 < 0			; Test 16 pixels
					mem_l[u10]{u9} = v2	; color pixels
					v0 = v0 + u7 		; when we step x, we add u8 (dY * 16) to the vector
					u10 = u10 + 64		; update pionter
					u11 = u11 - 1
					if u11 goto loop0
					v1 = v1 - u8 		; vertical step, update right term
					v0 = v1
					u11 = NUM_COLUMNS
					u12 = u12 - 1		; deduct row count
					if u12 goto loop0

					cr31 = u0			; done


fbstart				.word 0xfc000
color				.byte 0xff, 0, 0, 0
					.align 64
step_vector			.word 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15




