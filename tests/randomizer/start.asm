_start		s2 = 0xf
			cr30 = s2		; Enable all strands
			s2 = cr0		; Get strand ID
			
			; set up address of private memory region
			s1 = s1 + 1	
			s1 = s2 << 17	; Multiply by 128k, so each strand starts on a new page
			
			s2 = s2 << 9	; Multiply by 512 bytes (128 instructions)
			pc = pc + s2	; jump to start address for this strand
			
			