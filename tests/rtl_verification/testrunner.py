#!/usr/bin/python
#
# Top level test runner
#

import subprocess, tempfile, os, sys, random, struct, inspect
from testcase import TestCase
from types import *

ASSEMBLER_PATH = '../../tools/asm/assemble'
INTERPRETER_PATH = 'vvp'
HEX_FILENAME = 'WORK/test.hex'
REGISTER_FILENAME = 'WORK/initialregs.hex'
MODEL_PATH = '../../verilog/sim.vvp'

try:
	os.makedirs('WORK/')
except:
	pass

def formatVector(vec):
	str = ''
	for x in vec:
		str += '%08x ' % x
		
	return str
	

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
	if regs == None:
		return None

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
		print open(inputFilename).read()
		return False

	return True

def runSimulator(program, regFile, checkMemBase, checkMemLength):
	args = [INTERPRETER_PATH, MODEL_PATH, '+bin=' + program, 
		'+initial_regs=' + regFile ]

	if 'VVPTRACE' in os.environ:
		args += ['+trace=trace.vcd']

	if checkMemBase != None:
		args += [ '+memdumpbase=' + hex(checkMemBase)[2:], '+memdumplen=' + hex(checkMemLength)[2:] ]

	args += [ '+simcycles=1000' ]

	try:
		process = subprocess.Popen(args, stdout=subprocess.PIPE)
		output = process.communicate()[0]
	except:
		print 'killing simulator process'
		process.kill()
		raise
	
	return output.split('\n')

def printFailureMessage(msg, initialRegisters, filename, expectedRegisters, debugOutput):
	print 'FAIL:', msg
	print 'initial state:'
	for key in initialRegisters:
		print '  ' + key + ' ' + hex(initialRegisters[key])

	print 'source:'
	print open(filename).read()
	print
	print 'expected registers:' 
	for key in expectedRegisters:
		if expectedRegisters[key]:
			print '  ' + key + ' ' + hex(expectedRegisters[key])

	print 'log:'
	print debugOutput

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
				return False

			for lane in value:
				f.write('%08x\r\n' % lane)
		else:
			for i in range(16):
				f.write('00000000\r\n')

	f.close()	
	return True

def parseSimResults(results):
	log = ''
	scalarRegs = []
	vectorRegs = []
	memory = None
	halted = False
	
	outputIndex = 0
	while outputIndex < len(results) and results[outputIndex][:10] != 'REGISTERS:':
		if results[outputIndex].find('***HALTED***') != -1:
			halted = True
			
		log += results[outputIndex] + '\r\n'
		outputIndex += 1

	if not halted:
		print 'Simulation did not halt normally'	# Perhaps should be failure
		sys.exit(1)

	if outputIndex == len(results):
		return log, None, None, None

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
			val = results[outputIndex]
			if val != 'xxxxxxxx':
				regval += [ sanitizeValue(int(val, 16)) ]
			else:
				regval += [ val ]

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
	checkMem = None):

	global totalTestCount

	sanitizeRegisters(initialRegisters)
	sanitizeRegisters(expectedRegisters)

	if not assemble(HEX_FILENAME, asmFilename):
		return False

	if not makeInitialRegisterFile(REGISTER_FILENAME, initialRegisters):
		return False
	
	results = runSimulator(HEX_FILENAME, REGISTER_FILENAME, checkMemBase,
		len(checkMem) * 4 if checkMem != None else 0)		
	log, scalarRegs, vectorRegs, memory = parseSimResults(results)
	if scalarRegs == None or vectorRegs == None:
		print 'Simulator aborted:', log
		return False

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
				printFailureMessage('Register ' + regName + ' should be ' + hex(expected) 
					+ ' actual '  + hex(scalarRegs[regIndex]), initialRegisters, asmFilename, 
					expectedRegisters, log)
				return False
		
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
				printFailureMessage('Register ' + regName + '\nshould be ' + formatVector(expected) 
					+ '\nactual    ' + formatVector(vectorRegs[regIndex]), initialRegisters, asmFilename, 
					expectedRegisters, log)
				return False

	# Check memory
	if checkMemBase != None:
		for index, loc in enumerate(range(len(checkMem))):
			if memory[index] != checkMem[index]:
				printFailureMessage('Memory %x should be %08x actual %08x' % (checkMemBase + index, 
					checkMem[index], memory[index]), initialRegisters, asmFilename, 
					expectedRegisters, log)
				return False

	return True

#
# expectedRegisters/initialRegisters = [{regIndex: value}, (regIndex, value), ...]
# All final registers, unless otherwise specified are checked against 
# the initial registers and any differences are reported as an error.
#
def runTest(initialRegisters, codeSnippet, expectedRegisters, checkMemBase = None, 
	checkMem = None):

	asmFilename = 'WORK/test.asm'

	# 1. Assemble the code for the test case
	f = open(asmFilename, 'w')
	if codeSnippet.find('_start') == -1:
		f.write('_start ')

	f.write(codeSnippet)
	f.write('''
		___done nop
				nop
				nop
				nop
				nop
				cr31 = s0		; Writing any value will halt simulation
				nop
				nop
				nop
				nop
				nop
				nop
				nop
				nop
			''')
	f.close()

	return runTestWithFile(initialRegisters, asmFilename, expectedRegisters, checkMemBase,
		checkMem)


def buildTestCaseList():
	testList = []
	for file in os.listdir('.'):
		if file[-3:] == '.py':
			if file[:-3] == 'testrunner':
				continue	# Don't load myself

			try:
				module = __import__(file[:-3])	
			except Exception as inst:
				print 'Error: ', inst
				continue
				
			if module != None:
				for className, classObj in inspect.getmembers(module):
					if type(classObj) == ClassType:
						if TestCase in classObj.__bases__:
							# Import this class
							for methodName, methodObj in inspect.getmembers(classObj):
								if type(methodObj) == MethodType and methodName[:5] == 'test_':
									testList += [(className, methodName[5:], methodObj)]

	return testList


allTests = buildTestCaseList()
if len(sys.argv) == 1:
	testsToRun = allTests
else:
	testsToRun = []
	for testModule, testCase, object in allTests:
		if testCase == sys.argv[1]:
			testsToRun += [ (testModule, testCase, object) ]
		elif testModule == sys.argv[1]:
			testsToRun += [ (testModule, testCase, object) ]

if len(testsToRun) == 0:
	print 'Couldn\'t find any tests to run'
	sys.exit(2)

stopOnFail = True
failCount = 0
for testModuleName, testCaseName, object in testsToRun:
	testParams = object.__func__()
	if type(testParams) == ListType:
		print 'running ' + testCaseName + '(' + str(len(testParams)) + ' tests)',
		for initial, code, expected, memBase, memValue, cycles in testParams:
			# XXX cycles is ignored
			if not runTest(initial, code, expected, memBase, memValue):
				print 'FAIL'
				failCount += 1
				if stopOnFail:
					sys.exit(1)
			else:
				print '.',
				
		print ''
	else:
		print 'running ' + testCaseName,
		initial, code, expected, memBase, memValue, cycles = testParams
		# XXX cycles is ignored
		if not runTest(initial, code, expected, memBase, memValue):
			print 'FAIL'
			failCount += 1
			if stopOnFail:
				sys.exit(1)
		else:
			print 'PASS'
	

print 'Ran', len(testsToRun), 'tests total.',
if failCount == 0:
	print 'All tests passed.'
else:
	print 'There were', failCount, ' failures.'
