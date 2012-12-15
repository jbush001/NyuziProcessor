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

class LoadStoreTests(TestGroup):
	def test_scalarLoad():
		return ({}, '''
			i10 = 15
			cr30 = i10		; Enable all threads
	
			i10 = &label1
			i1 = mem_b[i10]
			i20 = i1 + 1			; test load RAW hazard.  Use add to ensure side effect occurs once.
			i2 = mem_b[i10 + 1]
			i3 = mem_b[i10 + 2]
			u4 = mem_b[i10 + 2]		; sign extend
			u5 = mem_b[i10 + 3]
			i6 = mem_s[i10 + 4]		; sign extend
			i21 = i6 + 1			; test load RAW hazard
			u7 = mem_s[i10 + 4]
			i8 = mem_s[i10 + 6]
			i9 = mem_l[i10 + 8]
			i22 = i9 + 1			; test load RAW hazard
			i10 = i10 + 4
			i11 = mem_b[i10 + -4]	; negative offset
			
			goto ___done
			
			label1:	.byte 0x5a, 0x69, 0xc3, 0xff
					.short 0xabcd, 0x1234	
					.word 0xdeadbeef
		''', {
			'u1' : 0x5a, 
			'u2' : 0x69, 
			'u3' : 0xffffffc3, 
			'u4' : 0xc3,
			'u5' : 0xff, 
			'u6' : 0xffffabcd, 
			'u7' : 0xabcd, 
			'u8' : 0x1234,
			'u9' : 0xdeadbeef, 
			'u10' : None, 
			'u20' : 0x5a + 1, 
			'u21' : 0xffffabcd + 1,
			'u22' : 0xdeadbeef + 1, 
			'u10' : None, 
			'u11' : 0x5a}, None, None, None)
		
	def test_scalarStore():
		baseAddr = 128

		return ({'u1' : 0x5a, 'u2' : 0x69, 'u3' : 0xc3, 'u4' : 0xff, 
			'u5' : 0xabcd, 'u6' : 0x1234,
			'u7' : 0xdeadbeef, 'u10' : baseAddr}, '''
	
			mem_b[i10] = i1
			mem_b[i10 + 1] = i2
			mem_b[i10 + 2] = i3
			mem_b[i10 + 3] = i4
			mem_s[i10 + 4] = i5
			mem_s[i10 + 6] = i6
			mem_l[i10 + 8] = i7
		''', {}, baseAddr, [ 0x5a, 0x69, 0xc3, 0xff, 0xcd, 0xab, 0x34, 0x12, 0xef,
				0xbe, 0xad, 0xde ], None)
	
	#
	# Store word, read smaller than word to ensure proper ordering
	#
	def test_endian1():
		return ({'u1' : 128, 'u2' : 0x12345678},
			'''
				mem_l[u1] = u2
				u4 = mem_s[u1]
				u5 = mem_s[u1 + 2]
				u6 = mem_b[u1]
				u7 = mem_b[u1 + 1]
				u8 = mem_b[u1 + 2]
				u9 = mem_b[u1 + 3]
			''',
			{ 	't0u4' : 0x5678, 
				't0u5' : 0x1234, 
				't0u6' : 0x78,
				't0u7' : 0x56, 
				't0u8' : 0x34, 
				't0u9' : 0x12 }, None, None, None)

	#
	# Store smaller than word, read word to ensure proper ordering
	#
	def test_endian2():
		return ({'u1' : 128, 
				'u2' : 0x5678, 
				'u3' : 0x1234, 
				'u4' : 0xef,
				'u5' : 0xbe, 
				'u6' : 0xad, 
				'u7' : 0xde},
			'''
				mem_s[u1] = u2
				mem_s[u1 + 2] = u3
				
				mem_b[u1 + 4] = u4
				mem_b[u1 + 5] = u5 
				mem_b[u1 + 6] = u6
				mem_b[u1 + 7] = u7
				
				u8 = mem_l[u1]
				u9 = mem_l[u1 + 4]
			''',
			{ 't0u8' : 0x12345678, 't0u9' : 0xdeadbeef }, None, None, None)
				
				
	
	# Two loads, one with an offset to ensure offset calcuation works correctly
	# and the second instruction ensures execution resumes properly after the
	# fetch stage is suspended for the multi-cycle load.
	# We also immediately access the destination register.  Since the load
	# has several cycles of latency, this ensures the scheduler is properly 
	# inserting bubbles.
	def test_blockLoad():
		data = [ random.randint(0, 0xff) for x in range(4 * 16 * 2) ]
		v1 = makeVectorFromMemory(data, 0, 4)
		v2 = makeVectorFromMemory(data, 64, 4)
		return ({ 'u1' : 0xaaaa }, '''
			i10 = 15
			cr30 = i10		; Enable all threads
			
			i10 = &label1
			v1 = mem_l[i10]
			v4 = v1	+ 1					; test load RAW hazard
			v6{u1} = mem_l[i10]			; mask form
			v7{~u1} = mem_l[i10]		; invert mask
			v2 = mem_l[i10 + 64]
			v5 = v2	+ 1					; test load RAW hazard
			v8{u1} = mem_l[i10 + 64]		; mask form
			v9{~u1} = mem_l[i10 + 64]	; invert mask
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
			'u10' : None}, None, None, None)
	
	def test_blockStore():
		cases = []
		for mask, invertMask in [(None, False), (0x5a5a, False), (0x5a5a, True)]:
			baseAddr = 128
			memory = [ 0 for x in range(4 * 16 * 4) ]	
			v1 = allocateUniqueScalarValues(16)
			v2 = allocateUniqueScalarValues(16)
			emulateVectorStore(baseAddr, memory, baseAddr, v1, 4, mask, invertMask)
			emulateVectorStore(baseAddr, memory, baseAddr + 64, v2, 4, mask, invertMask)
		
			maskDesc = ''
			if mask != None:
				maskDesc += '{'
				if invertMask:
					maskDesc += '~'
					
				maskDesc += 'u1}'
			
			code = 'mem_l[i10]' + maskDesc + '''= v1
				mem_l[i10 + 64]''' + maskDesc + '''= v2
			'''
		
			cases += [ ({ 'u10' : baseAddr, 'v1' : v1, 'v2' : v2, 'u1' : mask if mask != None else 0 }, 
				code, { 'u10' : None }, baseAddr, memory, None) ]

		return cases

	def test_stridedLoad():
		data = [ random.randint(0, 0xff) for x in range(12 * 16) ]
		v1 = makeVectorFromMemory(data, 0, 12)
		return ({ 'u1' : 0xaaaa }, '''
			u10 = 15
			cr30 = u10	; Start all strands

			i10 = &label1
			v1 = mem_l[i10, 12]
			v2 = v1 + 1			; test load RAW hazard
			v3{u1} = mem_l[i10, 12]
			v4{~u1} = mem_l[i10, 12]
			goto ___done

			label1:	''' + makeAssemblyArray(data)
		, { 'v1' : v1,
			'v2' : [ x + 1 for x in v1 ],
			'v3' : [ value if index % 2 == 0 else 0 for index, value in enumerate(v1) ],
			'v4' : [ value if index % 2 == 1 else 0 for index, value in enumerate(v1) ],
			'u10' : None}, None, None, None)
	
	def test_stridedStore():
		cases = []
		for mask, invertMask in [(None, False), (0x5a5a, False), (0x5a5a, True)]:
			baseAddr = 128
			memory = [ 0 for x in range(4 * 16 * 4) ]	
			v1 = allocateUniqueScalarValues(16)
			v2 = allocateUniqueScalarValues(16)
			emulateVectorStore(baseAddr, memory, baseAddr, v1, 12, mask, invertMask)
			emulateVectorStore(baseAddr, memory, baseAddr + 4, v2, 12, mask, invertMask)
		
			maskDesc = ''
			if mask != None:
				maskDesc += '{'
				if invertMask:
					maskDesc += '~'
					
				maskDesc += 'u1}'
			
			code = 'mem_l[i10, 12]' + maskDesc + '''= v1
				i10 = i10 + 4
				mem_l[i10, 12]''' + maskDesc + '''= v2
			'''
		
			cases += [({ 'u10' : baseAddr, 'v1' : v1, 'v2' : v2, 'u1' : mask if mask != None else 0 }, 
				code, { 'u10' : None }, baseAddr, memory, None) ]
				
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
				u10 = 15
				cr30 = u10		; Enable all threads

				v0 = mem_l[ptr]
				v1 = mem_l[v0]
				v2 = v1 + 1			; test load RAW hazard
				v3{u1} = mem_l[v0]
				v4{~u1} = mem_l[v0]
				goto ___done

				.align 64
			ptr: '''
	
		for x in shuffledIndices:
			code += '\t\t\t\t.word ' + labels[x] + '\n'
			
		for x in range(16):
			code += labels[x] + ':\t\t\t\t.word ' + hex(values[x]) + '\n'
	
		expectedArray = [ values[shuffledIndices[x]] for x in range(16) ]
	
		return ({ 'u1' : 0xaaaa }, code, { 
			'v0' : None, 
			'v1' : expectedArray, 
			'v2' : [ x + 1 for x in expectedArray ],
			'v3' : [ value if index % 2 == 0 else 0 for index, value in enumerate(expectedArray) ],
			'v4' : [ value if index % 2 == 1 else 0 for index, value in enumerate(expectedArray) ],
			'u10' : None
			}, None, None, None)
	
	def test_scatterStore():
		baseAddr = 128
		cases = []
		for offset, mask, invertMask in [(0, None, None), 
			(8, None, None), (4, 0xa695, False), (4, 0xa695, True)]:
			memory = [ 0 for x in range(10 * 16) ]	
			values = allocateUniqueScalarValues(16)
			ptrs = [ baseAddr + x * 8 for x in shuffleIndices() ]
		
			code = 'mem_l[v1'
			if offset != None:
				code += ' + ' + str(offset)
			
			code += ']'
			if mask != None:
				code += '{'
				if invertMask:
					code += '~'
					
				code += 'u0}'	
			
			code += '=v2'
		
			emulateScatterStore(baseAddr, memory, ptrs, values, 
				offset if offset != None else 0, mask, invertMask)
		
			cases += [({ 'v1' : ptrs, 'v2' : values, 'u0' : mask if mask != None else 0}, 
				code, 
				{ 't0u10' : None }, baseAddr, memory, None)]

		return cases
		
	def test_controlRegister():
		return ({ 'u7' : 0x12345}, '''
			cr7 = u7
			cr9 = u0
			u12 = cr7
		''', { 't0u12' : 0x12345}, None, None, None)

	# Verify that all cache alignments work by doing a copy byte-by-byte.
	# The cache line size is 64 bytes, so we will try 128. 
	def test_bytewiseCopy():
		destAddr = 1024
		data = [ random.randint(0, 0xff) for x in range(128) ]

		return ({
			'u0' : destAddr,
			'u2' : 128}, '''
						; s0 is dest
						; s1 is src
						; s2 is length
						s1 = &sourceData
			loop:		s3 = mem_b[s1]
						mem_b[s0] = s3
						s0 = s0 + 1
						s1 = s1 + 1
						s2 = s2 - 1
						if s2 goto loop
						goto ___done
			sourceData: '''+ makeAssemblyArray(data),
			None, destAddr, data, 2048)

	# Load 4 separate cache lines.  Verify requests are queued properly.
	def test_divergentLoad():
		destAddr = 128
		data = [ random.randint(0, 0xff) for x in range(256) ]

		return ({}, '''
						u0 = 15
						cr30 = u0		; Start all strands
		
						u0 = cr0
						u0 = u0 << 6
						u0 = u0 + ''' + str(destAddr) + '''
						v0 = mem_l[u0]
						goto ___done
						.align 128
			sourceData: '''+ makeAssemblyArray(data),
			{ 'u0' : None, 
			't0v0' : makeVectorFromMemory(data, 0, 4), 
			't1v0' : makeVectorFromMemory(data, 64, 4), 
			't2v0' : makeVectorFromMemory(data, 128, 4), 
			't3v0' : makeVectorFromMemory(data, 192, 4) }, 
			None, None, None)

	def test_multiStrandStore():
		destAddr = 128
		data = [ random.randint(0, 0xff) for x in range(256) ]

		return ({
			't0v0' : makeVectorFromMemory(data, 0, 4), 
			't1v0' : makeVectorFromMemory(data, 64, 4), 
			't2v0' : makeVectorFromMemory(data, 128, 4), 
			't3v0' : makeVectorFromMemory(data, 192, 4)
			}, '''
						u0 = 15
						cr30 = u0		; Start all strands
		
						u0 = cr0
						u0 = u0 << 6
						u0 = u0 + ''' + str(destAddr) + '''
						mem_l[u0] = v0
						goto ___done''',
			{ 'u0' : None }, 
			destAddr, data, 256)		
	
	# Was causing a hang previously.  This test just verifies that the
	# code runs to completion.
	def test_storeStoreCollision():
		return ({ 'u0' : 7 }, '''
					mem_l[value] = u0
					mem_l[value] = u0
					u1 = mem_l[value]
					u1 = u1 + 1
					mem_l[value] = u1
					goto ___done
			value:	.word 0
		
		''', { 't0u1' : 8 }, None, None, None)
		
	def test_loadSynchronized():
		return ({}, '''
			u0 = &label1
			u1 = mem_sync[u0]		; Cache miss
			u2 = mem_sync[u0]		; Cache hit, but reload
			goto ___done
			
			label1:	.word 0x1abcdef1
		
		''', { 't0u0' : None, 't0u1' : 0x1abcdef1, 't0u2' : 0x1abcdef1 }, 
		None, None, None)
	
	# Success, no conflict
	def test_loadStoreSynchronized0():
		return ({ 'u0' : 128, 'u1' : 0xdeadbeef }, '''
			u2 = mem_sync[u0]	
			mem_sync[u0] = u1
		''', { 't0u1' : 1, 't0u2' : 0 }, 
		128, [ 0xef, 0xbe, 0xad, 0xde ], None)
	
	# Conflict, no store
	def test_loadStoreSynchronized1():
		return ({ 'u0' : 128, 'u1' : 0xdeadbeef, 'u3' : 0x12344321 }, '''
			u2 = mem_sync[u0]
			mem_l[u0] = u3
			mem_sync[u0] = u1
			u3 = mem_l[u0]		; Make sure L1 cache was not updated (regression test)
		''', { 't0u1' : 0, 't0u2' : 0, 'u0u3' : 0 }, 
		128, [ 0x21, 0x43, 0x34, 0x12 ], None)
		
	def test_atomicAdd():
		return ({},
			'''
							u0 = &var
							u1 = 0xf
							cr30 = u1	; Start all threads
				
				retry:		s1 = mem_sync[s0]
							s1 = s1 + 1
							mem_sync[s0] = s1
							if !s1 goto retry
							
				; The wait loop allows the test to terminate cleanly, but
				; is also important to ensure the L1 cache has been updated
				; properly.
				wait:		s2 = mem_l[s0]
							s2 = s2 == 21
							if !s2 goto wait
							
				goto		___done
				.align 128
				var:		.word 17
			''', { 'u0' : None, 'u1' : 1, 'u2' : None }, 128, [ 21, 0, 0, 0 ], None)

	def test_spinlock():
		return ({},
			'''
						u0 = 0xf
						cr30 = u0	; Start all threads

						s0 = &lock
				loop0:	s1 = mem_sync[s0]
						if s1 goto loop0		; Lock is already held, wait
						s1 = 1
						mem_sync[s0] = s1
						if !s1 goto loop0
						
						s1 = mem_l[protected_val]
						
						nop						; increase contention 
						nop
						nop
						nop
						nop
						nop

						s1 = s1 + 1
						mem_l[protected_val] = s1

						s1 = 0
						mem_l[s0] = s1			; release lock
						
				loop3:	s2 = mem_l[protected_val]
						s2 = s2 == 23
						if !s2 goto loop3
				
			lock:			.word 0
							.align 128
			protected_val:	.word 19
			
			
			''', None, 128, [ 23, 0, 0, 0 ], None)
	