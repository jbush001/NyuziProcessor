from testcase import *

def doBitCount(x):
	count = 0
	y = 0x80000000
	while y:
		if x & y:
			count = count + 1
			
		y >>= 1

	return count


class MixedTests(TestCase):
	def test_selectionSort():
		return ({}, '''
			sort_array			.byte 5, 7, 1, 8, 2, 4, 3, 6
			arraylen			.word	8
			
			_start				s0 = &sort_array
								s1 = mem_l[arraylen]
								s1 = s1 + s0				; s1 is now the end pointer
			outer_loop			s2 = s0 + 1
			inner_loop			s3 = mem_b[s0]
								s4 = mem_b[s2]
								s5 = s3 > s4
								if !s5 goto no_swap
								mem_b[s0] = s4
								mem_b[s2] = s3
			no_swap				s2 = s2 + 1
								s5 = s2 == s1
								if !s5 goto inner_loop
								s0 = s0 + 1
								s5 = s0 + 1
								s5 = s5 == s1
								if !s5 goto outer_loop
			done				goto done
		''', None, 4, [1, 2, 3, 4, 5, 6, 7, 8], 1000)

	def test_fibonacci():
		return ({ 'u0' : 9, 'u29' : 0x1000 }, '''
					call	fib
			done	goto  	done
			
		fib			sp = sp - 12
					mem_l[sp] = link
					mem_l[sp + 4] = s1		; save this
					mem_l[sp + 8] = s2		; save this

					if s0 goto notzero
					goto return				; return 0
		notzero		s0 = s0 - 1
					if s0 goto notone
					s0 = s0 + 1
					goto return				; return 1
		notone		s2 = s0	- 1				; save next value
					call fib				; call fib with n - 1
					s1 = s0					; save the return value
					s0 = s2					; restore parameter
					call fib				; call fib with n - 2
					s0 = s0 + s1			; add the two results
		return		link = mem_l[sp]
					s2 = mem_l[sp + 8]
					s1 = mem_l[sp + 4]
					sp = sp + 12
					pc = link		
		''', { 'u0' : 34, 'u29' : None, 'u1' : None, 'u2' : None, 'u30' : None }, None, None, 5000)

	# Vectorized count bits		
	def test_countBits():
		initialVec = allocateRandomVectorValue()
		counts = [ doBitCount(x) for x in initialVec ]
	
		return ({ 'v0' : initialVec }, '''

		loop0	u2 = v0 <> 0
				if !u2 goto done
				v1{u2} = v0 - 1
				v0{u2} = v0 & v1
				v2{u2} = v2 + 1
				goto loop0
		done	nop
		''', { 'v0' : [0 for x in range(16)], 'v1' : None, 'v2' : counts, 'u2' : 0 },
			None, None, None)
			
	def test_matrixMultiply():
		# Multiply v0 by v1, where each is a matrix in row major form
		return ({ 'v0' : [ 1.0, 5.0, 0.0, 9.0, 7.0, 3.0, 3.0, 1.0, 0.0, 0.0, 2.0, 3.0, 1.0, 0.0, 5.0, 7.0],
			'v1' : [ 2.0, 0.0, 1.0, 0.0, 1.0, 2.0, 3.0, 4.0, 9.0, 0.0, 8.0, 0.0, 1.0, 1.0, 1.0, 1.0 ] }, '''
						v2 = mem_l[permute0]
						v3 = shuffle(v0, v2)
						v4 = mem_l[permute1]
						v5 = shuffle(v1, v4)
						vf6 = vf3 * vf5

						v2 = v2 + 1
						v4 = v4 + 4
						v3 = shuffle(v0, v2)
						v5 = shuffle(v1, v4)
						vf3 = vf3 * vf5
						vf6 = vf6 + vf3

						v2 = v2 + 1
						v4 = v4 + 4
						v3 = shuffle(v0, v2)
						v5 = shuffle(v1, v4)
						vf3 = vf3 * vf5
						vf6 = vf6 + vf3

						v2 = v2 + 1
						v4 = v4 + 4
						v3 = shuffle(v0, v2)
						v5 = shuffle(v1, v4)
						vf3 = vf3 * vf5
						vf6 = vf6 + vf3	; result is in v6
						
			done		goto done
		
						;  0  1  2  3
						;  4  5  6  7
						;  8  9 10 11
						; 12 13 14 15
						.align 64
			permute0	.word 0, 0, 0, 0, 4, 4, 4, 4, 8, 8, 8, 8, 12, 12, 12, 12
			permute1	.word 0, 1, 2, 3, 0, 1, 2, 3, 0, 1, 2, 3, 0, 1, 2, 3 
		
		''', { 'v2' : None, 'v3' : None, 'v4' : None, 'v5' : None, 
			'v6' : [ 16.0, 19.0, 25.0, 29.0, 45.0, 7.0, 41.0, 13.0, 21.0, 3.0, 19.0, 3.0, 54.0, 7.0, 48.0, 7.0 ] }, None, None, None)
