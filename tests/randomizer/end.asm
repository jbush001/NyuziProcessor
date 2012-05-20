_start				s2 = cr0		; get strand ID
					s3 = 1
					s3 = s3 << s2	; convert to mask
					s3 = ~s3		; invert
					
					s2 = cr30		; get active strand mask
					s2 = s2 & s3	; turn myself off
					cr30 = s2
					nop
					nop
					nop
					nop
done				goto done					