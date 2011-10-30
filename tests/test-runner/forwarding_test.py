#
# Test result forwarding logic
#

import random, sys, string
from runcase import *

def doGetElem(vec, index):
	return vec[index]
	
def doVectorCompare(veca, vecb, func):
	print 'doVectorCompare'
	val = 0
	for x in range(16):
		val <<= 1
		print 'compare',veca[x], vecb[x]
		if func(veca[x], vecb[x]):
			print '1'
			val |= 1
		else:
			print '0'
			
		print 'val=', val

	return val

scalarCompareOps = [
	('==', (lambda a, b: int(a == b) * 0xffff)),
	('<>', (lambda a, b: int(a != b) * 0xffff)),
	('>', (lambda a, b: int(a > b) * 0xffff)),
	('<', (lambda a, b: int(a < b) * 0xffff)),
	('>=', (lambda a, b: int(a >= b) * 0xffff)),
	('<=', (lambda a, b: int(a <= b) * 0xffff)),
]

vectorCompareOps = [(name, (lambda a, b: doVectorCompare(a, b, func))) 
	for name, func in scalarCompareOps]

ternaryOps = [
	('+', (lambda a, b: (a + b) & 0xffffffff)),
	('-', (lambda a, b: (a - b) & 0xffffffff)),
	('&', (lambda a, b: a & b)),
	('&~', (lambda a, b: a & ~b)),
	('|', (lambda a, b: a | b)),
	('^', (lambda a, b: a ^ b))

# These work a little funkily
#	('muli', (lambda a, b: (a * b) & 0xffffffff)),
#	('lsr', (lambda a, b: int((a >> b) & 0xffffffff))),
#	('lsl', (lambda a, b: int((a << b) & 0xffffffff)))
]

vectorTernaryOps = []
vectorTernaryOps += ternaryOps

scalarTernaryOps = []
scalarTernaryOps += scalarCompareOps
scalarTernaryOps += ternaryOps

def genBinaryOp(dest, operation, src1, src2):
	return dest + '=' + src1 + ' ' + operation + ' ' + src2 + '\n'

#
# Run one instance of a register forwarding test
# This validates that:
#  1. Scalar registers are forwarded from every stage in the pipeline
#  2. Only the most recent value is forwarded, even when other writes to 
#	  a register are in the pipeline
#  3. Writes to unrelated registers are not forwarded
#
# To do:
#  1. Ensure that writes to vector registers with the same index are not 
#	  forwarded.
#
def runScalarTernaryForwardTest(op, lag, useParam1):
	opcode, func = op

	# Generate 3 random scalar values
	regs = allocateUniqueRegisters('s', 10)
	values = allocateUniqueScalarValues(10)

	initialState = dict(zip(regs, values))
	finalState = {}

	# Fill the pipeline with "shadow" operations, which write to a source
	# operand, but should be ignored because they are older
	code = ''
	for i in range(5):
		code += genBinaryOp(regs[0], opcode, regs[5], regs[6])

	# First operation
	code += genBinaryOp(regs[0], opcode, regs[1], regs[2]);
	bypassValue = func(values[1], values[2])
	finalState[regs[0]] = bypassValue

	# Add some dummy operations that don't reference any of our registers
	for i in range(lag):
		code += genBinaryOp(regs[7], opcode, regs[8], regs[9])

	if lag > 0:
		finalState[regs[7]] = func(values[8], values[9])	
	
	# Second operation
	if useParam1:
		code += genBinaryOp(regs[3], opcode, regs[0], regs[4])
		finalState[regs[3]] = func(bypassValue, values[4])
	else:
		code += genBinaryOp(regs[3], opcode, regs[4], regs[0])
		finalState[regs[3]] = func(values[4], bypassValue)

	runTest(initialState, code, finalState)

# Todo: Add test for v, v, imm
def runScalarImmediateForwardTest(op, lag):
	opcode, func = op

	# Generate 3 random scalar values
	regs = allocateUniqueRegisters('s', 7)
	values = allocateUniqueScalarValues(7)

	values[1] = values[1] & 0x7ff
	values[2] = values[2] & 0x7ff
	values[4] = values[4] & 0x7ff

	initialState = {
		# Source operands
		regs[1] : values[0],
		regs[3] : values[3],
		regs[5] : values[5],
		regs[6] : values[6],
	}
	
	# Fill the pipeline with "shadow" operations, which write to a source
	# operand, but should be ignored because they are older
	code = ''
	for i in range(5):
		code += genBinaryOp(regs[0], opcode, regs[3], regs[4])

	# First operation
	code += genBinaryOp(regs[0], opcode, regs[1], str(values[1]))

	# Add some dummy operations that don't reference any of our registers
	for i in range(lag):
		code += genBinaryOp(regs[4], opcode, regs[5], regs[6])
	
	finalState	= { regs[0] : func(values[0], values[1]) }

	# Second operation
	code += genBinaryOp(regs[2], opcode, regs[0], str(values[2]))

	finalState[regs[2]] = func(func(values[0], values[1]), values[2])
	if lag > 0:
		finalState[regs[4]] = func(values[5], values[6])	# dummy operation

	runTest(initialState, code, finalState)

# Where valuea and valueb are lists.
def performVectorOp(original, valuea, valueb, func, mask):
	result = []

	for laneo, lanea, laneb in zip(original, valuea, valueb):
		if (mask & 0x8000) != 0:
			result += [ func(lanea, laneb) ]
		else:
			result += [ laneo ]

		mask <<= 1

	return result
	
def allocateRandomVectorValue():
	return [ random.randint(1, 0xffffffff) for x in range(16) ]


def performScalarVectorOp(valuea, valueb, func):
	return func(valuea, valueb)

#
# Tests:
#  1. Ensure each lane is bypassed independently
#  2. Ensure bypasses work from all stages
#  3. Validate v, v, s instructions
#  4. Only lanes that are masked are forwarded.
# To do:
#  1. Ensure that writes to scalar registers with the same index are not 
#	  forwarded.
#  2. Validate writes are forwarded if they have no mask specified
#  3. Validate with inverted mask
#
def runVectorTernaryForwardTest(op1, op2, initialShift, format):
	opcode1, func1 = op1
	opcode2, func2 = op2

	NUM_STEPS = 6
	vectorRegs = allocateUniqueRegisters('v', NUM_STEPS * 2 + 3)
	bypassReg = vectorRegs[NUM_STEPS * 2 + 1]
	resultReg = vectorRegs[NUM_STEPS * 2 + 2]
	scalarRegs = allocateUniqueRegisters('s', NUM_STEPS + 1)

	scalarOtherOperandReg = scalarRegs[NUM_STEPS]
	scalarOtherOperandVal = allocateUniqueScalarValues(1)[0]
	vectorOtherOperandReg = vectorRegs[NUM_STEPS * 2]
	vectorOtherOperandVal = allocateRandomVectorValue() 

	mask = 0xffff >> initialShift	# positive bignum
	initialState = {
		scalarOtherOperandReg : scalarOtherOperandVal,
		vectorOtherOperandReg : vectorOtherOperandVal,
	}

#	resultReg = string.replace(resultReg, 'v', 's')

	bypassValue = [0 for x in range(16)]
	code = ''
	for x in range(NUM_STEPS):
		val1 = allocateRandomVectorValue() 
		val2 = allocateRandomVectorValue()
		initialState[vectorRegs[x * 2]] = val1	
		initialState[vectorRegs[x * 2 + 1]] = val2
		initialState[scalarRegs[x]] = mask
		code += bypassReg + '{' + scalarRegs[x] + '} = ' + \
			vectorRegs[x * 2] + ' ' + opcode1 + ' ' + vectorRegs[x * 2 + 1] + '\n'
		bypassValue = performVectorOp(bypassValue, val1, val2, func1, mask)
		mask >>= 1

	if format == 'sbv':	 # Scalar = Bypassed value, vector
		code += genBinaryOp(resultReg, opcode2, bypassReg, vectorOtherOperandReg)
		result = performScalarVectorOp(bypassValue, vectorOtherOperandVal, func2)
	elif format == 'svb':	# Scalar = Vector, bypassed value
		code += genBinaryOp(resultReg, opcode2, vectorOtherOperandReg, bypassReg)
		result = performScalarVectorOp(vectorOtherOperandVal, bypassValue, func2)
	elif format == 'sbs':	# Scalar = Bypassed, scalar value
		code += genBinaryOp(resultReg, opcode2, bypassReg, scalarOtherOperandReg)
		result = performScalarVectorOp(bypassValue, [scalarOtherOperandVal for x in range(16)], func2)
	elif format == 'vbv':	 # Vector = Bypassed value, vector
		code += genBinaryOp(resultReg, opcode2, bypassReg, vectorOtherOperandReg)
		result = performVectorOp([0 for x in range(16)], bypassValue, 
			vectorOtherOperandVal, func2, 0xffff)
	elif format == 'vvb':	# Vector = Vector, bypassed value
		code += genBinaryOp(resultReg, opcode2, vectorOtherOperandReg, bypassReg)
		result = performVectorOp([0 for x in range(16)], vectorOtherOperandVal, 
			bypassValue, func2, 0xffff)
	elif format == 'vbs':	# Vector = Bypassed, scalar value
		code += genBinaryOp(resultReg, opcode2, bypassReg, scalarOtherOperandReg)
		result = performVectorOp([0 for x in range(16)], bypassValue, 
			[scalarOtherOperandVal for x in range(16)], func2, 0xffff)
	else:
		print 'unknown addressing mode', format
		sys.exit(2)

	finalState = { bypassReg : bypassValue, resultReg : result }

	runTest(initialState, code, finalState)

def testPcOperand():
	# Immediate, PC as first operand
	regs = allocateUniqueRegisters('s', 1)
	code = ''
	initialPc = random.randint(1, 10)
	for x in range(initialPc):
		code += 'nop\r\n'

	code += genBinaryOp(regs[0], '+', 'pc', '0')

	runTest({}, code, { regs[0] : (initialPc * 4) + 4})
	
	# Ternary, PC as first operand
	regs = allocateUniqueRegisters('s', 2)
	values = allocateUniqueScalarValues(1)
	code = ''
	initialPc = random.randint(1, 10)
	for x in range(initialPc):
		code += 'nop\r\n'


	code += genBinaryOp(regs[0], '+', 'pc', regs[1])
	runTest({ regs[1] : values[0] }, code, { regs[0] : (initialPc * 4) + 4 
		+ values[0]})

	# Ternary, PC as second operand
	regs = allocateUniqueRegisters('s', 2)
	values = allocateUniqueScalarValues(1)
	code = ''
	initialPc = random.randint(1, 10)
	for x in range(initialPc):
		code += 'nop\r\n'

	code += genBinaryOp(regs[0], '+', regs[1], 'pc')
	runTest({ regs[1] : values[0] }, code, { regs[0] : (initialPc * 4) + 4 
		+ values[0]})


def runForwardTests():
#	print 'scalar/vector ternary ops'
#	for op in vectorCompareOps:
#		for format in [ 'sbv', 'svb', 'sbs' ]:
#			for initialShift in range(11):
#				runVectorTernaryForwardTest(ternaryOps[0], op, initialShift, format)

	print 'scalar ternary ops'
	for useParam1 in [False, True]:
		for op in scalarTernaryOps:
			for lag in range(6):
				runScalarTernaryForwardTest(op, lag, useParam1)

	testPcOperand()

	print 'vector ternary ops'
	for op in vectorTernaryOps:
		for format in [ 'vbv', 'vvb', 'vbs' ]:
			for initialShift in range(11):
				runVectorTernaryForwardTest(op, op, initialShift, format)

	print 'scalar immediate ops'
	for op in scalarTernaryOps:
		for lag in range(6):
			runScalarImmediateForwardTest(op, lag)
	
	# XXX todo: binary ops
	
	# XXX todo: floating point operations


runForwardTests()		
print 'All tests passed'	
