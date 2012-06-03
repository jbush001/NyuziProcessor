_start		s2 = 0xf
			cr30 = s2		; Enable all strands

			; load something interesting into scratchpad registers
			s3 = 4051
			s3 = s3 * 4049
			s4 = s3 * 59
			s5 = s4 * 103
			s6 = s5 ^ s4
			s7 = s6 * 17
			v3 = s3
			v4 = s4
			v5 = s5
			v6 = s6
			v7 = s7
			v3{s7} = v3 ^ v4
			v4{s6} = v4 ^ v5
			v5{s5} = v5 ^ v6
			v6{s4} = v6 ^ v7
			v7{s3} = v7 ^ v3
			
			s2 = cr0		; Get strand ID
			
			; set up address of private memory region (s0 is public and is left set to 0)
			s1 = s2 + 1	
			s1 = s1 << 17	; Multiply by 128k, so each strand starts on a new page
			v1 = s1			; set v1 as the same for now

			; Compute branch address			
			s2 = s2 << 9	; Multiply by 512 bytes (128 instructions)
			pc = pc + s2	; jump to start address for this strand

