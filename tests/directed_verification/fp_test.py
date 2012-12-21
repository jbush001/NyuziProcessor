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

from testgroup import *
from types import *
import struct

class FloatingPointTests(TestGroup):
	def test_floatingPointAddition():
		testValues = [
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
			(1000000.0, 10000000.0, 11000000.0),	# Very large number
			(-0.0, 2.323, 2.323),	# negative zero
			(2.323, -0.0, 2.323)	# negative zero
		]

		cases = []
	
		regIndex = 0
		inRegs = {}
		outRegs = {}
		code = ''
		for value1, value2, expectedResult in testValues:
			outRegs['t0u' + str(regIndex)] = expectedResult
			inRegs['u' + str(regIndex + 1)] = value1
			inRegs['u' + str(regIndex + 2)] = value2
			code += 'f' + str(regIndex) + ' = f' + str(regIndex + 1) + ' + f' + str(regIndex + 2) + '\n'
			regIndex += 3
			
			if regIndex == 30:
				cases +=  [ (inRegs, code, outRegs, None, None, None) ]
				inRegs = {}
				outRegs = {}
				code = ''
				regIndex = 0
	
		if regIndex > 0:
			cases +=  [ (inRegs, code, outRegs, None, None, None) ]
			inRegs = {}
			outRegs = {}
			code = ''

		return cases
	
	def test_floatingPointScalarCompare():
		testValues = [
			(-2.0, '>', -3.0, 1),
			(-3.0, '>', -2.0, 0),
			(17.0, '>', 2.0, 1),
			(2.0, '>', 17.0, 0),
			(5.0, '>', -17.0, 1),
			(-17.0, '>', 5.0, 0),
			(15.0, '>', -7.0, 1),
			(-7.0, '>', 15.0, 0),
			(-2.0, '>=', -3.0, 1),
			(-3.0, '>=', -2.0, 0),
			(17.0, '>=', 2.0, 1),
			(2.0, '>=', 17.0, 0),
			(5.0, '>=', -17.0, 1),
			(-17.0, '>=', 5.0, 0),
			(15.0, '>=', -7.0, 1),
			(-7.0, '>=', 15.0, 0),
			(-5.0, '>=', -5.0, 1),
			(-2.0, '<', -3.0, 0),
			(-3.0, '<', -2.0, 1),
			(17.0, '<', 2.0, 0),
			(2.0, '<', 17.0, 1),
			(5.0, '<', -17.0, 0),
			(-17.0, '<', 5.0, 1),
			(15.0, '<', -7.0, 0),
			(-7.0, '<', 15.0, 1),
			(-2.0, '<=', -3.0, 0),
			(-3.0, '<=', -2.0, 1),
			(17.0, '<=', 2.0, 0),
			(2.0, '<=', 17.0, 1),
			(5.0, '<=', -17.0, 0),
			(-17.0, '<=', 5.0, 1),
			(15.0, '<=', -7.0, 0),
			(-7.0, '<=', 15.0, 1),
			(-5.0, '<=', -5.0, 1),
			(float('nan'), '<=', 5.0, 0),
			(5.0, '<=', float('nan'), 0),
		]
	
		cases = []
		regIndex = 0
		inRegs = {}
		outRegs = {}
		code = ''
		for value1, operator, value2, expectedResult in testValues:
			outRegs['t0u' + str(regIndex)] = 0xffff if expectedResult else 0
			inRegs['u' + str(regIndex + 1)] = value1
			inRegs['u' + str(regIndex + 2)] = value2
			code += 'u' + str(regIndex) + ' = f' + str(regIndex + 1) + ' ' + operator + ' f' + str(regIndex + 2) + '\n'
			regIndex += 3
			
			if regIndex == 30:
				cases +=  [ (inRegs, code, outRegs, None, None, None) ]
				inRegs = {}
				outRegs = {}
				code = ''
				regIndex = 0
	
		if regIndex > 0:
			cases +=  [ (inRegs, code, outRegs, None, None, None) ]
			inRegs = {}
			outRegs = {}
			code = ''
			
		return cases
	
	def test_floatingPointVectorCompare():
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
	
		return ({ 	'v0' : [ x for x in vec1 ],
					'v1' : [ x for x in vec2 ] },
			'''
				s2 = vf0 > vf1  
				s3 = vf0 < vf1
				s4 = vf0 >= vf1
				s5 = vf0 <= vf1
			''',
			{ 	't0u2' : greaterMask, 
				't0u3' : lessMask,	 
				't0u4' : greaterEqualMask,	
				't0u5' : lessEqualMask }, None, None, None)	
				
	def test_floatingPointRAWDependency():
		return ({ 'u1' : 7.0, 'u2' : 11.0, 'u4' : 13.0 }, '''
			f0 = f1 + f2
			f3 = f0 + f4
		''', { 't0u0' : 18.0, 't0u3' : 31.0 }, None, None, None)

	def test_infAndNanAddition():
		POS_INF = float('inf')
		NEG_INF = -float('inf')
		NAN = float('nan')

		return ({ 'u1' : POS_INF, 'u2' : NEG_INF, 'u3' : NAN, 'u4' : 3.14 }, '''
			f5 = f1 + f1
			f6 = f1 + f2
			f7 = f2 + f2
			f8 = f2 + f1
			
			f9 = f1 - f1
			f10 = f1 - f2
			f11 = f2 - f2
			f12 = f2 - f1

			f13 = f4 + f1
			f14 = f4 + f2
			f15 = f4 + f3

			f16 = f1 + f4 
			f17 = f2 + f4
			f18 = f3 + f4

			f19 = f4 - f1
			f20 = f4 - f2
			f21 = f4 - f3

			f22 = f1 - f4 
			f23 = f2 - f4
			f24 = f3 - f4
		''', { 
			't0u5' : POS_INF + POS_INF,
			't0u6' : POS_INF + NEG_INF,
			't0u7' : NEG_INF + NEG_INF,
			't0u8' : NEG_INF + POS_INF,

			't0u9' : POS_INF - POS_INF,
			't0u10' : POS_INF - NEG_INF,
			't0u11' : NEG_INF - NEG_INF,
			't0u12' : NEG_INF - POS_INF,

			't0u13' : 3.14 + POS_INF,
			't0u14' : 3.14 + NEG_INF,
			't0u15' : 3.14 + NAN,

			't0u16' : POS_INF + 3.14,
			't0u17' : NEG_INF + 3.14,
			't0u18' : NAN + 3.14,

			't0u19' : 3.14 - POS_INF,
			't0u20' : 3.14 - NEG_INF,
			't0u21' : 3.14 - NAN,

			't0u22' : POS_INF - 3.14,
			't0u23' : NEG_INF - 3.14,
			't0u24' : NAN - 3.14
		}, None, None, None)
		
	def test_infAndNanMultiplication():
		POS_INF = float('inf')
		NEG_INF = -float('inf')
		NAN = float('nan')

		return ({ 'u1' : POS_INF, 'u2' : NEG_INF, 'u3' : NAN, 'u4' : 1.0 }, '''
			f5 = f1 * f1
			f6 = f1 * f2
			f7 = f2 * f2
			f8 = f2 * f1
			
			f9 = f4 * f1
			f10 = f4 * f2
			f11 = f4 * f3

			f12 = f1 * f4 
			f13 = f2 * f4
			f14 = f3 * f4
		''', { 
			't0u5' : POS_INF * POS_INF,
			't0u6' : POS_INF * NEG_INF,
			't0u7' : NEG_INF * NEG_INF,
			't0u8' : NEG_INF * POS_INF,

			't0u9' : 1.0 * POS_INF,
			't0u10' : 1.0 * NEG_INF,
			't0u11' : 1.0 - NAN,

			't0u12' : POS_INF * 1.0,
			't0u13' : NEG_INF * 1.0,
			't0u14' : NAN * 1.0,
		}, None, None, None)		
		
		
	def test_floatingPointMultiplication():
		return ({ 'u1' : 2.0, 
			'u2' : 4.0, 
			'u5' : 27.3943, 
			'u6' : 99.382,
			'u8' : -3.1415,
			'u9' : 2.71828,
			'u11' : -1.2,
			'u12' : -2.3,
			'u14' : 4.0,
			'u15'  : 0.001,
			'u17'	: 0.0,
			'u18'	: 19.4
			}, '''
			f3 = f1 * f2
			f4 = f5 * f6
			f7 = f8 * f9
			f10 = f11 * f12
			f13 = f14 * f15
			f16 = f17 * f18		; zero identity
			f19 = f18 * f17		; zero identity (zero in second position)
		''', { 
			't0u3' : 8.0, 
			't0u4' : 2722.5003226,
			't0u7' : -8.53947662,
			't0u10' : 2.76,
			't0u13' : 0.004,
			't0u16' : 0.0,
			't0u19' : 0.0
		}, None, None, None)
		
	def test_itof():
		return ({ 'u1' : 12, 
				'u5' : -123, 
				'u7' : 23 },
			'''
				f3 = itof(s1)	
				f4 = itof(s5)
				f6 = itof(s7)
			''',
			{ 	't0u3' : 12.0,
			 	't0u4' : -123.0,
			 	't0u6' : 23.0
			}, None, None, None)

	def test_ftoi1():
		return ({ 'u1' : 12.981, 
				'u5' : -123.0, 
				'u7' : 23.0 },
			'''
				u3 = ftoi(f1)	
				u4 = ftoi(f5)
				u6 = ftoi(f7)
			''',
			{ 't0u3' : 12,
			 	't0u4' : -123,
			 	't0u6' : 23
			}, None, None, None)
	
	def test_ftoi2():
		return ({ 'u1': 0.00009, 'u2' : 0.0 },
		'''
			u4 = ftoi(f1)	; Result will be zero because of very small exponent.  
							; Make sure we shift in zeros properly (regression test).

			u5 = ftoi(f2)	; Actually zero
		''', { 't0u4' : 0, 't0u5' : 0, 't0u6' : 0 }, None, None, None)

	def test_reciprocal1():
		return ({ 'u0' : 12345.0, 'u1' : 4.0 }, '''
			f8 = reciprocal(f0)
			f9 = reciprocal(f1)		; significand is zero, special case
			f10 = reciprocal(f2)	; divide by zero, inf
		''', { 't0u8' : 0x38aa0000, 't0u9' : 0.25, 't0u10' : float('inf') }, None, None, None)
	
	def test_reciprocal2():
		return ({ 'u0' : 123.0, 'u1' : 2.0 }, '''
			f2 = reciprocal(f0)

			; newton raphson refinement
			f3 = f2 * f0		; Multiply x by est. of 1/x (ideally should be 1.0)
			f3 = f1 - f3		; 2.0 - estimate returns the error
			f2 = f3 * f2		; update estimate

			f3 = f2 * f0		; one more iteration
			f3 = f1 - f3
			f2 = f3 * f2
		
		''', { 't0u2' : 0x3c053407, 't0u3' : None }, None, None, None )
			
	def test_mulOverflow():
		return ({ 'u1' : float('1e20'), 'u2' : float('1e-20') },
			'''
				f3 = f1 * f1
				f4 = f2 * f2
			''',
			{ 	
				't0u3' : float('inf'),
				't0u4' : float('inf')
			}, None, None, None)
