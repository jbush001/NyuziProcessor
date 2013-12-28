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

from testgroup import *

# Place to write and read values.  This must be past the end of text
SCRATCHPAD_BASE = 512

class LoadStoreTests(TestGroup):
	def test_scalarLoad():
		return ({}, '''
			move s10, 15
			setcr s10, 30	; Start all threads
	
			lea s10, label1
			load_s8 s1, (s10)
			add_i s20, s1, 1			; test load RAW hazard.  Use add to ensure side effect occurs once.
			load_s8 s2, 1(s10)
			load_s8 s3, 2(s10)
			load_u8 s4, 2(s10)		; sign extend
			load_u8 s5, 3(s10)
			
			load_s16 s6, 4(s10)		; sign extend
			add_i s21, s6, 1		; test load RAW hazard
			
			load_u16 s7, 4(s10)
			load_s16 s8, 6(s10)
			load_32 s9, 8(s10)
			add_i s22, s9, 1			; test load RAW hazard
			add_i s10, s10, 4
			load_s8 s11, -4(s10)	; negative offset
			
			goto ___done
			
			label1:	.byte 0x5a, 0x69, 0xc3, 0xff
					.short 0xabcd, 0x1234	
					.long 0xdeadbeef
		''', {
			's1' : 0x5a, 
			's2' : 0x69, 
			's3' : 0xffffffc3, 
			's4' : 0xc3,
			's5' : 0xff, 
			's6' : 0xffffabcd, 
			's7' : 0xabcd, 
			's8' : 0x1234,
			's9' : 0xdeadbeef, 
			's10' : None, 
			's20' : 0x5a + 1, 
			's21' : 0xffffabcd + 1,
			's22' : 0xdeadbeef + 1, 
			's10' : None, 
			's11' : 0x5a}, None, None, None)
		
	def test_scalarStore():
		return ({
			's1' : 0x5a, 
			's2' : 0x69, 
			's3' : 0xc3, 
			's4' : 0xff, 
			's5' : 0xabcd, 
			's6' : 0x1234,
			's7' : 0xdeadbeef, 
			's10' : SCRATCHPAD_BASE}, '''
	
			store_8 s1, (s10)
			store_8 s2, 1(s10)
			store_8 s3, 2(s10)
			store_8 s4, 3(s10)
			store_16 s5, 4(s10)
			store_16 s6, 6(s10)
			store_32 s7, 8(s10)
		''', {}, SCRATCHPAD_BASE, [ 0x5a, 0x69, 0xc3, 0xff, 0xcd, 0xab, 0x34, 0x12, 0xef,
				0xbe, 0xad, 0xde ], None)
	
	#
	# Store word, read smaller than word to ensure proper ordering
	#
	def test_endian1():
		return ({'s1' : SCRATCHPAD_BASE, 's2' : 0x12345678},
			'''
				store_32 s2, (s1)

				load_u16 s4, (s1)
				load_u16 s5, 2(s1)
					
				load_u8 s6, (s1)
				load_u8 s7, 1(s1)
				load_u8 s8, 2(s1)
				load_u8 s9, 3(s1)
			''',
			{ 	't0s4' : 0x5678, 
				't0s5' : 0x1234, 
				't0s6' : 0x78,
				't0s7' : 0x56, 
				't0s8' : 0x34, 
				't0s9' : 0x12 }, None, None, None)

	#
	# Store smaller than word, read word to ensure proper ordering
	#
	def test_endian2():
		return ({'s1' : SCRATCHPAD_BASE, 
				's2' : 0x5678, 
				's3' : 0x1234, 
				's4' : 0xef,
				's5' : 0xbe, 
				's6' : 0xad, 
				's7' : 0xde},
			'''
				store_16 s2, (s1)
				store_16 s3, 2(s1)

				store_8 s4, 4(s1)
				store_8 s5, 5(s1)
				store_8 s6, 6(s1)
				store_8 s7, 7(s1)
				
				load_32 s8, (s1)
				load_32 s9, 4(s1)
			''',
			{ 't0s8' : 0x12345678, 't0s9' : 0xdeadbeef }, None, None, None)
	
	# Immediately access the destination register.  Since the load
	# has several cycles of latency, this ensures the scheduler is properly 
	# inserting bubbles.
	def test_blockLoad():
		data = [ random.randint(0, 0xff) for x in range(4 * 16 * 2) ]
		v1 = makeVectorFromMemory(data, 0, 4)
		v2 = makeVectorFromMemory(data, 64, 4)
		return ({ 's1' : 0xaaaa }, '''
			move s10, 15
			setcr s10, 30  ; Start all threads
			
			lea s10, label1
			load_v v1, (s10)
			add_i v4, v1, 1					; test load RAW hazard
			load_v_mask v6, s1, (s10)		; mask form
			load_v_invmask v7, s1, (s10)	; invert mask
			load_v v2, 64(s10)
			add_i v5, v2, 1					; test load RAW hazard
			load_v_mask v8, s1, 64(s10)		; mask form
			load_v_invmask v9, s1, 64(s10)	; invert mask
			goto ___done
			
			.align 64
			label1:	''' + makeAssemblyArray(data)
		, { 'v1' : v1,
			'v4' : [ x + 1 for x in v1 ],
			'v2' : v2,
			'v5' : [ x + 1 for x in v2 ],
			'v6' : [ value if index % 2 == 0 else 0 for index, value in enumerate(v1) ],
			'v7' : [ value if index % 2 == 1 else 0 for index, value in enumerate(v1) ],
			'v8' : [ value if index % 2 == 0 else 0 for index, value in enumerate(v2) ],
			'v9' : [ value if index % 2 == 1 else 0 for index, value in enumerate(v2) ],
			's10' : None}, None, None, None)
	
	def test_blockStore():
		cases = []
		for mask, invertMask in [(None, False), (0x5a5a, False), (0x5a5a, True)]:
			memory = [ 0 for x in range(4 * 16 * 4) ]	
			v1 = allocateUniqueScalarValues(16)
			v2 = allocateUniqueScalarValues(16)
			emulateVectorStore(SCRATCHPAD_BASE, memory, SCRATCHPAD_BASE, v1, 4, mask, invertMask)
			emulateVectorStore(SCRATCHPAD_BASE, memory, SCRATCHPAD_BASE + 64, v2, 4, mask, invertMask)
		
			store1 = 'store_v'
			store2 = 'store_v'
			if mask != None:
				if invertMask:
					store1 += '_invmask'
					store2 += '_invmask'
				else:
					store1 += '_mask' 
					store2 += '_mask' 

				store1 += ' v1, s1, (s10)\n'
				store2 += ' v2, s1, 64(s10)\n'
			else:
				store1 += ' v1, (s10)\n'
				store2 += ' v2, 64(s10)\n'
		
			cases += [ ({ 's10' : SCRATCHPAD_BASE, 'v1' : v1, 'v2' : v2, 's1' : mask if mask != None else 0 }, 
				store1 + store2, { 's10' : None }, SCRATCHPAD_BASE, memory, None) ]

		return cases

	def test_stridedLoad():
		data = [ random.randint(0, 0xff) for x in range(12 * 16) ]
		v1 = makeVectorFromMemory(data, 0, 12)
		return ({ 's1' : 0xaaaa }, '''
			move s10, 15
			setcr s10, 30  ; Start all threads

			lea s10, label1
			load_strd v1, 12(s10)
			add_i v2, v1, 1		; test load RAW hazard
			load_strd_mask v3, s1, 12(s10)
			load_strd_invmask v4, s1, 12(s10)
			goto ___done

			label1:	''' + makeAssemblyArray(data),
			{ 'v1' : v1,
			'v2' : [ x + 1 for x in v1 ],
			'v3' : [ value if index % 2 == 0 else 0 for index, value in enumerate(v1) ],
			'v4' : [ value if index % 2 == 1 else 0 for index, value in enumerate(v1) ],
			's10' : None}, None, None, None)
	
	def test_stridedStore():
		cases = []
		for mask, invertMask in [(None, False), (0x5a5a, False), (0x5a5a, True)]:
			memory = [ 0 for x in range(4 * 16 * 4) ]	
			v1 = allocateUniqueScalarValues(16)
			v2 = allocateUniqueScalarValues(16)
			emulateVectorStore(SCRATCHPAD_BASE, memory, SCRATCHPAD_BASE, v1, 12, mask, invertMask)
			emulateVectorStore(SCRATCHPAD_BASE, memory, SCRATCHPAD_BASE + 4, v2, 12, mask, invertMask)

			storeInst1 = 'store_strd'
			storeInst2 = 'store_strd'
			if mask != None:
				if invertMask:
					storeInst1 += '_invmask'
					storeInst2 += '_invmask'
				else:
					storeInst1 += '_mask' 
					storeInst2 += '_mask' 

				storeInst1 += ' v1, s1, 12(s10)\n'
				storeInst2 += ' v2, s1, 12(s10)\n'
			else:
				storeInst1 += ' v1, 12(s10)\n'
				storeInst2 += ' v2, 12(s10)\n'

			code = storeInst1 + 'add_i s10, s10, 4\n' + storeInst2
			cases += [({ 's10' : SCRATCHPAD_BASE, 'v1' : v1, 'v2' : v2, 's1' : mask if mask != None else 0 }, 
				code, { 's10' : None }, SCRATCHPAD_BASE, memory, None) ]
				
		return cases
	
	
	#
	# This also validates that the assembler properly fixes up label references
	# as data
	#
	def test_gatherLoad():
		labels = ['off' + str(x) for x in range(16)]
		values = allocateUniqueScalarValues(16)
		shuffledIndices = shuffleIndices()
	
		code = '''
				move s10, 15
				setcr s10, 30  ; Start all threads

				load_v v0, ptrs
				load_gath v1, (v0)
				add_i v2, v1, 1			; test load RAW hazard
				load_gath_mask v3, s1, (v0)
				load_gath_invmask v4, s1, (v0)
				goto ___done

				.align 64
			ptrs: '''
	
		for x in shuffledIndices:
			code += '\t\t\t\t.long ' + labels[x] + '\n'
			
		for x in range(16):
			code += labels[x] + ':\t\t\t\t.long ' + hex(values[x]) + '\n'
	
		expectedArray = [ values[shuffledIndices[x]] for x in range(16) ]
	
		return ({ 's1' : 0xaaaa }, code, { 
			'v0' : None, 
			'v1' : expectedArray, 
			'v2' : [ x + 1 for x in expectedArray ],
			'v3' : [ value if index % 2 == 0 else 0 for index, value in enumerate(expectedArray) ],
			'v4' : [ value if index % 2 == 1 else 0 for index, value in enumerate(expectedArray) ],
			's10' : None
			}, None, None, None)
	
	def test_scatterStore():
		cases = []
		for offset, mask, invertMask in [(0, None, None), 
			(8, None, None), (4, 0xa695, False), (4, 0xa695, True)]:
			memory = [ 0 for x in range(10 * 16) ]	
			values = allocateUniqueScalarValues(16)
			ptrs = [ SCRATCHPAD_BASE + x * 8 for x in shuffleIndices() ]

			code = 'store_scat'
			if mask != None:
				if invertMask:
					code += '_invmask'
				else:
					code += '_mask' 

				code += ' v2, s0, '
			else:
				code += ' v2, '
		
			if offset != 0:
				code += str(offset)
			
			code += '(v1)\n'

			emulateScatterStore(SCRATCHPAD_BASE, memory, ptrs, values, 
				offset if offset != None else 0, mask, invertMask)
		
			cases += [({ 'v1' : ptrs, 'v2' : values, 's0' : mask if mask != None else 0}, 
				code, 
				{ 't0s10' : None }, SCRATCHPAD_BASE, memory, None)]

		return cases

	# Verify that all cache alignments work by doing a copy byte-by-byte.
	# The cache line size is 64 bytes, so we will try 128. 
	def test_bytewiseCopy():
		destAddr = 1024
		data = [ random.randint(0, 0xff) for x in range(128) ]

		return ({
			's0' : destAddr,
			's2' : 128 }, '''
						; s0 is dest
						; s1 is src
						; s2 is length
						lea s1, sourceData
			loop:		load_u8 s3, (s1)
						store_8 s3, (s0)
						add_i s0, s0, 1
						add_i s1, s1, 1
						sub_i s2, s2, 1
						btrue s2, loop
						goto ___done
			sourceData: '''+ makeAssemblyArray(data),
				None, destAddr, data, 2048)

	# Load 4 separate cache lines.  Verify requests are queued properly.
	def test_divergentLoad():
		data = [ random.randint(0, 0xff) for x in range(256) ]

		return ({}, '''
						move s0, 15
						setcr s0, 30  ; Start all threads
		
						getcr s0, 0		; Get current thread
						shl s0, s0, 6	; Multiply by 64
						lea s1, sourceData
						add_i s0, s0, s1
						load_v v0, (s0)
						goto ___done
						.align 64
			sourceData: '''+ makeAssemblyArray(data),
			{ 's0' : None, 
			's1' : None,
			't0v0' : makeVectorFromMemory(data, 0, 4), 
			't1v0' : makeVectorFromMemory(data, 64, 4), 
			't2v0' : makeVectorFromMemory(data, 128, 4), 
			't3v0' : makeVectorFromMemory(data, 192, 4) }, 
			None, None, None)

	def test_multiStrandStore():
		data = [ random.randint(0, 0xff) for x in range(256) ]

		return ({
			't0v0' : makeVectorFromMemory(data, 0, 4), 
			't1v0' : makeVectorFromMemory(data, 64, 4), 
			't2v0' : makeVectorFromMemory(data, 128, 4), 
			't3v0' : makeVectorFromMemory(data, 192, 4)
			}, '''
						move s0, 15
						setcr s0, 30  ; Start all threads
		
						getcr s0, 0		; Get current thread
						shl s0, s0, 6	; Multiply by 64
						add_i s0, s0, ''' + str(SCRATCHPAD_BASE) + '''
						store_v v0, (s0)''',
			{ 's0' : None, 's1' : None }, 
			SCRATCHPAD_BASE, data, 256)		
	
	# Was causing a hang previously.  This test just verifies that the
	# code runs to completion.
	def test_storeStoreCollision():
		return ({ 's0' : 7 }, '''
					store_32 s0, value
					store_32 s0, value
					load_32 s1, value
					add_i s1, s1, 1
					store_32 s1, value
					goto ___done
			value:	.long 0
		
		''', { 't0s1' : 8 }, None, None, None)
		
	def test_loadSynchronized():
		return ({}, '''
			lea s0, label1
			load_sync s1, (s0)	; Cache miss
			load_sync s2, (s0)	; Cache hit, but reload
			goto ___done
			label1:	.long 0x1abcdef1
		
		''', { 't0s0' : None, 't0s1' : 0x1abcdef1, 't0s2' : 0x1abcdef1 }, 
		None, None, None)
	
	# Success, no conflict
	def test_loadStoreSynchronized0():
		return ({ 's0' : SCRATCHPAD_BASE, 's1' : 0xdeadbeef }, '''
			load_sync s2, (s0)
			store_sync s1, (s0)
		''', { 't0s1' : 1, 't0s2' : 0 }, 
		SCRATCHPAD_BASE, [ 0xef, 0xbe, 0xad, 0xde ], None)
	
	# Conflict, no store
	def test_loadStoreSynchronized1():
		return ({ 's0' : SCRATCHPAD_BASE, 's1' : 0xdeadbeef, 's3' : 0x12344321 }, '''
			load_sync s2, (s0)
			store_32 s3, (s0)
			store_sync s1, (s0)
			load_32 s4, (s0)  ; Make sure L1 cache was not updated (regression test)
		''', { 't0s1' : 0, 't0s2' : 0, 't0s4' : 0x12344321 }, 
		SCRATCHPAD_BASE, [ 0x21, 0x43, 0x34, 0x12 ], None)

	# A successful load before the load_sync.  There was previously a bug where the
	# original (normal) load response would be interpreted as a load_sync ack, causing
	# a failure
	def test_loadStoreSynchronized2():
		return ({ 's0' : SCRATCHPAD_BASE, 's1' : 0xdeadbeef }, '''
			load_32 s2, (s0)
			load_sync s2, (s0)
			store_sync s1, (s0)
		''', { 't0s1' : 1, 't0s2' : 0 }, 
		SCRATCHPAD_BASE, [ 0xef, 0xbe, 0xad, 0xde ], None)

	# Hit various cases, including case where the response for the first store comes in the same
	# cycle the second is requested. In that case, the store should be enqueued.  
	def test_stbufCollisionSync():
		tests = []
		for delay in range(2, 20):
			src = '''
				.align 64
				store_32 s1, (s0)
		wait:	sub_i s2, s2, 1
				btrue s2, wait
			'''
			
			if delay & 1:
				src += '\nnop\n'

			src += '''
				store_sync s1, (s0)
			'''
			
			tests += [ ({ 's0' : SCRATCHPAD_BASE, 's2' : delay / 2 }, src, 
				{ 's1' : 0, 's2' : None }, None, None, None) ]

		return tests

	# Case where the response for the first store comes in the same cycle the second is
	# requested. In this case, the store should be enqueued.
	# Delay is as described above.
	def test_stbufCollisionNormal():
		tests = []
		for delay in range(2, 20):
			src = '''
				.align 64
				store_32 s1, (s0)
		wait:	sub_i s2, s2, 1
				btrue s2, wait
			'''
			
			if delay & 1:
				src += '\nnop\n'

			src += '''
				store_32 s3, (s0)
			'''
			
			tests += [ ({ 's0' : SCRATCHPAD_BASE, 's2' : delay / 2, 's3' : 0xdeadbeef }, src, 
				{ 's1' : 0, 's2' : None }, SCRATCHPAD_BASE, [ 0xef, 0xbe, 0xad, 0xde ], None) ]
		
		return tests
		
	def test_atomicAdd():
		return ({},
			'''
							move s0, 15
							setcr s0, 30  ; Start all threads

							move s0, ''' + str(SCRATCHPAD_BASE) + '''
				retry:		load_sync s1, (s0)
							add_i s1, s1, 1
							store_sync s1, (s0)
							bfalse s1, retry
							
				; The wait loop allows the test to terminate cleanly, but
				; is also important to ensure the L1 cache has been updated
				; properly.
				wait:		load_32 s2, (s0)
							seteq_i s2, s2, 3
							bfalse s2, wait
							goto ___done
			''', { 's0' : None, 's1' : 1, 's2' : None }, SCRATCHPAD_BASE, [ 4, 0, 0, 0 ], None)

	def test_spinlock():
		return ({},
			'''
						move s0, 15
						setcr s0, 30  ; Start all threads

						lea s0, lock
				loop0:	load_sync s1, (s0)
						btrue s1, loop0			; Lock is already held, wait
						move s1, 1
						store_sync s1, (s0)
						bfalse s1, loop0
						
						load_32 s1, protected_val
						
						nop						; increase contention 
						nop
						nop
						nop
						nop
						nop

						add_i s1, s1, 1
						store_32 s1, protected_val

						move s1, 0
						store_32 s1, (s0)	; release lock
						
				loop3:	load_32 s2, protected_val
						seteq_i s2, s2, 23
						bfalse s2, loop3
				
						; XXX should use .data directive, but that crashes.  Probably lld bug.
						.align 64
			lock:		.long 0
			protected_val: .long 19
			''', None, None, None, None)

	# Also verifies control register access
	def test_unalignedMemoryAccessFault():
		return ({ 's0' : 1},
			'''
							lea s3, fault_handler
							setcr s3, 1			# Set up fault handler
							
							load_32 s1, (s0)
			fault_pc:		move s4, 5 # Should not hit this.
							goto ___done
			
			fault_handler:	getcr s2, 2
							lea s3, fault_pc	
							sub_i s4, s2, s3	; Ensure fault PC is set correctly
			
			''', { 't0s2' : None, 't0s3' : None , 't0s4' : 0 }, None, None, None)
			# XXX can't verify fault address

	# Non-cacheable loads/stores.  These use a dummy device that is hard
	# coded into simulator_top
	def test_deviceIoMemoryAccess():
		return ({ 's0' : 0xdeadbeef, 's1' : 0xffff0000 },
			'''
				load_32 s2, (s1)
				store_32 s0, (s1)
				load_32 s3, (s1)
				load_32 s4, 4(s1)
			''',
			{
				't0s2' : 0,
				't0s3' : 0xEF56DF77,
				't0s4' : 0xffffffff
			}, None, None, None)								
				