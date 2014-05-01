			.globl _start
_start:		lea s0, ops
			lea s10, end
test_loop:	load_32 s1, (s0)
			load_32 s2, 4(s0)
			add_f s3, s1, s2
			sub_f s4, s1, s2
			mul_f s5, s1, s2
			add_i s0, s0, 8
			setge_i s6, s0, s10
			bfalse s6, test_loop
			setcr s0, 29
done: 		goto done

ops:		.float 17.79, 19.32 			; Exponents are equal.  This will carry into the next significand bit
			.float 0.34, 44.23 				; Exponent 2 larger
			.float 44.23, 0.034 			; Exponent 1 larger
			.float -1.0, 5.0 				; First element is negative and has smaller exponent
			.float -5.0, 1.0 				; First element is negative and has larger exponent		
			.float 5.0, -1.0 				; Second element is negative and has smaller exponent
			.float 1.0, -5.0 				; Second element is negative and has larger exponent
			.float 5.0, 0.0 				; Zero identity (zero is a special case in IEEE754)
			.float 0.0, 5.0
			.float 0.0, 0.0
			.float 7.0, -7.0 				; Result is zero
			.float 1000000.0, 0.0000001 	; Second op is lost because of precision
			.float 0.0000001, 0.00000001 	; Very small number 
			.float 1000000.0, 10000000.0 	; Very large number
			.float -0.0, 2.323				; negative zero
			.float 2.323, -0.0				; negative zero
			.float 5.67666007898e-42, 0.0	; subnormal minus zero
			.float nan, 0
			.float nan, nan
			.float 0, nan
			.float inf, 0
			.float inf, inf
			.float 0, inf
end:		.long 0