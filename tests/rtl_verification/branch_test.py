from testgroup import TestGroup

class BranchTests(TestGroup):
	def test_goto():
		return ({ 'u1' : 1 }, '''		
					goto label1
					u0 = 5
					goto ___done
		label1 		u0 = 12
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

	# Verify that all queued pipeline instructions are invalidated after a branch
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
	# We have each strand load a different address
	def test_pcload():
		return ({}, '''
					u0 = 15
					cr30 = u0		; Start all strands
		
					u0 = cr0		; get strand ID
					u0 = u0 << 2	; Multiply by 4 to get offset
					u1 = &pc_ptr
					u1 = u1 + u0	; index into table
					pc = mem_l[u1]
					u1 = u1 + 12	; should never hit this
					goto ___done
					pc_ptr	.word target0, target1, target2, target3

			target0	u2 = 17
					goto ___done

			target1	u2 = 37
					goto ___done

			target2	u2 = 41
					goto ___done

			target3	u2 = 47
					goto ___done

					u2 = 29 	; Should never hit this
					
			''', { 
				'u0' : None, 
				'u1' : None,
				't0u2' : 17,
				't1u2' : 37,
				't2u2' : 41,
				't3u2' : 47,
			}, None, None, None)
	

	# Have a bunch of divergent branches (for each strand).  Also test
	# arithmetic with a PC destination.
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
	
	
	
	
	