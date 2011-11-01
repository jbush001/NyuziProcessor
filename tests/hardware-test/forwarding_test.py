#
# Test result forwarding logic (aka bypassing)
#

import random, sys, string
from runcase import *

def emitOperation(dest, src1, src2):
	return dest + '=' + src1 + ' ^ ' + src2 + '\n'

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
def runScalarForwardTest(lag, useParam1):
	# Generate 3 random scalar values
	regs = allocateUniqueRegisters('u', 10)
	values = allocateUniqueScalarValues(10)

	initialState = dict(zip(regs, values))
	finalState = {}

	# Fill the pipeline with "shadow" operations, which write to a source
	# operand, but should be ignored because they are older
	code = ''
	for i in range(5):
		code += emitOperation(regs[0], regs[5], regs[6])

	# Generate the result to be bypassed
	code += emitOperation(regs[0], regs[1], regs[2]);
	bypassValue = values[1] ^ values[2]
	finalState[regs[0]] = bypassValue

	# Add some dummy operations that don't reference any of our registers
	# This is to introduce latency so we can test forwarding from the appropriate
	# stage.
	for i in range(lag):
		code += emitOperation(regs[7], regs[8], regs[9])

	if lag > 0:
		finalState[regs[7]] = values[8] ^ values[9]
	
	# Second operation, this will potentially require forwarded operations
	# from the previous stage
	if useParam1:
		code += emitOperation(regs[3], regs[0], regs[4])
		finalState[regs[3]] = bypassValue ^ values[4]
	else:
		code += emitOperation(regs[3], regs[4], regs[0])
		finalState[regs[3]] = values[4] ^ bypassValue

	runTest(initialState, code, finalState)

# Todo: Add test for v, v, imm
def runScalarImmediateForwardTest(lag):
	# Generate 3 random scalar values
	regs = allocateUniqueRegisters('u', 7)
	values = allocateUniqueScalarValues(7)

	values[1] = values[1] & 0xff
	values[2] = values[2] & 0xff
	values[4] = values[4] & 0xff

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
		code += emitOperation(regs[0], regs[3], regs[4])

	# First operation
	code += emitOperation(regs[0], regs[1], str(values[1]))

	# Add some dummy operations that don't reference any of our registers
	for i in range(lag):
		code += emitOperation(regs[4], regs[5], regs[6])
	
	finalState	= { regs[0] : values[0] ^ values[1] }

	# Second operation
	code += emitOperation(regs[2], regs[0], str(values[2]))

	finalState[regs[2]] = values[0] ^ values[1] ^ values[2]
	if lag > 0:
		finalState[regs[4]] = values[5] ^ values[6]	# dummy operation

	runTest(initialState, code, finalState)

# Where valuea and valueb are lists.
def vectorXor(original, valuea, valueb, mask):
	result = []

	for laneo, lanea, laneb in zip(original, valuea, valueb):
		if (mask & 0x8000) != 0:
			result += [ lanea ^ laneb ]
		else:
			result += [ laneo ]

		mask <<= 1

	return result
	
def allocateRandomVectorValue():
	return [ random.randint(1, 0xffffffff) for x in range(16) ]

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
def runVectorForwardTest(initialShift, format):
	NUM_STEPS = 6
	vectorRegs = allocateUniqueRegisters('v', NUM_STEPS * 2 + 3)
	bypassReg = vectorRegs[NUM_STEPS * 2 + 1]
	resultReg = vectorRegs[NUM_STEPS * 2 + 2]
	scalarRegs = allocateUniqueRegisters('u', NUM_STEPS + 1)

	scalarOtherOperandReg = scalarRegs[NUM_STEPS]
	scalarOtherOperandVal = allocateUniqueScalarValues(1)[0]
	vectorOtherOperandReg = vectorRegs[NUM_STEPS * 2]
	vectorOtherOperandVal = allocateRandomVectorValue() 

	mask = 0xffff >> initialShift	# positive bignum
	initialState = {
		scalarOtherOperandReg : scalarOtherOperandVal,
		vectorOtherOperandReg : vectorOtherOperandVal,
	}

	bypassValue = [0 for x in range(16)]
	code = ''
	for x in range(NUM_STEPS):
		val1 = allocateRandomVectorValue() 
		val2 = allocateRandomVectorValue()
		initialState[vectorRegs[x * 2]] = val1	
		initialState[vectorRegs[x * 2 + 1]] = val2
		initialState[scalarRegs[x]] = mask
		code += bypassReg + '{' + scalarRegs[x] + '} = ' + \
			vectorRegs[x * 2] + ' ^ ' + vectorRegs[x * 2 + 1] + '\n'
		bypassValue = vectorXor(bypassValue, val1, val2, mask)
		mask >>= 1

	if format == 'vbv':	 # Vector = Bypassed value, vector
		code += emitOperation(resultReg, bypassReg, vectorOtherOperandReg)
		result = vectorXor([0 for x in range(16)], bypassValue, 
			vectorOtherOperandVal, 0xffff)
	elif format == 'vvb':	# Vector = Vector, bypassed value
		code += emitOperation(resultReg, vectorOtherOperandReg, bypassReg)
		result = vectorXor([0 for x in range(16)], vectorOtherOperandVal, 
			bypassValue, 0xffff)
	elif format == 'vbs':	# Vector = Bypassed, scalar value
		code += emitOperation(resultReg, bypassReg, scalarOtherOperandReg)
		result = vectorXor([0 for x in range(16)], bypassValue, 
			[scalarOtherOperandVal for x in range(16)], 0xffff)
	else:
		print 'unknown addressing mode', format
		sys.exit(2)

	finalState = { bypassReg : bypassValue, resultReg : result }

	runTest(initialState, code, finalState)

# Note that we add 8 to the expected PC instead of 4, because the assembler
# puts a jump at the beginning of the program.
def testPcOperand():
	# Immediate, PC as first operand
	regs = allocateUniqueRegisters('u', 1)
	code = ''
	initialPc = random.randint(1, 10)
	for x in range(initialPc):
		code += 'nop\r\n'

	code += emitOperation(regs[0], 'pc', '0xa5')

	runTest({}, code, { regs[0] : ((initialPc * 4) + 8) ^ 0xa5})
	
	# Two registers, PC as first operand
	regs = allocateUniqueRegisters('u', 2)
	values = allocateUniqueScalarValues(1)
	code = ''
	initialPc = random.randint(1, 10)
	for x in range(initialPc):
		code += 'nop\r\n'

	code += emitOperation(regs[0], 'pc', regs[1])
	runTest({ regs[1] : values[0] }, code, { regs[0] : ((initialPc * 4) + 8) 
		^ values[0]})

	# Two registers, PC as second operand
	regs = allocateUniqueRegisters('u', 2)
	values = allocateUniqueScalarValues(1)
	code = ''
	initialPc = random.randint(1, 10)
	for x in range(initialPc):
		code += 'nop\r\n'

	code += emitOperation(regs[0], regs[1], 'pc')
	runTest({ regs[1] : values[0] }, code, { regs[0] : ((initialPc * 4) + 8)
		^ values[0]})


def runForwardTests():
	print 'vector ops'
	for format in [ 'vbv', 'vvb', 'vbs' ]:
		for initialShift in range(5):
			runVectorForwardTest(initialShift, format)

	print 'scalar ops'
	testPcOperand()

	for useParam1 in [False, True]:
		for lag in range(5):
			runScalarForwardTest(lag, useParam1)

	print 'scalar immediate ops'
	for lag in range(5):
		runScalarImmediateForwardTest(lag)

runForwardTests()		
print 'All tests passed'	
