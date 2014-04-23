#
# Test simple load stores
#

		.text
		.align	4

		.globl	_start
		.align	4
		.type	main,@function
_start:	lea s1, testvar1
		
		# Scalar loads (signed and unsigned, all widths and valid alignments)
		load_u8 s2, (s1)	# Byte
		load_u8 s3, 1(s1)
		load_u8 s4, 2(s1)
		load_u8 s5, 3(s1)

		load_s8 s6, (s1)	# Sign extension
		load_s8 s7, 1(s1)
		load_s8 s8, 2(s1)
		load_s8 s9, 3(s1)

		load_u16 s2, (s1)	# Half word
		load_u16 s3, 2(s1)

		load_s16 s4, (s1)	# Sign extension
		load_s16 s5, 2(s1)

		load_32 s8, (s1)	# Word

		# Scalar stores
		store_8 s2, 4(s1)
		store_8 s3, 5(s1)
		store_8 s4, 6(s1)
		store_8 s5, 7(s1)
		store_16 s6, 8(s1)
		store_16 s7, 10(s1)
		store_32 s8, 12(s1)
		
		# Reload stored words to ensure they come back correctly
		load_32 s10, 4(s1)
		load_32 s11, 8(s1)
		load_32 s12, 12(s1)

		# Block vector loads/store
		lea s10, testvar2
		load_v v1, (s10)
		store_v v1, 64(s10)
		load_v v2, 64(s10)
		
		# Gather load
		load_v v4, shuffleIdx
		lea s1, testvar2
		add_i v4, v4, s1
		load_gath v3, (v4)
		
		# Scatter store
		load_v v5, testvar2
		load_v v4, shuffleIdx
		lea s1, testvar4
		add_i v4, v4, s1
		store_scat v5, (v4)

		setcr s0, 29		; Halt
done: goto done

			.align 4
testvar1: 	.long 0x1234abcd, 0, 0, 0
			.align 64
testvar2:	.long 3440378739, 4250892796, 4233383008, 3376522075, 3385158138, 3175690347
			.long 3125411834, 3035294258, 1861950113, 1685601175, 2031058269, 734868089
			.long 30224103, 3013975381, 302019815, 3396086804
testvar3:	.long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
testvar4:   .long 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
shuffleIdx: .long 0, 60, 56, 52, 48, 44, 40, 36, 32, 28, 24, 20, 16, 12, 8, 4

			