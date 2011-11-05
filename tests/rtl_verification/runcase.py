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

def runSimulator(program, regFile, checkMemBase, checkMemLength, cycles):
	args = [INTERPRETER_PATH, MODEL_PATH, '+bin=' + program, 
		'+initial_regs=' + regFile ]

	if False:
		args += ['+trace=fail.vcd']

	if checkMemBase != None:
		args += [ '+memdumpbase=' + hex(checkMemBase)[2:], '+memdumplen=' + hex(checkMemLength)[2:] ]

	if cycles != None:
		args += [ '+simcycles=' + str(cycles) ]

	process = subprocess.Popen(args, stdout=subprocess.PIPE)
	output = process.communicate()[0]
	return output.split('\n')

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

def makeInitialRegisterFile(filename, initialRegisters):
	f = open(filename, 'w')
	
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

def parseSimResults(results):
	log = ''
	scalarRegs = []
	vectorRegs = []
	memory = None
	
	outputIndex = 0
	while results[outputIndex][:10] != 'REGISTERS:':
		log += results[outputIndex] + '\r\n'
		outputIndex += 1

	outputIndex += 1

	for x in range(32):
		val = results[outputIndex]
		if val != 'xxxxxxxx':
			scalarRegs += [ sanitizeValue(int(val, 16)) ]
		else:
			scalarRegs += [ val ]
			
		outputIndex += 1

	for x in range(32):
		regval = []
		for y in range(16):
			regval += [ sanitizeValue(int(results[outputIndex], 16)) ]
			outputIndex += 1
		
		vectorRegs += [ regval ]		

	if outputIndex < len(results) and results[outputIndex] == 'MEMORY:':
		memory = []
		outputIndex += 1
		while outputIndex < len(results) and results[outputIndex] != '':
			memory += [ int(results[outputIndex], 16) ]
			outputIndex += 1
	
	return log, scalarRegs, vectorRegs, memory
	

def runTestWithFile(initialRegisters, asmFilename, expectedRegisters, checkMemBase = None,
	checkMem = None, cycles = None):

	global totalTestCount

	sanitizeRegisters(initialRegisters)
	sanitizeRegisters(expectedRegisters)

	assemble(HEX_FILENAME, asmFilename)

	makeInitialRegisterFile(REGISTER_FILENAME, initialRegisters)
	
	results = runSimulator(HEX_FILENAME, REGISTER_FILENAME, checkMemBase,
		len(checkMem) * 4 if checkMem != None else 0, cycles)		

	log, scalarRegs, vectorRegs, memory = parseSimResults(results)

	if expectedRegisters != None:
		# Check scalar registers
		for regIndex in range(31):	# Note: don't check PC
			regName = 'u' + str(regIndex)
			if regName in expectedRegisters:
				expected = expectedRegisters[regName]
			elif regName in initialRegisters:
				expected = initialRegisters[regName]
			else:
				expected = 0
				
			# Note that passing None as an expected value means "don't care"
			# the check will be skipped.
			if expected != None and scalarRegs[regIndex] != expected:
				fail('Register ' + regName + ' should be ' + str(expected) 
					+ ' actual '  + str(regValue), initialRegisters, asmFilename, 
					expectedRegisters, debugOutput)
		
		# Check vector registers
		for regIndex in range(32):
			regName = 'v' + str(regIndex)
			if regName in expectedRegisters:
				expected = expectedRegisters[regName]
			elif regName in initialRegisters:
				expected = initialRegisters[regName]
			else:
				expected = [ 0 for i in range(16) ]
	
			# Note that passing None as an expected value means "don't care"
			# the check will be skipped.
			if expected != None and vectorRegs[regIndex] != expected:
				fail('Register ' + regName + ' should be ' + str(expected) 
					+ ' actual ' + str(regValue), initialRegisters, asmFilename, 
					expectedRegisters, debugOutput)

	# Check memory
	if checkMemBase != None:
		for index, loc in enumerate(range(len(checkMem))):
			if memory[index] != checkMem[index]:
				fail('Memory %x should be %08x actual %08x' % (checkMemBase + index, 
					checkMem[index], memory[index]), initialRegisters, asmFilename, 
					expectedRegisters, debugOutput)
	
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
