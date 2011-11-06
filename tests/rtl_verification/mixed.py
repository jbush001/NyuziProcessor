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
								bfalse s5, no_swap
								mem_b[s0] = s4
								mem_b[s2] = s3
			no_swap				s2 = s2 + 1
								s5 = s2 == s1
								bfalse s5, inner_loop
								s0 = s0 + 1
								s5 = s0 + 1
								s5 = s5 == s1
								bfalse s5, outer_loop
			done				goto done
		''', None, 4, [1, 2, 3, 4, 5, 6, 7, 8], 500)
