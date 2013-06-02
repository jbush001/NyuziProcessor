
				FRAME_BUFFER_ADDRESS = 0x10000000

				.regalias tmp s0
				.regalias ptr s1
				.regalias ycoord s2
				.regalias frame_num s3
				.regalias xcoord v0
				.regalias pixel_values v1


_start:			tmp = 15
				cr30 = tmp				; start all strands

				tmp = cr0
				tmp = tmp << 14
				tmp = tmp | 0xFF

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
				; ((x + y) ^ x) + f
				pixel_values = xcoord + ycoord
				pixel_values = pixel_values ^ xcoord
				pixel_values = pixel_values + frame_num
				pixel_values = pixel_values << 8

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

				s10 = 1000000
delay0:			s10 = s10 - 1
				if s10 goto delay0


				goto new_frame

				.align 64
initial_xcoords: .word 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15

