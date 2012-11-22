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

StartFrame:			.enterscope
					.saveregs link
					
					u0 = &cube
					u1 = mem_l[numTriangles]

					;call @clearFrameBuffer
					call @DrawTriangles
					
					.restoreregs link
					pc = link
					
numTriangles:		.word 12
cube:				.word 0xff0000ff
					.float 0.5,0.5,-0.5
					.float -0.5,0.5,-0.5
					.float -0.5,0.5,0.5
			
					.word 0xff0000ff
					.float -0.5,0.5,0.5
					.float 0.5,0.5,0.5
					.float 0.5,0.5,-0.5
			
					.word 0x00ff00ff
					.float 0.5,-0.5,0.5
					.float -0.5,-0.5,0.5
					.float -0.5,-0.5,-0.5
			
					.word 0x00ff00ff
					.float -0.5,-0.5,-0.5
					.float 0.5,-0.5,-0.5
					.float 0.5,-0.5,0.5
			
					.word 0x0000ffff
					.float 0.5,0.5,0.5
					.float -0.5,0.5,0.5
					.float -0.5,-0.5,0.5
			
					.word 0x0000ffff
					.float -0.5,-0.5,0.5
					.float 0.5,-0.5,0.5
					.float 0.5,0.5,0.5
			
					.word 0xff00ffff
					.float 0.5,-0.5,-0.5
					.float -0.5,-0.5,-0.5
					.float -0.5,0.5,-0.5
			
					.word 0xff00ffff
					.float -0.5,0.5,-0.5
					.float 0.5,0.5,-0.5
					.float 0.5,-0.5,-0.5
			
					.word 0xffff00ff
					.float -0.5,0.5,0.5
					.float -0.5,0.5,-0.5
					.float -0.5,-0.5,-0.5
			
					.word 0xffff00ff
					.float -0.5,-0.5,-0.5
					.float -0.5,-0.5,0.5
					.float -0.5,0.5,0.5
			
					.word 0x00ffffff
					.float 0.5,0.5,-0.5
					.float 0.5,0.5,0.5
					.float 0.5,-0.5,0.5
			
					.word 0x00ffffff
					.float 0.5,-0.5,0.5
					.float 0.5,-0.5,-0.5
					.float 0.5,0.5,-0.5
					.exitscope

FinishFrame: 		call @FlushFrameBuffer
					cr31 = s0		; Halt

;;
;; Draw triangles
;;  u0 - geometry pointer
;;  u1 - triangle count
;;
DrawTriangles:		.enterscope

					;; Temporary registers
					.regalias geometryPointer u12
					.regalias triangleCount u13
					.regalias vertexCount u14
					.regalias tvertPtr u15
					.regalias color u16
					.regalias job u17
					.regalias jobtmp u18

					.saveregs u12, u13, u14, u15, u16, link
					
					geometryPointer = u0
					triangleCount = u1

triLoop0:			vertexCount = 3
					call @AllocateJob
					job = s0
					jobtmp = job + 8		; Offset past header
					
					color = mem_l[geometryPointer]
					;; XXX do something with color
					geometryPointer = geometryPointer + 4

vertexLoop:			f0 = mem_l[geometryPointer]			; x
					f1 = mem_l[geometryPointer + 4]		; y
					f2 = mem_l[geometryPointer + 8]		; z
					geometryPointer = geometryPointer + 12
					
					call @TransformVertex

					;; Save the return values
					mem_l[jobtmp] = u0		; Save X
					mem_l[jobtmp + 4] = u1	; Save Y
					jobtmp = jobtmp + 8
					
					vertexCount = vertexCount - 1
					if vertexCount goto vertexLoop

					; We have three transformed vertices, enqueue a job to rasterize it
					s0 = job
					s1 = 5		; RasterizeTriangle
					call @EnqueueJob

					triangleCount = triangleCount - 1
					if triangleCount goto triLoop0

					.restoreregs u12, u13, u14, u15, u16, link

					pc = link

outputColor:		.word 0

					.exitscope
