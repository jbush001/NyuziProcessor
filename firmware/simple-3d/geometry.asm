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
; Given a vertex with points x, y, z in world space, return
; the position x, y of the projected vertex in raster coordinates.
;

transformVertex:	.enterscope

					;; Input parameters
					.regalias x f0
					.regalias y f1
					.regalias z f2
					; X and Y outputs are returned in u0 and u1

					;; Temporaries
					.regalias sx u7
					.regalias sy u8
					.regalias w f3			; parameter/return value mulMatrixVec
					.regalias oneOverW f3	; reuse w register
					.regalias matrixPtr u4	; parameter to mulMatrixVec
					.regalias halfTileFloat f5
					.regalias halfTileInt u6

					; Rotate
					w = mem_l[onePointOh]
					matrixPtr = &mvpMatrix
					
					sp = sp - 4
					mem_l[sp] = link
					
					call @mulMatrixVec
					
					link = mem_l[sp]
					sp = sp + 4

					; Convert from screen space to raster coordinates...
					; -1 to 1 -> 0 to 63
					halfTileFloat = mem_l[halfTileSizeF]
					halfTileInt = mem_l[halfTileSizeI]

					oneOverW = reciprocal(w)		; w returned by mulMatrixVec
		
;					x = x * oneOverW				; perspective divide
					
					x = x * halfTileFloat
					sx = ftoi(x)
					sx = sx + halfTileInt

;					y = y * oneOverW				; perspective divide
					y = y * halfTileFloat
					sy = ftoi(y)
					sy = halfTileInt - sy
					
					u0 = sx
					u1 = sy
					
					pc = link

onePointOh:			.float 1.0
halfTileSizeF:		.float 32.0
halfTileSizeI:		.word 32
mvpMatrix:			.float 0.2138, -0.712666, 0.485503, 5.29548e-08
					.float -0.850966, -0.25529, 0, 0
					.float -0.156878, 0.522926, 0.836681, -0.0903695
					.float -0.157027, 0.523424, 0.837478, 1.9105
					.exitscope

;
; Multiply a matrix times a vector
; Matrix is in row major form
; 

mulMatrixVec:		.enterscope

					;; Parameters/Results
					.regalias x f0	; inout
					.regalias y f1	; inout
					.regalias z f2	; inout
					.regalias w f3	; inout
					.regalias matrixPtr u4 ; in
					
					;; Temporaries					
					.regalias matrixCell f5
					.regalias mulTmp f6

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

					x = f7
					y = f8
					z = f9
					w = f10

					pc = link

					.exitscope
					
					