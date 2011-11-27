from testcase import *

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