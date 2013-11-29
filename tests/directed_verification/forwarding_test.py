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

#
# Test result forwarding logic (aka bypassing)
#

import random, sys, string
from testgroup import *

def emitOperation(dest, src1, src2):
	return 'xor ' + dest + ', ' + src1 + ', ' + src2 + '\n'

class ForwardingTests(TestGroup):

	#
	# This validates that:
	#  1. Scalar registers are forwarded from every stage in the pipeline
	#  2. Only the most recent value is forwarded, even when other writes to 
	#	  a register are in the pipeline
	#  3. Writes to unrelated registers are not forwarded
	# Tests all four strands, one at a time.
	#
	# To do:
	#  1. Ensure that writes to vector registers with the same index are not 
	#	  forwarded.
	#
	def test_scalarForwarding():
		tests = []
	
		for useParam1 in [False, True]:
			for lag in range(5):
				# Generate 3 random scalar values
				regs = [ 's' + str(x) for x in range(11) ]	# One extra scratchpad
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
			
				code += '''
					; Stop myself and start next thread.
					; When the last thread has run, the simulation will halt
					getcr s10, 30
					shl s10, s10, 1
					setcr s10, 30
				'''
				
				finalState['s10'] = None
			
				tests += [ (initialState, code, finalState, None, None, None) ]

		return tests	

	# This tests all four strands, one at a time	
	# Todo: Add test for v, v, imm
	def test_immediateForwardTest():
		tests = []
	
		for lag in range(5):
			regs = [ 's' + str(x) for x in range(7) ]	# s0 - s6
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

			code += '''
				; Stop myself and start next thread.
				; When the last thread has run, the simulation will halt
				getcr s7, 30
				shl s7, s7, 1
				setcr s7, 30
			'''
		
			finalState[regs[2]] = values[0] ^ values[1] ^ values[2]
			if lag > 0:
				finalState[regs[4]] = values[5] ^ values[6]	# dummy operation
		
			finalState['s7'] = None
		
			tests += [ (initialState, code, finalState, None, None, None) ]

		return tests
	
		
	
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
	#  4. Test all four strands
	#
	def test_vectorForwarding():
		NUM_STEPS = 6
		
		testList = []

		for format in [ 'vbv', 'vvb', 'vbs' ]:
			for initialShift in range(5):
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
			
				bypassValue = [0 for x in range(16)]
				code = ''
				for x in range(NUM_STEPS):
					val1 = allocateRandomVectorValue() 
					val2 = allocateRandomVectorValue()
					initialState[vectorRegs[x * 2]] = val1	
					initialState[vectorRegs[x * 2 + 1]] = val2
					initialState[scalarRegs[x]] = mask
					code += 'xor_mask ' + bypassReg + ', ' + scalarRegs[x] + ', ' + \
						vectorRegs[x * 2] + ', ' + vectorRegs[x * 2 + 1] + '\n'
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
			
				finalState = { 't0' + bypassReg : bypassValue, 't0' + resultReg : result }
			
				testList += [ (initialState, code, finalState, None, None, None) ]
			
		return testList
	
	def DISABLED_test_pcOperand1():
		# Immediate, PC as first operand
		regs = allocateUniqueRegisters('s', 1)
		code = '.align 128\n'
		initialPc = random.randint(1, 10)
		for x in range(initialPc):
			code += 'nop\r\n'
	
		code += emitOperation(regs[0], 'pc', '0xa5')
	
		return ({}, code, { 't0' + regs[0] : ((initialPc * 4) + 128) ^ 0xa5}, None, None, None)

	def DISABLED_test_pcOperand2():
		# Two registers, PC as first operand
		regs = allocateUniqueRegisters('s', 2)
		values = allocateUniqueScalarValues(1)
		code = '.align 128\n'
		initialPc = random.randint(1, 10)
		for x in range(initialPc):
			code += 'nop\r\n'
	
		code += emitOperation(regs[0], 'pc', regs[1])
		return ({ regs[1] : values[0] }, code, { 't0' + regs[0] : ((initialPc * 4) + 128) 
			^ values[0]}, None, None, None)
	
	def DISABLED_test_pcOperand3():
		# Two registers, PC as second operand
		regs = allocateUniqueRegisters('s', 2)
		values = allocateUniqueScalarValues(1)
		code = '.align 128\n'
		initialPc = random.randint(1, 10)
		for x in range(initialPc):
			code += 'nop\r\n'
	
		code += emitOperation(regs[0], regs[1], 'pc')
		return ({ regs[1] : values[0] }, code, { 't0' + regs[0] : ((initialPc * 4) + 128)
			^ values[0]}, None, None, None)
