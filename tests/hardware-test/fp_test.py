from runcase import *
from types import *
import struct

def runFpAdderTests(testList):
	regIndex = 0
	inRegs = {}
	outRegs = {}
	code = ''
	for value1, value2, expectedResult in testList:
		if type(value1) is FloatType:
			# Convert to a raw integer value
			value1 = struct.unpack('I', struct.pack('f', value1))[0]
	
		if type(value2) is FloatType:
			# Convert to a raw integer value
			value2 = struct.unpack('I', struct.pack('f', value2))[0]
	
		if type(expectedResult) is FloatType:
			# Convert to a raw integer value
			expectedResult = struct.unpack('I', struct.pack('f', expectedResult))[0]

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

	if regIndex > 0:
		runTest(inRegs, code, outRegs)			
		inRegs = {}
		outRegs = {}
		code = ''

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
