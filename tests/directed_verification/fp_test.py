# 
# Copyright (C) 2011-2014 Jeff Bush
# 
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Library General Public
# License as published by the Free Software Foundation; either
# version 2 of the License, or (at your option) any later version.
# 
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Library General Public License for more details.
# 
# You should have received a copy of the GNU Library General Public
# License along with this library; if not, write to the
# Free Software Foundation, Inc., 51 Franklin St, Fifth Floor,
# Boston, MA  02110-1301, USA.
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
			outRegs['t0s' + str(regIndex)] = expectedResult
			inRegs['s' + str(regIndex + 1)] = value1
			inRegs['s' + str(regIndex + 2)] = value2
			code += 'add_f s'+ str(regIndex) + ', s' + str(regIndex + 1) + ', s' + str(regIndex + 2) + '\n'
			regIndex += 3
			
			if regIndex == 27:
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
			(-2.0, 'gt', -3.0, 1),
			(-3.0, 'gt', -2.0, 0),
			(17.0, 'gt', 2.0, 1),
			(2.0, 'gt', 17.0, 0),
			(5.0, 'gt', -17.0, 1),
			(-17.0, 'gt', 5.0, 0),
			(15.0, 'gt', -7.0, 1),
			(-7.0, 'gt', 15.0, 0),
			(-2.0, 'ge', -3.0, 1),
			(-3.0, 'ge', -2.0, 0),
			(17.0, 'ge', 2.0, 1),
			(2.0, 'ge', 17.0, 0),
			(5.0, 'ge', -17.0, 1),
			(-17.0, 'ge', 5.0, 0),
			(15.0, 'ge', -7.0, 1),
			(-7.0, 'ge', 15.0, 0),
			(-5.0, 'ge', -5.0, 1),
			(-2.0, 'lt', -3.0, 0),
			(-3.0, 'lt', -2.0, 1),
			(17.0, 'lt', 2.0, 0),
			(2.0, 'lt', 17.0, 1),
			(5.0, 'lt', -17.0, 0),
			(-17.0, 'lt', 5.0, 1),
			(15.0, 'lt', -7.0, 0),
			(-7.0, 'lt', 15.0, 1),
			(-2.0, 'le', -3.0, 0),
			(-3.0, 'le', -2.0, 1),
			(17.0, 'le', 2.0, 0),
			(2.0, 'le', 17.0, 1),
			(5.0, 'le', -17.0, 0),
			(-17.0, 'le', 5.0, 1),
			(15.0, 'le', -7.0, 0),
			(-7.0, 'le', 15.0, 1),
			(-5.0, 'le', -5.0, 1),
			(float('nan'), 'le', 5.0, 0),
			(5.0, 'le', float('nan'), 0),
		]
	
		cases = []
		regIndex = 0
		inRegs = {}
		outRegs = {}
		code = ''
		for value1, operator, value2, expectedResult in testValues:
			outRegs['t0s' + str(regIndex)] = 0xffff if expectedResult else 0
			inRegs['s' + str(regIndex + 1)] = value1
			inRegs['s' + str(regIndex + 2)] = value2
			code += 'set' + operator + '_f s' + str(regIndex) + ', s' + str(regIndex + 1) + ', s' + str(regIndex + 2) + '\n'
			regIndex += 3
			
			if regIndex == 27:
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
				setgt_f s2, v0, v1  
				setlt_f s3, v0, v1
				setge_f s4, v0, v1
				setle_f s5, v0, v1
			''',
			{ 	't0s2' : greaterMask, 
				't0s3' : lessMask,	 
				't0s4' : greaterEqualMask,	
				't0s5' : lessEqualMask }, None, None, None)	
				
	def test_floatingPointRAWDependency():
		return ({ 's1' : 7.0, 's2' : 11.0, 's4' : 13.0 }, '''
			add_f s0, s1, s2
			add_f s3, s0, s4
		''', { 't0s0' : 18.0, 't0s3' : 31.0 }, None, None, None)

	def test_infAndNanAddition():
		POS_INF = float('inf')
		NEG_INF = -float('inf')
		NAN = float('nan')

		return ({ 's1' : POS_INF, 's2' : NEG_INF, 's3' : NAN, 's4' : 3.14 }, '''
			add_f s5, s1, s1
			add_f s6, s1, s2
			add_f s7, s2, s2
			add_f s8, s2, s1
			
			sub_f s9, s1, s1
			sub_f s10, s1, s2
			sub_f s11, s2, s2
			sub_f s12, s2, s1

			add_f s13, s4, s1
			add_f s14, s4, s2
			add_f s15, s4, s3

			add_f s16, s1, s4 
			add_f s17, s2, s4
			add_f s18, s3, s4

			sub_f s19, s4, s1
			sub_f s20, s4, s2
			sub_f s21, s4, s3

			sub_f s22, s1, s4 
			sub_f s23, s2, s4
			sub_f s24, s3, s4
		''', { 
			't0s5' : POS_INF + POS_INF,
			't0s6' : POS_INF + NEG_INF,
			't0s7' : NEG_INF + NEG_INF,
			't0s8' : NEG_INF + POS_INF,

			't0s9' : POS_INF - POS_INF,
			't0s10' : POS_INF - NEG_INF,
			't0s11' : NEG_INF - NEG_INF,
			't0s12' : NEG_INF - POS_INF,

			't0s13' : 3.14 + POS_INF,
			't0s14' : 3.14 + NEG_INF,
			't0s15' : 3.14 + NAN,

			't0s16' : POS_INF + 3.14,
			't0s17' : NEG_INF + 3.14,
			't0s18' : NAN + 3.14,

			't0s19' : 3.14 - POS_INF,
			't0s20' : 3.14 - NEG_INF,
			't0s21' : 3.14 - NAN,

			't0s22' : POS_INF - 3.14,
			't0s23' : NEG_INF - 3.14,
			't0s24' : NAN - 3.14
		}, None, None, None)
		
	def test_infAndNanMultiplication():
		POS_INF = float('inf')
		NEG_INF = -float('inf')
		NAN = float('nan')

		return ({ 's1' : POS_INF, 's2' : NEG_INF, 's3' : NAN, 's4' : 1.0 }, '''
			mul_f s5, s1, s1
			mul_f s6, s1, s2
			mul_f s7, s2, s2
			mul_f s8, s2, s1
			
			mul_f s9, s4, s1
			mul_f s10, s4, s2
			mul_f s11, s4, s3

			mul_f s12, s1, s4 
			mul_f s13, s2, s4
			mul_f s14, s3, s4
		''', { 
			't0s5' : POS_INF * POS_INF,
			't0s6' : POS_INF * NEG_INF,
			't0s7' : NEG_INF * NEG_INF,
			't0s8' : NEG_INF * POS_INF,

			't0s9' : 1.0 * POS_INF,
			't0s10' : 1.0 * NEG_INF,
			't0s11' : 1.0 - NAN,

			't0s12' : POS_INF * 1.0,
			't0s13' : NEG_INF * 1.0,
			't0s14' : NAN * 1.0,
		}, None, None, None)		
		
		
	def test_floatingPointMultiplication():
		return ({ 's1' : 2.0, 
			's2' : 4.0, 
			's5' : 27.3943, 
			's6' : 99.382,
			's8' : -3.1415,
			's9' : 2.71828,
			's11' : -1.2,
			's12' : -2.3,
			's14' : 4.0,
			's15'  : 0.001,
			's17'	: 0.0,
			's18'	: 19.4
			}, '''
			mul_f s3, s1, s2
			mul_f s4, s5, s6
			mul_f s7, s8, s9
			mul_f s10, s11, s12
			mul_f s13, s14, s15
			mul_f s16, s17, s18		; zero identity
			mul_f s19, s18, s17		; zero identity (zero in second position)
		''', { 
			't0s3' : 8.0, 
			't0s4' : 2722.5003226,
			't0s7' : -8.53947662,
			't0s10' : 2.76,
			't0s13' : 0.004,
			't0s16' : 0.0,
			't0s19' : 0.0
		}, None, None, None)
		
	def test_itof():
		return ({ 's1' : 12, 
				's5' : -123, 
				's7' : 23 },
			'''
				itof s3, s1	
				itof s4, s5
				itof s6, s7
			''',
			{ 	't0s3' : 12.0,
			 	't0s4' : -123.0,
			 	't0s6' : 23.0
			}, None, None, None)

	def test_ftoi1():
		return ({ 's1' : 12.981, 
				's5' : -123.0, 
				's7' : 23.0 },
			'''
				ftoi s3, s1	
				ftoi s4, s5
				ftoi s6, s7
			''',
			{ 't0s3' : 12,
			 	't0s4' : -123,
			 	't0s6' : 23
			}, None, None, None)
	
	def test_ftoi2():
		return ({ 's1': 0.00009, 's2' : 0.0 },
		'''
			ftoi s4, s1	; Result will be zero because of very small exponent.  
							; Make sure we shift in zeros properly (regression test).

			ftoi s5, s2	; Actually zero
		''', { 't0s4' : 0, 't0s5' : 0, 't0s6' : 0 }, None, None, None)

	def test_reciprocal1():
		return ({ 
			's0' : 12345.0, 
			's1' : 4.0,
			's2' : +0.0,
			's3' : -0.0,
			's4' : float('inf'),
			's5' : -float('inf'),
			's6' : float('nan')
		}, '''
			reciprocal s8, s0		; divide by normal number
			reciprocal s9, s1		; significand is zero, special case
			reciprocal s10, s2	; divide by plus zero, +inf
			reciprocal s11, s3	; divide by minus zero, -inf
			reciprocal s12, s4	; divide by +inf, result is +0
			reciprocal s13, s5	; divide by -inf, result is -0
			reciprocal s14, s6	; divide by NaN, result is NaN
		''', { 
			't0s8' : 0x38aa0000, 
			't0s9' : 0.25, 
			't0s10' : float('inf'),
			't0s11' : -float('inf'),
			't0s12' : +0.0,
			't0s13' : -0.0,
			't0s14' : float('nan')
		 }, None, None, None)
	
	def test_reciprocal2():
		return ({ 's0' : 123.0, 's1' : 2.0 }, '''
			reciprocal s2, s0

			; newton raphson refinement
			mul_f s3, s2, s0		; Multiply x by est. of 1/x (ideally should be 1.0)
			sub_f s3, s1, s3		; 2.0 - estimate returns the error
			mul_f s2, s3, s2		; update estimate

			mul_f s3, s2, s0		; One more iteration
			sub_f s3, s1, s3
			mul_f s2, s3, s2
		
		''', { 't0s2' : 0x3c053407, 't0s3' : None }, None, None, None )
			
	def test_mulOverUnderflow():
		return ({ 's1' : float('1e20'), 's2' : float('1e-20') },
			'''
				mul_f s3, s1, s1	; overflow
				mul_f s4, s2, s2	; underflow
			''',
			{ 	
				't0s3' : float('inf'),
				't0s4' : 0.0
			}, None, None, None)
			
