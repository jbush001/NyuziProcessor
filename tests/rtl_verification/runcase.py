#
# Main test runner
#  1. Assembles a test case based on a description
#  2. Creates initial register values and writes into files
#  3. Invokes verilog simulator
#  4. Parses result and checks correctness
#

import subprocess, tempfile, os, sys, random, struct
from types import *

ASSEMBLER_PATH = '../../tools/asm/assemble'
INTERPRETER_PATH = 'vvp'
HEX_FILENAME = 'WORK/test.hex'
REGISTER_FILENAME = 'WORK/initialregs.hex'
MODEL_PATH = '../../verilog/sim.vvp'

totalTestCount = 0

try:
	os.makedirs('WORK/')
except:
	pass

# Turn a value into something that is acceptable to compare to a register
# result (32 bit unsigned integer)
def sanitizeValue(value):
	if type(value) is FloatType:
		return struct.unpack('I', struct.pack('f', value))[0]
	elif value < 0:
		return ((-value + 1) ^ 0xffffffff) & 0xffffffff
	else:
		return value

def sanitizeRegisters(regs):
	for registerName in regs:
		oldValue = regs[registerName]
		if oldValue == None:
			continue
			
		if type(oldValue) is ListType:
			newValue = [ sanitizeValue(x) for x in oldValue ]
		else:
			newValue = sanitizeValue(oldValue)
		
		regs[registerName] = newValue

def assemble(outputFilename, inputFilename):
	process = subprocess.Popen([ASSEMBLER_PATH, '-o', outputFilename, 
		inputFilename], stdout=subprocess.PIPE)
	output = process.communicate()
	if process.returncode != 0:
		print 'failed to assemble test'
		print 'error:'
		print output[0], output[1]
		print 'source:'
		print open(asmFilename).read()
		sys.exit(2)

def fail(msg, initialRegisters, filename, expectedRegisters, debugOutput):
	print 'FAIL:', msg
	print 'initial state:', initialRegisters
	print 'source:'
	print open(filename).read()
	print
	print 'expected registers:', expectedRegisters
	print 'log:'
	print debugOutput
	sys.exit(2)

def runTestWithFile(initialRegisters, asmFilename, expectedRegisters, checkMemBase = None,
	checkMem = None, cycles = None):

	global totalTestCount

	sanitizeRegisters(initialRegisters)
	sanitizeRegisters(expectedRegisters)

	assemble(HEX_FILENAME, asmFilename)

	#
	# Set up initial register values for verilog simulator
	#
	f = open(REGISTER_FILENAME, 'w')
	
	# scalar regs
	for regIndex in range(32):			
		regName = 'u' + str(regIndex)
		if regName in initialRegisters:
			f.write('%08x\r\n' % initialRegisters[regName])
		else:
			f.write('00000000\r\n')

	for regIndex in range(32):
		regName = 'v' + str(regIndex)
		if regName in initialRegisters:
			value = initialRegisters[regName]
			if len(value) != 16:
				print 'internal test error: bad register width'
				sys.exit(2)

			for lane in value:
				f.write('%08x\r\n' % lane)
		else:
			for i in range(16):
				f.write('00000000\r\n')

	f.close()
	
	#
	# Invoke the verilog simulator
	#
	args = [INTERPRETER_PATH, MODEL_PATH, '+bin=' + HEX_FILENAME, 
		'+initial_regs=' + REGISTER_FILENAME ]

	if False:
		args += ['+trace=fail.vcd']

	if checkMemBase != None:
		args += [ '+memdumpbase=' + hex(checkMemBase)[2:], '+memdumplen=' + hex(len(checkMem) * 4)[2:] ]

	if cycles != None:
		args += [ '+simcycles=' + str(cycles) ]

	process = subprocess.Popen(args, stdout=subprocess.PIPE)
	output = process.communicate()[0]

	#
	# Parse the register descriptions from stdout
	#
	debugOutput = ''
	results = output.split('\n')

	outputIndex = 0
	while results[outputIndex][:10] != 'REGISTERS:':
		debugOutput += results[outputIndex] + '\r\n'
		outputIndex += 1

	outputIndex += 1

	# Check scalar registers
	if expectedRegisters != None:
		for regIndex in range(31):	# Note: don't check PC
			regName = 'u' + str(regIndex)
			regValue = sanitizeValue(int(results[outputIndex], 16))
			if regName in expectedRegisters:
				expected = expectedRegisters[regName]
			elif regName in initialRegisters:
				expected = initialRegisters[regName]
			else:
				expected = 0
				
			# Note that passing None as an expected value means "don't care"
			# the check will be skipped.
			if expected != None and regValue != expected:
				fail('Register ' + regName + ' should be ' + str(expected) 
					+ ' actual '  + str(regValue), initialRegisters, asmFilename, 
					expectedRegisters, debugOutput)
		
			outputIndex += 1
			
		outputIndex += 1	# Skip PC
		
		# Check vector registers
		for regIndex in range(32):
			regName = 'v' + str(regIndex)
			regValue = []
			for lane in range(16):
				regValue += [ sanitizeValue(int(results[outputIndex], 16)) ]
				outputIndex += 1
				
			if regName in expectedRegisters:
				expected = expectedRegisters[regName]
			elif regName in initialRegisters:
				expected = initialRegisters[regName]
			else:
				expected = [ 0 for i in range(16) ]
	
			# Note that passing None as an expected value means "don't care"
			# the check will be skipped.
			if expected != None and regValue != expected:
				fail('Register ' + regName + ' should be ' + str(expected) 
					+ ' actual ' + str(regValue), initialRegisters, asmFilename, 
					expectedRegisters, debugOutput)
	else:
		outputIndex += 32 + 16 * 32

	# Check memory
	if checkMemBase != None:
		if results[outputIndex] != 'MEMORY:':
			print 'error from simulator output: no memory line', results[outputIndex]
			sys.exit(2)
			
		outputIndex += 1
		for index, loc in enumerate(range(len(checkMem))):
			actual = int(results[outputIndex], 16)
			if actual != checkMem[index]:
				fail('Memory %x should be %08x actual %08x' % (checkMemBase + index, 
					checkMem[index], actual), initialRegisters, asmFilename, 
					expectedRegisters, debugOutput)

			outputIndex += 1
	
	totalTestCount += 1
	print 'PASS', totalTestCount
	

#
# expectedRegisters/initialRegisters = [{regIndex: value}, (regIndex, value), ...]
# All final registers, unless otherwise specified are checked against 
# the initial registers and any differences are reported as an error.
#
def runTest(initialRegisters, codeSnippet, expectedRegisters, checkMemBase = None, 
	checkMem = None, cycles = None):

	asmFilename = 'WORK/test.asm'

	# 1. Assemble the code for the test case
	f = open(asmFilename, 'w')
	f.write('_start ')
	f.write(codeSnippet)
	f.write("\n___done goto ___done\n")
	f.close()

	runTestWithFile(initialRegisters, asmFilename, expectedRegisters, checkMemBase,
		checkMem, cycles)

	
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
