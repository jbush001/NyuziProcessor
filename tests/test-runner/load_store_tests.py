from runcase import *


def runScalarLoadTests():
	runTest({}, '''
		i10 = &label1
		i1 = mem_b[i10]
		i2 = mem_b[i10 + 1]
		i3 = mem_b[i10 + 2]
		u4 = mem_b[i10 + 2]		; sign extend
		u5 = mem_b[i10 + 3]
		i6 = mem_s[i10 + 4]		; sign extend
		u7 = mem_s[i10 + 4]
		i8 = mem_s[i10 + 6]
		i9 = mem_l[i10 + 8]
		done goto done
		
		label1	.byte 0x5a, 0x69, 0xc3, 0xff
				.short 0xabcd, 0x1234	
				.word 0xdeadbeef
	
	''', {'u1' : 0x5a, 'u2' : 0x69, 'u3' : 0xffffffc3, 'u4' : 0xc3,
	'u5' : 0xff, 'u6' : 0xffffabcd, 'u7' : 0xabcd, 'u8' : 0x1234,
	'u9' : 0xdeadbeef, 'u10' : None})
	
def runScalarStoreTests():
	baseAddr = 64

	runTest({'u1' : 0x5a, 'u2' : 0x69, 'u3' : 0xc3, 'u4' : 0xff, 
		'u5' : 0xabcd, 'u6' : 0x1234,
		'u7' : 0xdeadbeef, 'u10' : baseAddr}, '''

		mem_b[i10] = i1
		mem_b[i10 + 1] = i2
		mem_b[i10 + 2] = i3
		mem_b[i10 + 3] = i4
		mem_s[i10 + 4] = i5
		mem_s[i10 + 6] = i6
		mem_l[i10 + 8] = i7
		done goto done
	''', {}, baseAddr, [ 0x5a, 0x69, 0xc3, 0xff, 0xcd, 0xab, 0x34, 0x12, 0xef,
			0xbe, 0xad, 0xde ])

def runScalarCopyTest():
	baseAddr = 64
	
	runTest({'u1' : 64, 'u2' : 0x12345678},
		'''
			mem_l[u1] = u2
			u3 = mem_l[u1]
			u4 = mem_s[u1]
			u5 = mem_s[u1 + 2]
			u6 = mem_b[u1]
			u7 = mem_b[u1 + 1]
			u8 = mem_b[u1 + 2]
			u9 = mem_b[u1 + 3]
			done goto done
		''',
		{ 'u3' : 0x12345678, 'u4' : 0x5678, 'u5' : 0x1234, 'u6' : 0x78,
			'u7' : 0x56, 'u8' : 0x34, 'u9' : 0x12 })

# Two loads, one with an offset to ensure offset calcuation works correctly
# and the second instruction ensures execution resumes properly after the
# fetch stage is suspended for the multi-cycle load.
def runBlockLoadTest():
	runTest({}, '''
		i10 = &label1
		v1 = mem_l[i10]
		v2 = mem_l[i10 + 4]
		done goto done
		
		label1	.word 0x01010101, 0x02020202, 0x03030303, 0x04040404
				.word 0x05050505, 0x06060606, 0x07070707, 0x08080808
				.word 0x09090909, 0x0a0a0a0a, 0x0b0b0b0b, 0x0c0c0c0c
				.word 0x0d0d0d0d, 0x0e0e0e0e, 0x0f0f0f0f, 0x5a5a5a5a
				.word 0xc6c6c6c6

	''', { 'v1' : [ 0x01010101, 0x02020202, 0x03030303, 0x04040404,
				0x05050505, 0x06060606, 0x07070707, 0x08080808,
				0x09090909, 0x0a0a0a0a, 0x0b0b0b0b, 0x0c0c0c0c,
				0x0d0d0d0d, 0x0e0e0e0e, 0x0f0f0f0f, 0x5a5a5a5a ],
			'v2' : [ 0x02020202, 0x03030303, 0x04040404,
				0x05050505, 0x06060606, 0x07070707, 0x08080808,
				0x09090909, 0x0a0a0a0a, 0x0b0b0b0b, 0x0c0c0c0c,
				0x0d0d0d0d, 0x0e0e0e0e, 0x0f0f0f0f, 0x5a5a5a5a,
				0xc6c6c6c6 ],
			'u10' : None})


def runBlockStoreTest():
	baseAddr = 64
	
	data = [ random.randint(0, 0xff) for x in range(4 * 16 * 2) ]
	v1 = [ data[x * 4] | (data[x * 4 + 1] << 8) | (data[x * 4 + 2] << 16) 
		| (data[x * 4 + 3] << 24) for x in range(16) ]
	v2 = [ data[64 + x * 4] | (data[64 + x * 4 + 1] << 8) 
		| (data[64 + x * 4 + 2] << 16) | (data[64 + x * 4 + 3] << 24) for x in range(16) ]

	runTest({ 'u10' : baseAddr,
			'v1' : v1,
			'v2' : v2}, 
		'''
		mem_l[i10] = v1
		mem_l[i10 + 64] = v2
		done goto done

	''',{}, baseAddr, data)

runScalarLoadTests()
runScalarStoreTests()
runScalarCopyTest()
runBlockLoadTest()
runBlockStoreTest()