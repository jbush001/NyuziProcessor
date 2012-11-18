#!/usr/bin/python
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
# Top level test runner
#

import subprocess, tempfile, os, sys, random, struct, inspect, types
from testgroup import TestGroup
from types import *

ASSEMBLER_PATH = '../../tools/assembler/assemble'
INTERPRETER_PATH = 'vvp'
HEX_FILENAME = 'WORK/test.hex'
REGISTER_FILENAME = 'WORK/initialregs.hex'
MEMDUMP_PATH = 'WORK/memory.bin'
MODEL_PATH = '../../rtl/sim.vvp'

class TestException(Exception):
	def __init__(self, value):
		self.value = value

	def __str__(self):
		return repr(self.value)		

try:
	os.makedirs('WORK/')
except:
	pass

def formatVector(vec):
	str = ''
	for x in vec:
		if type(x) is StringType:
			str += ' ' + x
		else:
			str += '%08x ' % x
		
	return str

#
# Turn a value into something that is acceptable to compare to a register
# result (32 bit unsigned integer)
#
def sanitizeValue(value):
	if type(value) is FloatType:
		return struct.unpack('I', struct.pack('f', value))[0]
	elif value < 0:
		return ((-value ^ 0xffffffff) + 1) & 0xffffffff
	else:
		return value

#
# Given a set of register values that are passed in from a test case,
# Make sure that they are all converted to 32-bit unsigned integers that
# can be passed to the simulator.  Convert floating point values to 
# their raw form and signed values to two's complement form.
#
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
		raise TestException('assemble error')

def runSimulator(program, regFile, checkMemBase, checkMemLength, showRegs):
	args = [INTERPRETER_PATH, MODEL_PATH, '+bin=' + program, 
		'+initial_regs=' + regFile, "+autoflushl2=1" ]

	if 'VVPTRACE' in os.environ:
		args += ['-lxt2', '+trace=trace.lxt']

	if checkMemBase != None:
		args += [ '+memdumpfile=' + MEMDUMP_PATH, '+memdumpbase=' + hex(checkMemBase)[2:], '+memdumplen=' + hex(checkMemLength)[2:] ]

	if showRegs:
		args += [ '+regtrace=1' ]

	if 'SIMCYCLES' in os.environ:
		args += [ '+simcycles=' + os.environ['SIMCYCLES'] ]
	else:
		args += [ '+simcycles=40000' ]

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
		value = initialRegisters[key]
		if isinstance(value, types.ListType):
			print '  ' + key + ' ' + str([ hex(element) for element in value ])
		else:
			print '  ' + key + ' ' + hex(value)

	print 'source:'
	print open(filename).read()
	print
	if expectedRegisters:
		print 'expected registers:' 
		for key in expectedRegisters:
			if expectedRegisters[key]:
				value = expectedRegisters[key]
				if isinstance(value, types.ListType):
					print '  ' + key + ' ' + str([ hex(element) for element in value ])
				else:
					print '  ' + key + ' ' + hex(value)

	print 'log:'
	print debugOutput

def makeInitialRegisterFile(filename, initialRegisters):
	VECTOR_OFFSET = 32 * 4
	registerValues = [ 0 for x in range(32 * 4 + 32 * 4 * 16) ]

	for target in initialRegisters:
		# Is there a thread specifier?
		if target[0] == 't':
			strands = [ ord(target[1]) - ord('0') ]
			regSpecifier = target[2:]
		else:
			strands = [0,1,2,3]
			regSpecifier = target

		# Register index
		regIndex = int(regSpecifier[1:])
		if regSpecifier[0] == 'v':
			for laneIndex, laneValue  in enumerate(initialRegisters[target]):
				for strand in strands:
					registerValues[VECTOR_OFFSET + (strand * 32 * 16) + (regIndex * 16) + laneIndex] = laneValue 
		
		elif regSpecifier[0] == 's' or regSpecifier[0] == 'u':
			for strand in strands:
				registerValues[strand * 32 + regIndex] = initialRegisters[target]
		else:
			raise TestException('Bad Register Type' + reg)

	f = open(filename, 'w')
	for value in registerValues:
		f.write('%08x\r\n' % value)

	f.close()

def parseSimResults(results, showRegs):
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
		return log, None, None

	if outputIndex == len(results):
		return log, None, None

	outputIndex += 1

	for strandId in range(4):
		strandRegs = []
		for x in range(32):
			val = results[outputIndex]
			if val != 'xxxxxxxx':
				strandRegs += [ sanitizeValue(int(val, 16)) ]
			else:
				strandRegs += [ val ]
				
			outputIndex += 1

		scalarRegs += [ strandRegs ]

	for strandId in range(4):
		strandRegs = []
		for x in range(32):
			regval = []
			for y in range(16):
				val = results[outputIndex]
				if val != 'xxxxxxxx':
					regval += [ sanitizeValue(int(val, 16)) ]
				else:
					regval += [ val ]
	
				outputIndex += 1
			
			strandRegs += [ regval ]		
			
		vectorRegs += [ strandRegs ]
	
	return log, scalarRegs, vectorRegs

def runTestWithFile(initialRegisters, asmFilename, expectedRegisters, checkMemBase = None,
	checkMem = None):

	global totalTestCount

	sanitizeRegisters(initialRegisters)
	sanitizeRegisters(expectedRegisters)

	assemble(HEX_FILENAME, asmFilename)
	makeInitialRegisterFile(REGISTER_FILENAME, initialRegisters)
	
	showRegs = 'SHOWREGS' in os.environ

	results = runSimulator(HEX_FILENAME, REGISTER_FILENAME, checkMemBase,
		len(checkMem) * 4 if checkMem != None else 0, showRegs)		
	log, scalarRegs, vectorRegs = parseSimResults(results, showRegs)
	if scalarRegs == None or vectorRegs == None:
		print 'Simulator aborted:', log
		raise TestException('simulator aborted')

	if expectedRegisters != None:
		for strandId in range(4):
			# Check scalar registers
			for regIndex in range(31):	# Note: don't check PC
				extendedName = 't' + str(strandId) + 'u' + str(regIndex)
				regName = 'u' + str(regIndex)
				if extendedName in expectedRegisters:
					expected = expectedRegisters[extendedName]
				elif regName in expectedRegisters:
					expected = expectedRegisters[regName]
				elif extendedName in initialRegisters:
					expected = initialRegisters[extendedName]
				elif regName in initialRegisters:
					expected = initialRegisters[regName]
				else:
					expected = 0
	
				# Note that passing None as an expected value means "don't care"
				# the check will be skipped.
				actualValue = scalarRegs[strandId][regIndex]
				if expected != None and actualValue != expected:
					if isinstance(actualValue, str):
						actualString = actualValue
					else:
						actualString = hex(actualValue)
						
					printFailureMessage('Strand ' + str(strandId) + ' register ' + regName + ' should be ' + hex(expected) 
						+ ' actual '  + actualString, initialRegisters, asmFilename, 
						expectedRegisters, log)
					raise TestException('test failure')
		
			# Check vector registers
			for regIndex in range(32):
				extendedName = 't' + str(strandId) + 'v' + str(regIndex)
				regName = 'v' + str(regIndex)
				if extendedName in expectedRegisters:
					expected = expectedRegisters[extendedName]
				elif regName in expectedRegisters:
					expected = expectedRegisters[regName]
				elif extendedName in initialRegisters:
					expected = initialRegisters[extendedName]
				elif regName in initialRegisters:
					expected = initialRegisters[regName]
				else:
					expected = [ 0 for i in range(16) ]
		
				# Note that passing None as an expected value means "don't care"
				# the check will be skipped.
				actualValue = vectorRegs[strandId][regIndex]
				if expected != None and actualValue != expected:
					printFailureMessage('Strand ' + str(strandId) + ' register ' + regName + '\nshould be ' + formatVector(expected) 
						+ '\nactual    ' + formatVector(actualValue), initialRegisters, asmFilename, 
						expectedRegisters, log)
					raise TestException('test failure')

	# Check memory
	if checkMemBase != None:
		fp = open(MEMDUMP_PATH, 'rb')
		memory = fp.read()
		fp.close()

		for index, loc in enumerate(range(len(checkMem))):
			actual = ord(memory[index])
			if actual != checkMem[index]:
				printFailureMessage('Memory %x should be %02x actual %02x' % (checkMemBase + index, 
					checkMem[index], actual), initialRegisters, asmFilename, 
					expectedRegisters, log)
				raise TestException('test failure')

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
	if codeSnippet.find('_start:') == -1:
		f.write('_start: ')

	f.write(codeSnippet)
	f.write('''
		 ___done: nop nop nop nop nop nop nop nop
		 		nop nop nop nop nop nop nop nop
		 		cr31 = s0
		''')

	f.close()

	runTestWithFile(initialRegisters, asmFilename, expectedRegisters, checkMemBase,
		checkMem)


def buildTestCaseList():
	testList = []
	for file in os.listdir('.'):
		if file[-3:] == '.py':
			if file[:-3] == 'runtest':
				continue	# Don't load myself

			try:
				module = __import__(file[:-3])	
			except Exception as inst:
				print 'Error: ', inst
				continue
				
			if module != None:
				for className, classObj in inspect.getmembers(module):
					if type(classObj) == ClassType:
						if TestGroup in classObj.__bases__:
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
			try:
				runTest(initial, code, expected, memBase, memValue)
			except Exception as exc:
				print 'FAIL:', exc
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
		try:
			runTest(initial, code, expected, memBase, memValue)
		except TestException as exc:
			print 'FAIL:', exc
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
