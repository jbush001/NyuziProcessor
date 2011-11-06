from testcase import TestCase

class BranchTests(TestCase):
	def test_goto():
		return ({ 'u1' : 1 }, '''		goto label1
					u0 = u0 + 5
		loop1		goto loop1		
		label1 		u0 = u0 + 12
		loop2		goto loop2''', { 'u0' : 12 }, None, None, None)

	
	def test_pcDest():
		return ({}, '''		
						u0 = &label
						pc = u0
			loop0		goto loop0
						u1 = u1 + 13
			loop1		goto loop1
			label		u1 = u1 + 17
			loop2		goto loop2
						u1 = u1 + 57
			loop3		goto loop3''',
			{ 'u0' : None, 'u1' : 17 }, None, None, None)

	def test_bzeroNotTaken():
		return ({ 'u1' : 0 }, '''		bzero u1, label1
						u0 = u0 + 5
			loop1		goto loop1		
			label1 		u0 = u0 + 12
			loop2		goto loop2''', { 'u0' : 12 }, None, None, None)
		
	def test_bzeroTaken():
		return ({ 'u1' : 1 }, '''		bzero u1, label1
						u0 = u0 + 5
			loop1		goto loop1		
			label1 		u0 = u0 + 12
			loop2		goto loop2''', { 'u0' : 5 }, None, None, None)
		
	def test_bnzeroNotTaken():
		return ({ 'u1' : 0 }, '''		bnzero 	u1, label1
						u0 = u0 + 5
			loop1		goto loop1		
			label1 		u0 = u0 + 12
			loop2		goto loop2''', { 'u0' : 5 }, None, None, None)

	def test_bnzeroTaken():		
		return ({ 'u1' : 1 }, '''		bnzero 	u1, label1
						u0 = u0 + 5
			loop1		goto loop1		
			label1 		u0 = u0 + 12
			loop2		goto loop2''', { 'u0' : 12 }, None, None, None)

	def test_ballNotTakenSomeBits():
		return ({ 'u1' : 1 }, '''		ball u1, label1
						u0 = u0 + 5
			loop1		goto loop1		
			label1 		u0 = u0 + 12
			loop2		goto loop2''', { 'u0' : 5 }, None, None, None)

	def test_ballNotTakenNoBits():
		return ({ 'u1' : 0 }, '''		
						ball u1, label1
						u0 = u0 + 5
			loop1		goto loop1		
			label1 		u0 = u0 + 12
			loop2		goto loop2''', { 'u0' : 5 }, None, None, None)

	def test_ballTaken():
		return ({ 'u1' : 0xffff }, '''		
						ball u1, label1
						u0 = u0 + 5
			loop1		goto loop1		
			label1 		u0 = u0 + 12
			loop2		goto loop2''', { 'u0' : 12 }, None, None, None)
	
	def test_ballTakenSomeBits():
		return ({ 'u1' : 0x20ffff }, '''		
						ball u1, label1
						u0 = u0 + 5
			loop1		goto loop1		
			label1 		u0 = u0 + 12
			loop2		goto loop2''', { 'u0' : 12 }, None, None, None)

	def test_rollback():
		return ({},'''
				goto label1
				u0 = u0 + 234
				u1 = u1 + 456
				u2 = u2 + 37
				u3 = u3 + 114
		label3	u4 = u4 + 9
		done	goto done
				u5 = u5 + 12
		label1	goto label3
				u4 = u4 + 99
		''', { 'u4' : 9 }, None, None, None)

	