#
# Main test runner
#  1. Assembles a test case based on a description
#  2. Creates initial register values and writes into files
#  3. Invokes verilog simulator
#  4. Parses result and checks correctness
#

import subprocess, tempfile, os, sys
import random

assemblerPath = '../../tools/asm/assemble'
interpreterPath = 'vvp'

try:
	os.makedirs('WORK/')
except:
	pass
	
hexFilename = 'WORK/hex'
asmFilename = 'WORK/asm'
scalarRegisterFilename = 'WORK/scalarRegs'
vectorRegisterFilename = 'WORK/vectorRegs'
totalTestCount = 0

#
# Return a list of registers, where there are no duplicates in the list.
# e.g. ['r1', 'r7', 'r4']
# Note, this will not use r0
#
def allocateUniqueRegisters(type, numRegisters):
	regs = []
	while len(regs) < numRegisters:
		reg = type + str(random.randint(1, 30))	
		if reg not in regs:
			regs.append(reg)
			
	return regs

#
# Allocate a list of values, where there are no duplicates in the list
#
def allocateUniqueScalarValues(numValues):
	values = []
	while len(values) < numValues:
		value = random.randint(1, 0xffffffff)
		if value not in values:
			values.append(value)
			
	return values

#
# finalRegisters/initialRegisters = [{regIndex: value}, (regIndex, value), ...]
# All final registers, unless otherwise specified are checked against 
# the initial registers and any differences are reported as an error.
#
def runTest(initialRegisters, codeSnippet, finalRegisters):
	global binaryFilename
	global hexFilename
	global asmFilename
	global outputFilename
	global scalarRegisterFilename
	global vectorRegisterFilename
	global totalTestCount

	# 1. Assemble the code for the test case
	f = open(asmFilename, 'w')
	f.write('_start ')
	f.write(codeSnippet)
	f.close()

	process = subprocess.Popen([assemblerPath, '-o', hexFilename, 
		asmFilename], stdout=subprocess.PIPE)
	output = process.communicate()
	if process.returncode != 0:
		print 'failed to assemble test:'
		print codeSnippet
		print 'error:'
		print output[0], output[1]
		sys.exit(2)
	
	# 2. Set up scalar register block
	f = open(scalarRegisterFilename, 'w')
	for regIndex in range(31):
		regName = 'u' + str(regIndex)
		if regName in initialRegisters:
			f.write('%08x\r\n' % initialRegisters[regName])
		else:
			f.write('00000000\r\n')
	
	f.close()
	
	# 3. Set up vector register block
	f = open(vectorRegisterFilename, 'w')
	for regIndex in range(32):
		regName = 'v' + str(regIndex)
		if regName in initialRegisters:
			value = initialRegisters[regName]
			for lane in value:
				f.write('%08x\r\n' % lane)
		else:
			for i in range(16):
				f.write('00000000\r\n')

	f.close()
	
	# 4. Invoke the verilog simulator
	process = subprocess.Popen([interpreterPath, '../../verilog/sim.vvp', '+bin=' + hexFilename, 
		'+sreg=' + scalarRegisterFilename, '+vreg=' + vectorRegisterFilename,
		'+trace=fail.vcd'], stdout=subprocess.PIPE)
	output = process.communicate()[0]

	# 5. Parse the register descriptions from stdout
	debugOutput = ''
	results = output.split('\n')
	outputIndex = 0
	while results[outputIndex][:10] != 'REGISTERS:':
		debugOutput += results[outputIndex] + '\r\n'
		outputIndex += 1

	outputIndex += 1

	# Check scalar registers
	for regIndex in range(31):	# Note: don't check PC
		regName = 'u' + str(regIndex)
		regValue = int(results[outputIndex], 16)
		if regName in finalRegisters:
			expected = finalRegisters[regName]
		elif regName in initialRegisters:
			expected = initialRegisters[regName]
		else:
			expected = 0
			
		if regValue != expected:
			print 'FAIL'
			print 'Register %s should be %08x actual %08x' % (regName, expected, regValue)
			print 'initial state:', initialRegisters
			print 'code:', codeSnippet
			print 'final state:', finalRegisters
			print 'log:'
			print debugOutput
			sys.exit(2)
	
		outputIndex += 1
		
	outputIndex += 1	# Skip PC
		
	# Check vector registers
	for regIndex in range(32):
		regName = 'v' + str(regIndex)
		regValue = []
		for lane in range(16):
			regValue += [ int(results[outputIndex], 16) ]
			outputIndex += 1
			
		if regName in finalRegisters:
			expected = finalRegisters[regName]
		elif regName in initialRegisters:
			expected = initialRegisters[regName]
		else:
			expected = [0 for i in range(16) ]

		if regValue != expected:
			print 'FAIL'
			print 'Register ', regName, 'should be'
			print expected 
			print 'actual'
			print regValue
			print 'initial state:', initialRegisters
			print 'code:', codeSnippet
			print 'final state:', finalRegisters
			print 'log:'
			print debugOutput
			sys.exit(2)
	
	totalTestCount += 1
	print 'PASS', totalTestCount
	
