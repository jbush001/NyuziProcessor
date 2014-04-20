# 
# Copyright (C) 2011-2014 Jeff Bush
# 
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Library General Public
# License as published by the Free Software Foundation; either
# version 2 of the License, or (at your option) any later version.
# 
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Library General Public License for more details.
# 
# You should have received a copy of the GNU Library General Public
# License along with this library; if not, write to the
# Free Software Foundation, Inc., 51 Franklin St, Fifth Floor,
# Boston, MA  02110-1301, USA.
# 


from testgroup import TestGroup

class CacheTests(TestGroup):
	# Simple test that does a store followed by a load.  Will cause a cache
	# miss and write through on the first instruction and a cache hit on 
	# the second.
	def test_cacheStoreLoad():
		return ({ 's0' : 0x12345678}, '''
					store_32 s0, dat1
					load_32 s1, dat1
					goto ___done
			dat1:	.long 0	
		''', { 't0s1' : 0x12345678 }, None, None, None)

	# Cache line is resident.  The second load will need to bypass a result
	# from the store buffer.
	def test_storeRAW():
		return ({ 's0' : 0x12345678}, '''
					load_32 s1, dat1	# load line into cache...
					store_32 s0, dat1
					load_32 s1, dat1
					goto ___done
			dat1:	.long 0	
		''', { 't0s1' : 0x12345678 }, None, None, None)


	def test_membar():
		return ({ 's1' : 0x12345678 }, '''
					store_32 s1, dat1
					membar
					goto ___done
			dat1:	.long 0xabababab		; XXX should be in data segment
		''', { }, None, None, None)

	def test_dinvalidate():
		return ({ 's0' : 512, 's1' : 0xdeadbeef },
			'''
				load_32 s2, (s0)		# Make line resident
				store_32 s1, (s0)
				dinvalidate s0
				membar
				load_32 s3, (s0)
			''', { 't0s3' : 0 }, None, None, None)

	# Validate this with some self-modifying code.  This depends on the instruction
	# format.
	def test_iinvalidate1():
		return ({ }, '''
			; This first test modifies an instruction, converting to NOP .  It then
			; runs the code without using the icache invalidate instruction.
			; The *old* version of the instruction will run because it is
			; still in the instruction cache.
						lea s1, modinst1
						store_32 s2, (s1)		; convert to NOP
						nop		; Ensure we flush instruction FIFO 
						nop
						nop
						nop
						nop
			modinst1: 	move s10, 7		

			; Same sequence as before, except this time we will use iinvalidate
			; instruction. This will pick up the changed instruction.
			; Note that we need to make sure the instruction is on the same
			; cache line as the code above it so we can be sure it is resident
			; in the instruction cache (making it less than 16 instructions ensures
			; that). Also, make sure to use a cache set past the zeroth
			; so we insure address information is sent properly to the cache.
						.align 64
						lea s1, modinst2
						store_32 s2, (s1)
						iinvalidate s1
						membar
						nop
						nop
						nop		; Need a cycle to ensure old instr is not in instruction FIFO
			modinst2: 	move s11, 9
		''', { 
			't0s1' : None, 
			't0s2' : None, 
			't0s10' : 7,
			't0s11' : 0 
			}, None, None, None)
		
	
	# invalidate a non-resident line.  Regression test: there was a bug previously
	# where this would hang.
	def test_iinvalidate2():
		return ({ 's0' : 0x8000 }, '''
			iinvalidate s0
			membar
		''', {}, None, None, None)		

	# It's difficult to fully verify dflush in this test harness.  We can't ensure
	# the cache line was pushed out when the instruction was executed or that
	# it wasn't pushed out a second time when the cache line was evicted.
	def test_dflush():
		return ({ 's0' : 256,
			's20' : 0x10000,
			's1' : 0x01010101 }, '''
					move s8, s0
					dflush s0			; flush a non-resident line
					store_32 s1, (s0)		; Dirty a line
					;dflush s0			; flush it

					; Write to aliases within the same set, which should cause
					; the line to be evicted (however, it should be clean at that
					; point, so it won't be written back.
					add_i s0, s0, s20
					load_32 s2, (s0)
					add_i s0, s0, s20
					load_32 s2, (s0)
					add_i s0, s0, s20
					load_32 s2, (s0)
					add_i s0, s0, s20
					load_32 s2, (s0)

					load_32 s3, (s8)	; Make sure value is correct
					dflush s8		; flush a resident, but non-dirty line
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
		's2' : None,
		's8' : None,
		't0s3' : 0x01010101,
		's0' : None
		}, 256, [0x01, 0x01, 0x01, 0x01], None)	

	def test_dflushMiss():
		return ({}, '''
			dflush s0
			add_i s0, s0, 64
			dflush s0
		''', { 's0' : None}, None, None, None)

	# These addresses all target the same set.  This will force a writeback
	# to L2, followed by a re-load
	def test_cacheAlias():
		return ({ 's0' : 256,
			's20' : 2048,
			's1' : 0x01010101, 
			's2' : 0x02020202,
			's3' : 0x03030303,
			's4' : 0x04040404,
			's5' : 0x05050505,
			's6' : 0x06060606,
			's7' : 0x07070707 }, '''
					move s8, s0
					store_32 s1, (s0)
					add_i s0, s0, s20
					store_32 s2, (s0)
					add_i s0, s0, s20
					store_32 s3, (s0)
					add_i s0, s0, s20
					store_32 s4, (s0)
					add_i s0, s0, s20
					store_32 s5, (s0)
					add_i s0, s0, s20
					store_32 s6, (s0)
					add_i s0, s0, s20
					store_32 s7, (s0)
					
					load_32 s9, (s8)
					add_i s8, s8, s20
					load_32 s10, (s8)
					add_i s8, s8, s20
					load_32 s11, (s8)
					add_i s8, s8, s20
					load_32 s12, (s8)
					add_i s8, s8, s20
					load_32 s13, (s8)
					add_i s8, s8, s20
					load_32 s14, (s8)
					add_i s8, s8, s20
					load_32 s15, (s8)
		''', { 
		't0s0' : None,
		't0s8' : None,
		't0s9' : 0x01010101, 
		't0s10' : 0x02020202, 
		't0s11' : 0x03030303, 
		't0s12' : 0x04040404, 
		't0s13' : 0x05050505, 
		't0s14' : 0x06060606, 
		't0s15' : 0x07070707
		}, None, None, None)
		
	def test_icacheMiss():
		return ({}, '''
					goto label1

					.align 64
		label5:		add_i s0, s0, 5
					add_i s1, s1, s0
					goto label6

					.align 64
		label4:		add_i s0, s0, 4
					add_i s1, s1, s0
					goto label5

					.align 64
		label3:		add_i s0, s0, 3
					add_i s1, s1, s0
					goto label4
				
					.align 64
		label2:		add_i s0, s0, 2
					add_i s1, s1, s0
					goto label3

					.align 64
		label6:		add_i s0, s0, 6
					add_i s1, s1, s0
					goto ___done

		label1:		add_i s0, s0, 1
					add_i s1, s1, s0
					goto label2
					
		''', { 't0s0' : 21, 't0s1' : 56 }, None, None, None)
