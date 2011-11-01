from runcase import *

def makeVectorFromMemory(data, startOffset, stride):
	return [ data[startOffset + x * stride] 
		| (data[startOffset + x * stride + 1] << 8) 
		| (data[startOffset + x * stride + 2] << 16) 
		| (data[startOffset + x * stride + 3] << 24) for x in range(16) ]

def makeAssemblyArray(data):
	str = ''
	for x in data:
		if str != '':
			str += ', '
			
		str += '0x%x' % x

	return '.byte ' + str

def runScalarLoadTests():
	runTest({}, '''
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
		
		done goto done
		
		label1	.byte 0x5a, 0x69, 0xc3, 0xff
				.short 0xabcd, 0x1234	
				.word 0xdeadbeef
	
	''', {'u1' : 0x5a, 'u2' : 0x69, 'u3' : 0xffffffc3, 'u4' : 0xc3,
	'u5' : 0xff, 'u6' : 0xffffabcd, 'u7' : 0xabcd, 'u8' : 0x1234,
	'u9' : 0xdeadbeef, 'u10' : None, 'u20' : 0x5a + 1, 'u21' : 0xffffabcd + 1,
	'u22' : 0xdeadbeef + 1})
	
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

#
# Store then load indivitual elements to verify endianness is correct.
#
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
# We also immediately access the destination register.  Since the load
# has several cycles of latency, this ensures the scheduler is properly 
# inserting bubbles.
def runBlockLoadTest():
	data = [ random.randint(0, 0xff) for x in range(4 * 16 * 2) ]
	v1 = makeVectorFromMemory(data, 0, 4)
	v2 = makeVectorFromMemory(data, 4, 4)
	runTest({}, '''
		i10 = &label1
		v1 = mem_l[i10]
		v4 = v1	+ 1				; test load RAW hazard
		v2 = mem_l[i10 + 4]
		v5 = v2	+ 1				; test load RAW hazard
		done goto done
		
		label1	''' + makeAssemblyArray(data)
	, { 'v1' : v1,
		'v4' : [ x + 1 for x in v1 ],
		'v2' : v2,
		'v5' : [ x + 1 for x in v2 ],
		'u10' : None})

def runBlockStoreTest():
	baseAddr = 64
	
	data = [ random.randint(0, 0xff) for x in range(4 * 16 * 2) ]
	v1 = makeVectorFromMemory(data, 0, 4)
	v2 = makeVectorFromMemory(data, 64, 4)

	runTest({ 'u10' : baseAddr,
			'v1' : v1,
			'v2' : v2}, 
		'''
		mem_l[i10] = v1
		mem_l[i10 + 64] = v2
		done goto done
	''',{}, baseAddr, data)

def runStridedLoadTest():
	data = [ random.randint(0, 0xff) for x in range(12 * 16) ]
	v1 = makeVectorFromMemory(data, 0, 12)
	runTest({}, '''
		i10 = &label1
		v1 = mem_l[i10, 12]
		v2 = v1 + 1			; test load RAW hazard
		done goto done
		label1	''' + makeAssemblyArray(data)
	, { 'v1' : v1,
		'v2' : [ x + 1 for x in v1 ],
		'u10' : None})

def runStridedStoreTest():
	baseAddr = 64

	data = [ random.randint(0, 0xff) for x in range(2 * 4 * 16) ]
	v1 = makeVectorFromMemory(data, 0, 8);
	v2 = makeVectorFromMemory(data, 4, 8);
	runTest({ 'u10' : baseAddr, 'v1' : v1, 'v2' : v2 }, '''
		mem_l[i10, 8] = v1
		i10 = i10 + 4
		mem_l[i10, 8] = v2
		done goto done
	'''
	, { 'u10' : None }, baseAddr, data)

def shuffleIndices():
	rawPointers = [ x for x in range(16) ]
	shuffledPointers = []
	for x in range(16):
		pullIndex = random.randint(0, len(rawPointers) - 1)
		shuffledPointers += [ rawPointers[pullIndex] ]
		del rawPointers[pullIndex]

	return shuffledPointers	

#
# This also validates that the assembler properly fixes up label references
# as data
#
def runGatherLoadTest():
	labels = ['off' + str(x) for x in range(16)]
	values = allocateUniqueScalarValues(16)
	shuffledIndices = shuffleIndices()

	code = '''
						v0 = mem_l[ptr]
						v1 = mem_l[v0]
						v2 = v1 + 1			; test load RAW hazard
			done		goto done
			
			ptr'''

	for x in shuffledIndices:
		code += '\t\t\t\t.word ' + labels[x] + '\n'
		
	for x in range(16):
		code += labels[x] + '\t\t\t\t.word ' + str(values[x]) + '\n'

	expectedArray = [ values[shuffledIndices[x]] for x in range(16) ]

	runTest({}, code, { 'v0' : None, 'v1' : expectedArray, 
		'v2' : [ x + 1 for x in expectedArray ] })

def runScatterStoreTest():
	baseAddr = 64
	data = [ random.randint(0, 0xff) for x in range(4 * 16) ]	# final data config
	values = makeVectorFromMemory(data, 0, 4);
	values.reverse()
	ptrs = [ baseAddr + (15 - x) * 4 for x in range(16) ]

	runTest({ 'u10' : baseAddr, 'v1' : ptrs, 'v2' : values }, '''
		mem_l[v1] = v2
		done goto done
	'''
	, { 'u10' : None }, baseAddr, data)

runScalarLoadTests()
runScalarStoreTests()
runScalarCopyTest()
runBlockLoadTest()
runBlockStoreTest()
runStridedLoadTest()
runStridedStoreTest()
runGatherLoadTest()
runScatterStoreTest()

# XXX todo run all of the vector cases with masks


