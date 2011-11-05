from runcase import *
from types import *
import struct

def runFpAdderTests(testList):
	regIndex = 0
	inRegs = {}
	outRegs = {}
	code = ''
	for value1, value2, expectedResult in testList:
		outRegs['u' + str(regIndex)] = expectedResult
		inRegs['u' + str(regIndex + 1)] = value1
		inRegs['u' + str(regIndex + 2)] = value2
		code += 'f' + str(regIndex) + ' = f' + str(regIndex + 1) + ' + f' + str(regIndex + 2) + '\n'
		regIndex += 3
		
		if regIndex == 30:
			runTest(inRegs, code, outRegs)			
			inRegs = {}
			outRegs = {}
			code = ''
			regIndex = 0

	if regIndex > 0:
		runTest(inRegs, code, outRegs)			
		inRegs = {}
		outRegs = {}
		code = ''

def runFpScalarCompareTests(testList):
	regIndex = 0
	inRegs = {}
	outRegs = {}
	code = ''
	for value1, operator, value2, expectedResult in testList:
		outRegs['u' + str(regIndex)] = 0xffff if expectedResult else 0
		inRegs['u' + str(regIndex + 1)] = value1
		inRegs['u' + str(regIndex + 2)] = value2
		code += 'u' + str(regIndex) + ' = f' + str(regIndex + 1) + ' ' + operator + ' f' + str(regIndex + 2) + '\n'
		regIndex += 3
		
		if regIndex == 30:
			runTest(inRegs, code, outRegs)			
			inRegs = {}
			outRegs = {}
			code = ''
			regIndex = 0

	if regIndex > 0:
		runTest(inRegs, code, outRegs)			
		inRegs = {}
		outRegs = {}
		code = ''

def runFpVectorCompareTest():
	vec1 = [ (random.random() - 0.5) * 10 for x in range(16) ]
	vec2 = [ (random.random() - 0.5) * 10 for x in range(16) ]
	
	greaterMask = 0
	lessMask = 0
	greaterEqualMask = 0
	lessEqualMask = 0
	for x in range(16):
		greaterMask |= (0x8000 >> x) if vec1[x] > vec2[x] else 0
		lessMask |= (0x8000 >> x) if vec1[x] < vec2[x] else 0
		greaterEqualMask |= (0x8000 >> x) if vec1[x] >= vec2[x] else 0
		lessEqualMask |= (0x8000 >> x) if vec1[x] <= vec2[x] else 0

	runTest({ 	'v0' : [ x for x in vec1 ],
				'v1' : [ x for x in vec2 ] },
		'''
			s2 = vf0 > vf1  
			s3 = vf0 < vf1
			s4 = vf0 >= vf1
			s5 = vf0 <= vf1
		''',
		{ 	'u2' : greaterMask, 
		 	'u3' : lessMask,	 
		 	'u4' : greaterEqualMask,	
		 	'u5' : lessEqualMask })	
			
runFpVectorCompareTest()

runFpAdderTests([
	(17.79, 19.32, 37.11), # Exponents are equal
	(0.34, 44.23, 0x423247ad), # Exponent 2 larger (44.57, adjusted for truncated rounding)
	(44.23, 0.034, 0x42310e55), # Exponent 1 larger
	(-1.0, 5.0, 4.0), # First element is negative and has smaller exponent
	(-5.0, 1.0, -4.0), # First element is negative and has larger exponent		
	(5.0, -1.0, 4.0),  # Second element is negative and has smaller exponent
	(1.0, -5.0, -4.0), # Second element is negative and has larger exponent
	(5.0, 0.0, 5.0), # Zero identity (zero is a special case in IEEE754)
	(0.0, 5.0, 5.0),
	(0.0, 0.0, 0.0),
	(7.0, -7.0, 0.0), # Result is zero
	(1000000.0, 0.0000001, 1000000.0), # Second op is lost because of precision
	(0.0000001, 0.00000001, 0x33ec3923), # Very small number 
	(1000000.0, 10000000.0, 11000000.0)	# Very large number
])

runFpScalarCompareTests([
	(-2.0, '>', -3.0, 1),
	(-3.0, '>', -2.0, 0),
	(17.0, '>', 2.0, 1),
	(2.0, '>', 17.0, 0),
	(5, '>', -17, 1),
	(-17, '>', 5, 0),
	(15, '>', -7, 1),
	(-7, '>', 15, 0),
	(-2.0, '>=', -3.0, 1),
	(-3.0, '>=', -2.0, 0),
	(17.0, '>=', 2.0, 1),
	(2.0, '>=', 17.0, 0),
	(5, '>=', -17, 1),
	(-17, '>=', 5, 0),
	(15, '>=', -7, 1),
	(-7, '>=', 15, 0),
	(-5, '>=', -5, 1),
	(-2.0, '<', -3.0, 0),
	(-3.0, '<', -2.0, 1),
	(17.0, '<', 2.0, 0),
	(2.0, '<', 17.0, 1),
	(5, '<', -17, 0),
	(-17, '<', 5, 1),
	(15, '<', -7, 0),
	(-7, '<', 15, 1),
	(-2.0, '<=', -3.0, 0),
	(-3.0, '<=', -2.0, 1),
	(17.0, '<=', 2.0, 0),
	(2.0, '<=', 17.0, 1),
	(5, '<=', -17, 0),
	(-17, '<=', 5, 1),
	(15, '<=', -7, 0),
	(-7, '<=', 15, 1),
	(-5, '<=', -5, 1),
])
