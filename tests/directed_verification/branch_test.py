# 
# Copyright 2011-2012 Jeff Bush
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#     http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# 

from testgroup import TestGroup

class BranchTests(TestGroup):
	def test_goto():
		return ({ 's1' : 1 }, '''		
					goto label1
					move s0, 5
					goto ___done
		label1:		move s0, 12
					goto ___done
		''', { 't0s0' : 12 }, None, None, None)

	
	def test_pcDest():
		return ({}, '''		
						lea s0, label
						move pc, s0
						goto ___done
						add_i s1, s1, 13
						goto ___done
			label:		add_i s1, s1, 17
						goto ___done
						add_i s1, s1, 57
						goto ___done
			''',
			{ 't0s0' : None, 't0s1' : 17 }, None, None, None)

	def test_bzeroTaken():
		return ({ 's1' : 0 }, '''		
						bfalse s1, label1
						add_i s0, s0, 5
						goto ___done
			label1:		add_i s0, s0, 12
						goto ___done
			''', { 't0s0' : 12 }, None, None, None)
		
	def test_bzeroNotTaken():
		return ({ 's1' : 1 }, '''		
						bfalse s1, label1
						add_i s0, s0, 5
						goto ___done
			label1:		add_i s0, s0, 12
						goto ___done
			''', { 't0s0' : 5 }, None, None, None)
		
	def test_bnzeroNotTaken():
		return ({ 's1' : 0 }, '''		
						btrue s1, label1
						add_i s0, s0, 5
						goto ___done
			label1:		add_i s0, s0, 12
						goto ___done
			''', { 't0s0' : 5 }, None, None, None)

	def test_bnzeroTaken():		
		return ({ 's1' : 1 }, '''			
						btrue s1, label1
						add_i s0, s0, 5
						goto ___done
			label1:		add_i s0, s0, 12
						goto ___done
			''', { 't0s0' : 12 }, None, None, None)

	def test_ballNotTakenSomeBits():
		return ({ 's1' : 1 }, '''		
						ball s1, label1
						add_i s0, s0, 5
						goto ___done		
			label1:		add_i s0, s0, 12
						goto ___done		
			''', { 't0s0' : 5 }, None, None, None)

	def test_ballNotTakenNoBits():
		return ({ 's1' : 0 }, '''		
						ball s1, label1
						add_i s0, s0, 5
						goto ___done
			label1:		add_i s0, s0, 12
						goto ___done
			''', { 't0s0' : 5 }, None, None, None)

	def test_ballTaken():
		return ({ 's1' : 0xffff }, '''		
						ball s1, label1
						add_i s0, s0, 5
						goto ___done
			label1:		add_i s0, s0, 12
						goto ___done
			''', { 't0s0' : 12 }, None, None, None)
	
	def test_ballTakenSomeBits():
		return ({ 's1' : 0x20ffff }, '''		
						ball s1, label1
						add_i s0, s0, 5
						goto ___done
			label1:		add_i s0, s0, 12
						goto ___done
			''', { 't0s0' : 12 }, None, None, None)
			
	def test_bnallTakenSomeBits():
		return ({ 's1' : 1 }, '''		
						bnall s1, label1
						add_i s0, s0, 5
						goto ___done		
			label1:		add_i s0, s0, 12
						goto ___done		
			''', { 't0s0' : 12 }, None, None, None)

	def test_bnallTakenNoBits():
		return ({ 's1' : 0 }, '''		
						bnall s1, label1
						add_i s0, s0, 5
						goto ___done
			label1:		add_i s0, s0, 12
						goto ___done
			''', { 't0s0' : 12 }, None, None, None)
	
	def test_bnallNotTaken():
		return ({ 's1' : 0xffff }, '''		
						bnall s1, label1
						add_i s0, s0, 5
						goto ___done
			label1:		add_i s0, s0, 12
						goto ___done
			''', { 't0s0' : 5 }, None, None, None)			

	def test_bnallNotTakenExtraBits():
		return ({ 's1' : 0x30ffff }, '''		
						bnall s1, label1
						add_i s0, s0, 5
						goto ___done
			label1:		add_i s0, s0, 12
						goto ___done
			''', { 't0s0' : 5 }, None, None, None)			

	# Verify that all queued pipeline instructions are invalidated after a branch
	def test_rollback():
		return ({},'''
				goto label1
				add_i s0, s0, 234
				add_i s1, s1, 456
				add_i s2, s2, 37
				add_i s3, s3, 114
		label3:	add_i s4, s4, 9
				goto ___done
				add_i s5, s5, 12
		label1:	goto label3
				add_i s4, s4, 99
		''', { 't0s4' : 9 }, None, None, None)
		
	def test_callOffset():
		return ({}, '''		
						call label1
			ret_addr:	add_i s0, s0, 7
						goto ___done
						nop
						nop
						nop
						nop
						nop
						nop
						nop
			label1:		add_i s0, s0, 12
						lea s5, ret_addr
						sub_i s4, link, s5	# This should be zero
						goto ___done
			''', { 't0s0' : 12, 't0s5' : None, 't0s30' : None }, None, None, None)
		
	def test_callRegister():
		return ({}, '''
						lea s1, label1
						call s1
						add_i s0, s0, 17
						goto ___done
						nop
						nop
						nop
						nop
						nop
						nop
						nop
				label1:	add_i s0, s0, 29
						goto ___done
			''', { 't0s0' : 29, 't0s30' : None, 't0s1' : None}, None, None, None)
			# XXX cannot predict value of s30
		
	# Note that this will be a cache miss the first time, which 
	# validates that the thread is rolled back and restarted
	# correctly (rather than just branching to address 0)
	# We have each strand load a different address
	def test_pcload():
		return ({}, '''
					move s0, 15
					setcr s0, 30		; Start all strands
		
					getcr s0, 0		; get strand ID
					shl s0, s0, 2	; Multiply by 4 to get offset
					lea s1, pc_ptr
					add_i s1, s1, s0	; index into table
					load_32 pc, (s1)
					add_i s1, s1, 12	; should never hit this
					goto ___done
			pc_ptr:	.long target0, target1, target2, target3

			target0: move s2, 17
					goto ___done

			target1: move s2, 37
					goto ___done

			target2: move s2, 41
					goto ___done

			target3: move s2, 47
					goto ___done

					move s2, 29 	; Should never hit this
					
			''', { 
				's0' : None, 
				's1' : None,
				't0s2' : 17,
				't1s2' : 37,
				't2s2' : 41,
				't3s2' : 47,
			}, None, None, None)
	

	# Have a bunch of divergent branches (for each strand).  Also test
	# arithmetic with a PC destination.
	def test_strandBranches():
		return ({}, '''
					move s0, 15
					setcr s0, 30		; Start all threads


					getcr s0, 0		; get the strand id
					shl s0, s0, 2	; multiply by 4
					add_i pc, pc, s0	; offset into branch table
					goto strand0
					goto strand1
					goto strand2
					goto strand3

			; Tight loop. Generates a bunch of rollbacks.
			; This kills everything when it is done
			strand0: move s1, 50
			loop5:	sub_i s1, s1, 1
					btrue s1, loop5
					goto ___done

			; Perform a bunch of operations without branching.
			; Ensure rollback of other strands doesn't affect this.
			strand1: add_i s1, s1, 1
					add_i s1, s1, 1
					add_i s1, s1, 1
					add_i s1, s1, 1
					add_i s1, s1, 1
					add_i s1, s1, 1
					add_i s1, s1, 1
					add_i s1, s1, 1
					add_i s1, s1, 1
					add_i s1, s1, 1
					add_i s1, s1, 1
					add_i s1, s1, 1
					add_i s1, s1, 1
					add_i s1, s1, 1
					add_i s1, s1, 1
					add_i s1, s1, 1
					add_i s1, s1, 1
			loop0:	goto loop0
			
			; This strand iterates runs a loop and generates periodic rollbacks
			strand2: move s2, 4
			loop1:	add_i s1, s1, 7
					sub_i s2, s2, 1
					btrue s2, loop1
			loop2:	goto loop2

			; Skip every other instruction
			strand3: add_i s1, s1, 7
					goto skip1
					add_i s1, s1, 9
			skip1:	add_i s1, s1, 13
					goto skip2
					add_i s1, s1, 17
			skip2:	add_i s1, s1, 19
					goto skip3
					add_i s1, s1, 27
			skip3:	add_i s1, s1, 29
			loop4:	goto loop4
			
		
			''', { 
				's0' : None,
				't0s1' : 0, 
				't1s1' : 17, 
				't2s1' : 28,
				't2s2' : 0,
				't3s1' : 68
				},
				None, None, None)
	
	
	# TODO: add some tests that do control register transfer, 
	# and memory accesses before a rollback.  Make sure side
	# effects do not occur
	
	
	
	
	