from testcase import TestCase

class BranchTests(TestCase):
	def test_goto():
		return ({ 'u1' : 1 }, '''		
					goto label1
					u0 = u0 + 5
					goto ___done
		label1 		u0 = u0 + 12
					goto ___done
		''', { 't0u0' : 12 }, None, None, None)

	
	def test_pcDest():
		return ({}, '''		
						u0 = &label
						pc = u0
						goto ___done
						u1 = u1 + 13
						goto ___done
			label		u1 = u1 + 17
						goto ___done
						u1 = u1 + 57
						goto ___done
			''',
			{ 't0u0' : None, 't0u1' : 17 }, None, None, None)

	def test_bzeroTaken():
		return ({ 'u1' : 0 }, '''		
						if !u1 goto label1
						u0 = u0 + 5
						goto ___done
			label1 		u0 = u0 + 12
						goto ___done
			''', { 't0u0' : 12 }, None, None, None)
		
	def test_bzeroNotTaken():
		return ({ 'u1' : 1 }, '''		
						if !u1 goto label1
						u0 = u0 + 5
						goto ___done
			label1 		u0 = u0 + 12
						goto ___done
			''', { 't0u0' : 5 }, None, None, None)
		
	def test_bnzeroNotTaken():
		return ({ 'u1' : 0 }, '''		
						if u1 goto label1
						u0 = u0 + 5
						goto ___done
			label1 		u0 = u0 + 12
						goto ___done
			''', { 't0u0' : 5 }, None, None, None)

	def test_bnzeroTaken():		
		return ({ 'u1' : 1 }, '''			
						if u1 goto label1
						u0 = u0 + 5
						goto ___done
			label1 		u0 = u0 + 12
						goto ___done
			''', { 't0u0' : 12 }, None, None, None)

	def test_ballNotTakenSomeBits():
		return ({ 'u1' : 1 }, '''		
						if all(u1) goto label1
						u0 = u0 + 5
						goto ___done		
			label1 		u0 = u0 + 12
						goto ___done		
			''', { 't0u0' : 5 }, None, None, None)

	def test_ballNotTakenNoBits():
		return ({ 'u1' : 0 }, '''		
						if all(u1) goto label1
						u0 = u0 + 5
						goto ___done
			label1 		u0 = u0 + 12
						goto ___done
			''', { 't0u0' : 5 }, None, None, None)

	def test_ballTaken():
		return ({ 'u1' : 0xffff }, '''		
						if all(u1) goto label1
						u0 = u0 + 5
						goto ___done
			label1 		u0 = u0 + 12
						goto ___done
			''', { 't0u0' : 12 }, None, None, None)
	
	def test_ballTakenSomeBits():
		return ({ 'u1' : 0x20ffff }, '''		
						if all(u1) goto label1
						u0 = u0 + 5
						goto ___done
			label1 		u0 = u0 + 12
						goto ___done
			''', { 't0u0' : 12 }, None, None, None)

	def test_rollback():
		return ({},'''
				goto label1
				u0 = u0 + 234
				u1 = u1 + 456
				u2 = u2 + 37
				u3 = u3 + 114
		label3	u4 = u4 + 9
				goto ___done
				u5 = u5 + 12
		label1	goto label3
				u4 = u4 + 99
		''', { 't0u4' : 9 }, None, None, None)
		
	def test_call():
		return ({}, '''		
						call label1
						u0 = u0 + 7
						goto ___done
			label1 		u0 = u0 + 12
						goto ___done
			''', { 't0u0' : 12, 't0u30' : 8 }, None, None, None)
		
		
	# Note that this will be a cache miss the first time, which 
	# validates that the thread is rolled back and restarted
	# correctly (rather than just branching to address 0)
	def test_pcload():
		return ({}, '''
		
					s0 = &pc_ptr
					pc = mem_l[s0]
					goto ___done
					s1 = s1 + 12
					goto ___done
			target	s1 = s1 + 17
					goto ___done
					s1 = s1 + 29
					
			pc_ptr	.word target
			''', { 't0u0' : None, 't0u1' : 17 }, None, None, None)
	

	def test_strandBranches():
		return ({}, '''
					u0 = 15
					cr30 = u0		; Start all threads


					u0 = cr0		; get the strand id
					u0 = u0 << 2	; multiply by 4
					pc = pc + u0	; offset into branch table
					goto strand0
					goto strand1
					goto strand2
					goto strand3

			; Tight loop. Generates a bunch of rollbacks.
			; This kills everything when it is done
			strand0	u1 = 50
			loop5	u1 = u1 - 1
					if u1 goto loop5
					goto ___done

			; Perform a bunch of operations without branching.
			; Ensure rollback of other strands doesn't affect this.
			strand1	u1 = u1 + 1
					u1 = u1 + 1
					u1 = u1 + 1
					u1 = u1 + 1
					u1 = u1 + 1
					u1 = u1 + 1
					u1 = u1 + 1
					u1 = u1 + 1
					u1 = u1 + 1
					u1 = u1 + 1
					u1 = u1 + 1
					u1 = u1 + 1
					u1 = u1 + 1
					u1 = u1 + 1
					u1 = u1 + 1
					u1 = u1 + 1
					u1 = u1 + 1
			loop0	goto loop0
			
			; This strand iterates runs a loop and generates periodic rollbacks
			strand2	u2 = 4
			loop1	u1 = u1 + 7
					u2 = u2 - 1
					if u2 goto loop1
			loop2	goto loop2

			; Skip every other instruction
			strand3	u1 = u1 + 7
					goto skip1
					u1 = u1 + 9
			skip1	u1 = u1 + 13
					goto skip2
					u1 = u1 + 17
			skip2	u1 = u1 + 19
					goto skip3
					u1 = u1 + 27
			skip3	u1 = u1 + 29
			loop4	goto loop4
			
		
			''', { 
				'u0' : None,
				't0u1' : 0, 
				't1u1' : 17, 
				't2u1' : 28,
				't2u2' : 0,
				't3u1' : 68
				},
				None, None, None)
	
	
	# TODO: add some tests that do control register transfer, 
	# and memory accesses before a rollback.  Make sure side
	# effects do not occur
	
	
	
	
	