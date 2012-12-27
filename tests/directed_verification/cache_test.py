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

class CacheTests(TestGroup):
	# Simple test that does a store followed by a load.  Will cause a cache
	# miss and write through on the first instruction and a cache hit on 
	# the second.
	def test_cacheStoreLoad():
		return ({ 'u0' : 0x12345678}, '''
					mem_l[dat1] = u0
					u1 = mem_l[dat1]
					goto ___done
			dat1:	.word 0	
		''', { 't0u1' : 0x12345678 }, None, None, None)

	# Cache line is resident.  The second load will need to bypass a result
	# from the store buffer.
	def test_storeRAW():
		return ({ 'u0' : 0x12345678}, '''
					u1 = mem_l[dat1]		# load line into cache...
					mem_l[dat1] = u0
					u1 = mem_l[dat1]
					goto ___done
			dat1:	.word 0	
		''', { 't0u1' : 0x12345678 }, None, None, None)


	def test_stbar():
		return ({ 'u1' : 0x12345678 }, '''
					mem_l[dat1] = u1
					stbar
					goto ___done
			dat1:	.word 0xabababab
		''', { }, None, None, None)

	def test_dinvalidate():
		return ({ 'u0' : 128, 'u1' : 0xdeadbeef },
			'''
				u2 = mem_l[u0]		# Make line resident
				mem_l[u0] = u1
				dinvalidate(u0)
				stbar
				u3 = mem_l[u0]
			''', { 't0u3' : 0 }, None, None, None)

	# Validate this with some self-modifying code.  This depends on the instruction
	# format.
	def test_iinvalidate():
		return ({ }, '''
			; This first test modifies an instruction, converting to NOP .  It then
			; runs the code without using the icache invalidate instruction.
			; The *old* version of the instruction will run because it is
			; still in the instruction cache.
						u1 = &modinst1
						mem_l[u1] = u2		; convert to NOP
						nop		; Ensure we flush instruction FIFO 
						nop
						nop
			modinst1: 	u10 = 7		

			; Same sequence as before, except this time we will use iinvalidate
			; instruction. This will pick up the changed instruction.
			; Note that we need to make sure the instruction is on the same
			; cache line as the code above it so we can be sure it is resident
			; in the instruction cache (making it less than 16 instructions ensures
			; that). Also, make sure to use a cache set past the zeroth
			; so we insure address information is sent properly to the cache.
						.align 64
						u1 = &modinst2
						mem_l[u1] = u2
						iinvalidate(u1)
						stbar
						nop		; Need a cycle to ensure old instr is not in instruction FIFO
			modinst2: 	u11 = 9
		''', { 
			't0u1' : None, 
			't0u2' : None, 
			't0u10' : 7,
			't0u11' : 0 
			}, None, None, None)
		

	# It's difficult to fully verify dflush in this test harness.  We can't ensure
	# the cache line was pushed out when the instruction was executed or that
	# it wasn't pushed out a second time when the cache line was evicted.
	def test_dflush():
		return ({ 'u0' : 256,
			'u20' : 0x10000,
			'u1' : 0x01010101 }, '''
					u8 = u0
					dflush(u0)			; flush a non-resident line
					mem_l[u0] = u1		; Dirty a line
					dflush(u0)			; flush it

					; push the line out of the cache to make sure it isn't written
					; back.
					u0 = u0 + u20
					u2 = mem_l[u0]
					u0 = u0 + u20
					u2 = mem_l[u0]
					u0 = u0 + u20
					u2 = mem_l[u0]
					u0 = u0 + u20
					u2 = mem_l[u0]

					u3 = mem_l[u8]	; Make sure value is correct
					dflush(u8)		; flush a resident, but non-dirty line
					nop
					nop
					nop
					nop
					nop
					nop
					nop
					nop
					nop
					nop
					nop
					nop
					nop
					nop
		''', { 
		'u2' : None,
		'u8' : None,
		't0u3' : 0x01010101,
		'u0' : None
		}, 256, [0x01, 0x01, 0x01, 0x01], None)	

	def test_dflushMiss():
		return ({}, '''
			dflush(s0)
			dflush(s0 + 64)
		''', {}, None, None, None)

	# These addresses all target the same set.  This will force a writeback
	# to L2, followed by a re-load
	def test_cacheAlias():
		return ({ 'u0' : 256,
			'u20' : 2048,
			'u1' : 0x01010101, 
			'u2' : 0x02020202,
			'u3' : 0x03030303,
			'u4' : 0x04040404,
			'u5' : 0x05050505,
			'u6' : 0x06060606,
			'u7' : 0x07070707 }, '''
					u8 = u0
					mem_l[u0] = u1
					u0 = u0 + u20
					mem_l[u0] = u2
					u0 = u0 + u20
					mem_l[u0] = u3
					u0 = u0 + u20
					mem_l[u0] = u4
					u0 = u0 + u20
					mem_l[u0] = u5
					u0 = u0 + u20
					mem_l[u0] = u6
					u0 = u0 + u20
					mem_l[u0] = u7
					
					u9 = mem_l[u8]
					u8 = u8 + u20
					u10 = mem_l[u8]
					u8 = u8 + u20
					u11 = mem_l[u8]
					u8 = u8 + u20
					u12 = mem_l[u8]
					u8 = u8 + u20
					u13 = mem_l[u8]
					u8 = u8 + u20
					u14 = mem_l[u8]
					u8 = u8 + u20
					u15 = mem_l[u8]
		''', { 
		't0u0' : None,
		't0u8' : None,
		't0u9' : 0x01010101, 
		't0u10' : 0x02020202, 
		't0u11' : 0x03030303, 
		't0u12' : 0x04040404, 
		't0u13' : 0x05050505, 
		't0u14' : 0x06060606, 
		't0u15' : 0x07070707
		}, None, None, None)
		
	def test_icacheMiss():
		return ({}, '''
					goto label1

					.align 2048
		label5:		s0 = s0 + 5
					s1 = s1 + s0
					goto label6

					.align 2048
		label4:		s0 = s0 + 4
					s1 = s1 + s0
					goto label5

					.align 2048
		label3:		s0 = s0 + 3
					s1 = s1 + s0
					goto label4
				
					.align 2048
		label2:		s0 = s0 + 2
					s1 = s1 + s0
					goto label3

					.align 2048
		label6:		s0 = s0 + 6
					s1 = s1 + s0
					goto ___done

		label1:		s0 = s0 + 1
					s1 = s1 + s0
					goto label2
					
		''', { 't0u0' : 21, 't0u1' : 56 }, None, None, None)
