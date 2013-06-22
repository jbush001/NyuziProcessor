; 
; Copyright 2011-2013 Jeff Bush
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

				FRAME_BUFFER_ADDRESS = 0x10000000

				.regalias tmp s0
				.regalias ptr s1
				.regalias ycoord s2
				.regalias frame_num s3
				.regalias dudx f4
				.regalias dudy f5
				.regalias dvdx f6
				.regalias dvdy f7
				.regalias step f8
				.regalias texture_base s9

				.regalias xcoord v0
				.regalias pixel_values v1
				.regalias vtmp vf2
				.regalias ui vi9
				.regalias vi vi10
				.regalias uf vf9
				.regalias vf vf10



_start:			tmp = 15
				cr30 = tmp				; start all strands
	
				tmp = cr0
				tmp = tmp << 14
				tmp = tmp | 0xFF
				f8 = 0.003
	
				texture_base = &texture_data

				dudx = 1.0
				dudy = 0.0
				dvdx = 0.0
				dvdy = 1.0

				frame_num = 0
new_frame:		tmp = cr0				; get my strand id
				tmp = tmp << 4			; Multiply by 16 pixels
				xcoord = mem_l[initial_xcoords]
				xcoord = xcoord + tmp	; Add strand offset
				ycoord = 0

				ptr = FRAME_BUFFER_ADDRESS
				tmp = cr0			; get my strand id
				tmp = tmp << 6		; Multiply by 64 bytes
				ptr = ptr + tmp

fill_loop:		; compute pixel values
				uf = itof(ycoord)				; Compute U
				uf = uf * dudy
				vtmp = itof(xcoord)
				vtmp = vtmp * dudx
				uf = uf + vtmp

				vf = itof(ycoord)				; Compute V
				vf = vf * dvdy
				vtmp = itof(xcoord)
				vtmp = vtmp * dvdx
				vf = vf + vtmp

				; Convert to integer coordinates
				ui = ftoi(uf)
				ui = ui & 15		; Wrap
				ui = ui << 2		; Multiply by four bytes
				vi = ftoi(vf)
				vi = vi & 15		; Wrap
				vi = vi << 6		; multiply by 16*4 for stride
				pixel_values = vi | ui
				pixel_values = pixel_values + texture_base	; Create texture address
				pixel_values = mem_l[pixel_values]	; fetch pixels

				; Write out pixels
				mem_l[ptr] = pixel_values
				dflush(ptr)
				
				; Increment horizontally. Strands are interleaved,
				; each one does 16 pixels, then skips forward 64.
				ptr = ptr + 256
				xcoord = xcoord + 64

				tmp = getlane(xcoord, 0)
				tmp = tmp < 640
				if tmp goto fill_loop

				; Past end of line.  Wrap around to the next line.
				xcoord = xcoord - 640 
				ycoord = ycoord + 1
				tmp = ycoord == 480
				if !tmp goto fill_loop
				
				; Done with frame.  Increment frame number and start on the next
				; one (XXX could have a barrier here to wait for everyone else
				; to complete)
				frame_num = frame_num + 1

				; rotate the matrix by one step
				dudx = dudx - step
				dvdy = dvdy - step

				goto new_frame

				.align 64
initial_xcoords: .word 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15
texture_data:	
	.word 0xffffff
	.word 0xffffff
	.word 0xffffff
	.word 0xffffff
	.word 0xfffff8
	.word 0xc8ffeb
	.word 0x68ffe3
	.word 0x28ffdf
	.word 0x7ffdf
	.word 0x7ffe3
	.word 0x28ffeb
	.word 0x68fff8
	.word 0xc8ffff
	.word 0xffffff
	.word 0xffffff
	.word 0xffffff
	.word 0xffffff
	.word 0xffffff
	.word 0xffffff
	.word 0xffffeb
	.word 0x68ffde
	.word 0xffde
	.word 0xffde
	.word 0xffde
	.word 0xffde
	.word 0xffde
	.word 0xffde
	.word 0xffde
	.word 0xffeb
	.word 0x68ffff
	.word 0xffffff
	.word 0xffffff
	.word 0xffffff
	.word 0xffffff
	.word 0xffffe7
	.word 0x48ffde
	.word 0xffde
	.word 0xffde
	.word 0xffde
	.word 0xffde
	.word 0xffde
	.word 0xffde
	.word 0xffde
	.word 0xffde
	.word 0xffde
	.word 0xffe7
	.word 0x48ffff
	.word 0xffffff
	.word 0xffffff
	.word 0xffffeb
	.word 0x68ffde
	.word 0xffde
	.word 0xffde
	.word 0xffde
	.word 0xffde
	.word 0xffde
	.word 0xffde
	.word 0xffde
	.word 0xffde
	.word 0xffde
	.word 0xffde
	.word 0xffde
	.word 0xffeb
	.word 0x68ffff
	.word 0xfffff8
	.word 0xc8ffde
	.word 0xffde
	.word 0xffde
	.word 0xffde
	.word 0xffde
	.word 0xffde
	.word 0xffde
	.word 0xffde
	.word 0xffde
	.word 0xffde
	.word 0xffde
	.word 0xffde
	.word 0xffde
	.word 0xffde
	.word 0xfff8
	.word 0xc8ffeb
	.word 0x68ffde
	.word 0xffde
	.word 0xffde
	.word 0x0
	.word 0x0
	.word 0xffde
	.word 0xffde
	.word 0xffde
	.word 0x0
	.word 0x0
	.word 0xffde
	.word 0xffde
	.word 0xffde
	.word 0xffde
	.word 0xffeb
	.word 0x68ffe3
	.word 0x28ffde
	.word 0xffde
	.word 0xffde
	.word 0x0
	.word 0x0
	.word 0xffde
	.word 0xffde
	.word 0xffde
	.word 0x0
	.word 0x0
	.word 0xffde
	.word 0xffde
	.word 0xffde
	.word 0xffde
	.word 0xffe3
	.word 0x28ffdf
	.word 0x7ffde
	.word 0xffde
	.word 0xffde
	.word 0xffde
	.word 0xffde
	.word 0xffde
	.word 0xffde
	.word 0xffde
	.word 0xffde
	.word 0xffde
	.word 0xffde
	.word 0xffde
	.word 0xffde
	.word 0xffde
	.word 0xffdf
	.word 0x7ffdf
	.word 0x7ffde
	.word 0xffde
	.word 0xffde
	.word 0xffde
	.word 0xffde
	.word 0xffde
	.word 0xffde
	.word 0xffde
	.word 0xffde
	.word 0xffde
	.word 0xffde
	.word 0xffde
	.word 0xffde
	.word 0xffde
	.word 0xffdf
	.word 0x7ffe3
	.word 0x28ffde
	.word 0xffde
	.word 0xffde
	.word 0xffde
	.word 0xffde
	.word 0xffde
	.word 0xffde
	.word 0xffde
	.word 0xffde
	.word 0xffde
	.word 0xffde
	.word 0xffde
	.word 0xffde
	.word 0xffde
	.word 0xffe3
	.word 0x28ffeb
	.word 0x68ffde
	.word 0xffde
	.word 0xffde
	.word 0xffde
	.word 0xffde
	.word 0xffde
	.word 0xffde
	.word 0xffde
	.word 0xffde
	.word 0xffde
	.word 0x0
	.word 0xffde
	.word 0xffde
	.word 0xffde
	.word 0xffeb
	.word 0x68fff8
	.word 0xc8ffde
	.word 0xffde
	.word 0x0
	.word 0x0
	.word 0xffde
	.word 0xffde
	.word 0xffde
	.word 0xffde
	.word 0xffde
	.word 0xffde
	.word 0x0
	.word 0xffde
	.word 0xffde
	.word 0xffde
	.word 0xfff8
	.word 0xc8ffff
	.word 0xffffeb
	.word 0x68ffde
	.word 0xffde
	.word 0x0
	.word 0x0
	.word 0x0
	.word 0xffde
	.word 0xffde
	.word 0x0
	.word 0x0
	.word 0x0
	.word 0xffde
	.word 0xffde
	.word 0xffeb
	.word 0x68ffff
	.word 0xffffff
	.word 0xffffff
	.word 0xffffe7
	.word 0x48ffde
	.word 0xffde
	.word 0xffde
	.word 0x0
	.word 0x0
	.word 0x0
	.word 0x0
	.word 0xffde
	.word 0xffde
	.word 0xffde
	.word 0xffe7
	.word 0x48ffff
	.word 0xffffff
	.word 0xffffff
	.word 0xffffff
	.word 0xffffff
	.word 0xffffeb
	.word 0x68ffde
	.word 0xffde
	.word 0xffde
	.word 0xffde
	.word 0xffde
	.word 0xffde
	.word 0xffde
	.word 0xffde
	.word 0xffeb
	.word 0x68ffff
	.word 0xffffff
	.word 0xffffff
	.word 0xffffff
	.word 0xffffff
	.word 0xffffff
	.word 0xffffff
	.word 0xfffff8
	.word 0xc8ffeb
	.word 0x68ffe3
	.word 0x28ffdf
	.word 0x7ffdf
	.word 0x7ffe3
	.word 0x28ffeb
	.word 0x68fff8
	.word 0xc8ffff
	.word 0xffffff
	.word 0xffffff
	.word 0xffffff




