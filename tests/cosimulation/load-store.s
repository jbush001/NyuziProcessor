#
# Test simple load stores 
#

		.text
		.align	4

		.globl	_start
		.align	4
		.type	main,@function
_start:	lea s1, testvar1
		
		# Scalar loads
		load_u8 s2, (s1)
		load_u8 s3, 1(s1)
		load_u8 s4, 2(s1)
		load_u8 s5, 3(s1)
		load_u16 s6, (s1)
		load_u16 s7, 2(s1)
		load_32 s8, (s1)

		# Scalar stores
		store_8 s2, 4(s1)
		store_8 s3, 5(s1)
		store_8 s4, 6(s1)
		store_8 s5, 7(s1)
		store_16 s6, 8(s1)
		store_16 s7, 10(s1)
		store_32 s8, 12(s1)
		
		# Reload stored words to ensure they were stored correctly
		load_32 s10, 4(s1)
		load_32 s11, 8(s1)
		load_32 s12, 12(s1)

		# Block vector loads/stores
		lea s10, testvar2
		load_v v1, (s10)
		store_v v1, 64(s10)

		setcr s0, 29		; Halt
done: goto done

			.align 4
testvar1: 	.long 0x12345678, 0, 0, 0
			.align 64
testvar2:	.long 3440378739, 4250892796, 4233383008, 3376522075, 3385158138, 3175690347
			.long 3125411834, 3035294258, 1861950113, 1685601175, 2031058269, 734868089
			.long 30224103, 3013975381, 302019815, 3396086804
testvar3:	.long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
			