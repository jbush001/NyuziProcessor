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
			(1000000.0, 10000000.0, 11000000.0)	# Very large number
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
		INF = 0x7f800000
		NAN = 0xffffffff
	
		return ({ 'u1' : INF, 'u2' : NAN, 'u3' : 3.14 }, '''
			f4 = f1 - f1		; inf - inf = nan
			f5 = f1 + f3		; inf + anything = inf
			f6 = f1 + f1		; inf + inf = inf
			f7 = f1 - f3		; inf - anything = inf
			f8 = f2 + f3		; nan + anything = nan
			f9 = f2 + f2		; nan + nan = nan
			f10 = f2 - f3		; nan - anything = nan
			f11 = f2 - f2		; nan - nan = nan
		''', { 
			't0u4' : NAN,
			't0u5' : INF,
			't0u6' : INF,
			't0u7' : INF,
			't0u8' : NAN,
			't0u9' : NAN,
			't0u10' : NAN,
			't0u11' : NAN
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
		''', { 't0u3' : 8.0, 
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

	def test_ftoi():
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
			
	# Result will be zero because of very small exponent.  Make sure
	# we shift in zeros properly (regression test).
	def test_ftoi2():
		return ({ 'u1': 0.00009 },
		'''
			u2 = ftoi(f1)
		''', { 't0u2' : 0 }, None, None, None)
			
	def test_reciprocal():
		return ({ 'u1' : 12345.0 }, '''
			f0 = reciprocal(f1)
		''', { 't0u0' : 0x38aa0000 }, None, None, None)
	
	
			
			
			
