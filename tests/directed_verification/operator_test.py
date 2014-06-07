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

def twos(x):
	if x < 0:
		return ((-x ^ 0xffffffff) + 1) & 0xffffffff
	else:
		return x

class OperatorTests(TestGroup):
	def test_vectorIntegerCompare():	
		BU = 0xc0800018		# Big unsigned
		BS = 0x60123498		# Big signed
		SM = 1	# Small
	
		return ({ 	'v0' : [ BU, BS, BU, BS, BU, SM, BS, SM, BU, BS, BU, BS, BU, SM, BS, SM ],
					'v1' : [ BU, BS, BS, BU, SM, BU, SM, BS, BU, BS, BS, BU, SM, BU, SM, BS ] },
			'''
				move s0, 15
				setcr s0, 30  ; Start all threads
				
				seteq_i s0, v0, v1
				setne_i s1, v0, v1
				setgt_i s2, v0, v1
				setlt_i s3, v0, v1
				setge_i s4, v0, v1
				setle_i s5, v0, v1
				setgt_u s6, v0, v1
				setlt_u s7, v0, v1
				setge_u s8, v0, v1
				setle_u s9, v0, v1
			''',
			{ 	's0' : 0xc0c0,
				's1' : 0x3f3f,
				's2' : 0x1616,   # 00010110
				's3' : 0x2929,	 # 00101001
				's4' : 0xd6d6,	 # 11010110
				's5' : 0xe9e9,	 # 11101001
				's6' : 0x2a2a,	 # 00101001
				's7' : 0x1515,	 # 00010101
				's8' : 0xeaea,   # 11101010
				's9' : 0xd5d5 	 # 11010101
			}, None, None, None) 
		
	def test_registerOps():
		OP1 = 0x19289adf
		OP2 = 0x2374bdad
			 
		return ({ 's0' : OP1, 's1' : OP2, 's20' : 5},
			'''
				move s2, 15
				setcr s2, 30  ; Start all threads

				or s2, s0, s1
				and s3, s0, s1
				;neg s4, s0		; XXX no assembler instruction
				xor s5, s0, s1
				;not s6, s0		; XXX not assembler instruction
				add_i s7, s0, s1
				sub_i s8, s0, s1
				ashr s9, s0, s20
				shl s10, s0, s20
			''',
			{ 's2' : (OP1 | OP2),
			's3' : (OP1 & OP2),
#			's4' : -OP1,
			's5' : (OP1 ^ OP2),
#			's6' : 0xffffffff ^ OP1,
			's7' : OP1 + OP2,
			's8' : twos(OP1 - OP2) ,
			's9' : OP1 >> 5,
			's10' : (OP1 << 5) & 0xffffffff }, None, None, None)
	
	# Test all immediate operator types
	def test_immediateOps():
		OP1 = 0x19289adf
			 
		return ({ 's0' : OP1 },
			'''
				move s2, 15
				setcr s2, 30  ; Start all threads

				or s2, s0, 233
				and s3, s0, 233
				xor s5, s0, 233
				add_i s6, s0, 233
				add_i s7, s0, -233		; Negative immediate operand
				sub_i s8, s0, 233
				ashr s9, s0, 5
				shl s10, s0, 5
			''',
			{ 's2' : (OP1 | 233),
			's3' : (OP1 & 233),
			's5' : (OP1 ^ 233),
			's6' : (OP1 + 233),
			's7' : OP1 - 233,
			's8' : OP1 - 233,
			's9' : OP1 >> 5,
			's10' : (OP1 << 5) & 0xffffffff }, None, None, None)
	
	# Test all values of format field for type B instructions
	def test_immediateFormats():
		OP1 = 27

		return({ 
				's1' : OP1,
				's2' : 0xaaaa,
				'v1' : [ OP1 for x in range(16) ]
			}, '''

			; Immediate values
			add_i s3, s1, 12			; Scalar/Scalar     (extended immediate)
			add_i v2, v1, 13			; Vector/Vector/N/N (extended immediate)
			add_i_mask v3, s2, v1, 17	; Vector/Vector/Y/N
			add_i v5, s1, 21			; Vector/Scalar/N/N (extended immediate)
			add_i_mask v6, s2, s1, 27	; Vector/Scalar/Y/N
			
			; Assignments (special case)
			move s4, s1					; Scalar/Scalar
			move v8, v1					; Vector/Vector/N/N
			move_mask v9, s2, v1		; Vector/Vector/Y/N
			move v11, s1				; Vector/Scalar/N/N
			move_mask v12, s2, s1		; Vector/Scalar/Y/N
		''', {
		't0s3' : 39,
		't0v2' : [ OP1 + 13 for x in range(16) ],		
		't0v3' : [ OP1 + 17 if x % 2 == 0 else 0 for x in range(16) ],		
		't0v5' : [ OP1 + 21 for x in range(16) ],		
		't0v6' : [ OP1 + 27 if x % 2 == 0 else 0 for x in range(16) ],		
		't0s4' : 27,
		't0v8' : [ OP1 for x in range(16) ],		
		't0v9' : [ OP1 if x % 2 == 0 else 0 for x in range(16) ],		
		't0v11' : [ OP1 for x in range(16) ],		
		't0v12' : [ OP1 if x % 2 == 0 else 0 for x in range(16) ],		
		}, None, None, None)
			
			
	# This mostly ensures we properly detect integer multiplies as long
	# latency instructions and stall the strand appropriately.
	def test_integerMultiplyRAW():
		return ({'s1' : 5, 's2' : 7, 's4' : 17},
			'''
				mul_i s0, s1, s2	; Ensure A instructions are marked as long latency
				mul_i s1, s0, 13	; Ensure scheduler resolves RAW hazard with i0
								; also ensure B instructions are marked as long latency
				move s2, s1			; RAW hazard with type B
				add_i s4, s4, 1		; Ensure these don't clobber results
				add_i s4, s4, 1
				add_i s4, s4, 1
				add_i s4, s4, 1
				add_i s4, s4, 1
				add_i s4, s4, 1
			''',
			{
				't0s0' : 35,
				't0s1' : 455,
				't0s2' : 455,
				't0s4' : 23
			}, None, None, None)	
	
	
	def test_integerMultiply():
		return ({'s1' : 5, 's2' : -12},
			'''
				mul_i s3, s1, s1
				mul_i s4, s1, s2
				mul_i s5, s2, s1
				mul_i s6, s2, s2
			''',
			{
				't0s3' : 25,
				't0s4' : -60,
				't0s5' : -60,
				't0s6' : 144
			}, None, None, None)
			
	# Shifting mask test.  We do this multiple address modes,
	# since those have different logic paths in the decode stage
	def test_vectorMask():
		code = '''
				move s0, 15
				setcr s0, 30		; Start all threads
		'''

		for x in range(16):
			code += '''
				add_i_mask v1, s1, v1, 1
				add_i_mask v3, s1, v3, s2
				add_i_mask v5, s1, v5, v20
				add_i v7, v7, 1				; No mask
				add_i v8, v8, s2			; No mask
				add_i v9, v9, v20			; No mask
				shr s1, s1, 1			
			'''			
	
		result1 = [ x + 1 for x in range(16) ]
		result3 = [ 16 for x in range(16) ]
		return ({ 's1' : 0xffff, 's2' : 1, 'v20' : [ 1 for x in range(16) ]}, 
			code, {
			's0' : None,
			'v1' : result1,
			'v3' : result1,
			'v5' : result1,
			'v7' : result3,
			'v8' : result3,
			'v9' : result3,
			's1' : None }, None, None, None)
			
	def test_shuffle():
		src = allocateRandomVectorValue()
		indices = shuffleIndices()
		
		return ({
				'v3' : src,
				'v4' : indices
			},
			'''
				move s0, 15
				setcr s0, 30  ; Start all threads
			
				shuffle v2, v3, v4
			''',
			{ 'v2' : [ src[index] for index in indices ], 's0' : None }, 
			None, None, None)

	# Format A
	def test_getlane1():
		src = allocateRandomVectorValue()
		
		return ({
				'v0' : src,
				's0' : 0,
				's1' : 1,
				's2' : 2,
				's3' : 3,
				's4' : 4,
				's5' : 5,
				's6' : 6,
				's7' : 7,
				's8' : 8,
				's9' : 9,
				's10' : 10,
				's11' : 11,
				's12' : 12,
				's13' : 13,
				's14' : 14,
				's15' : 15
			},
			'''
				getlane s16, v0, s0
				getlane s17, v0, s1
				getlane s18, v0, s2
				getlane s19, v0, s3
				getlane s20, v0, s4
				getlane s21, v0, s5
				getlane s22, v0, s6
				getlane s23, v0, s7
				getlane s24, v0, s8
				getlane s25, v0, s9
				getlane s26, v0, s10
				getlane s27, v0, s11
				getlane s0, v0, s12
				getlane s1, v0, s13
				getlane s2, v0, s14
				getlane s3, v0, s15
			''',
			{
				't0s16' : src[0],
				't0s17' : src[1],
				't0s18' : src[2],
				't0s19' : src[3],
				't0s20' : src[4],
				't0s21' : src[5],
				't0s22' : src[6],
				't0s23' : src[7],
				't0s24' : src[8],
				't0s25' : src[9],
				't0s26' : src[10],
				't0s27' : src[11],
				't0s0' : src[12],
				't0s1' : src[13],
				't0s2' : src[14],
				't0s3' : src[15],
			 }, 
			None, None, None)

	# Format B
	def test_getlane2():
		src = allocateRandomVectorValue()
		
		return ({
				'v0' : src
			},
			'''
				getlane s0, v0, 0
				getlane s1, v0, 1
				getlane s2, v0, 2
				getlane s3, v0, 3
				getlane s4, v0, 4
				getlane s5, v0, 5
				getlane s6, v0, 6
				getlane s7, v0, 7
				getlane s8, v0, 8
				getlane s9, v0, 9
				getlane s10, v0, 10
				getlane s11, v0, 11
				getlane s12, v0, 12
				getlane s13, v0, 13
				getlane s14, v0, 14
				getlane s15, v0, 15
			''',
			{
				't0s0' : src[0],
				't0s1' : src[1],
				't0s2' : src[2],
				't0s3' : src[3],
				't0s4' : src[4],
				't0s5' : src[5],
				't0s6' : src[6],
				't0s7' : src[7],
				't0s8' : src[8],
				't0s9' : src[9],
				't0s10' : src[10],
				't0s11' : src[11],
				't0s12' : src[12],
				't0s13' : src[13],
				't0s14' : src[14],
				't0s15' : src[15],
			 }, 
			None, None, None)

	# Copy instruction, with an immediate operator and register-register
	# transfer
	def test_copy():
		return ({ 's0' : 0x12345678 }, '''
			move s2, 15
			setcr s2, 30  ; Start all threads
			
			move s1, s0
			move s2, 123
		''', { 's1' : 0x12345678, 's2' : 123 }, None, None, None)

	def test_countZeroes():
		return ({ 's15' : 0xa5000000 }, '''
			move s0, 15
			setcr s0, 30  ; Start all threads

			clz s1, s15
			ctz s2, s15
			shr s15, s15, 1
			clz s3, s15
			ctz s4, s15
			shr s15, s15, 1
			clz s5, s15
			ctz s6, s15
			shr s15, s15, 10
			clz s7, s15
			ctz s8, s15
		''', {
			's0' : None,
			's1' : 0,
			's2' : 24,
			's3' : 1,
			's4' : 23,
			's5' : 2,
			's6' : 22,
			's7' : 12,
			's8' : 12,
			's15' : None
		}, None, None, None)
	
	# Strand 0 does a long latency operation
	# Strand 1-3 do short latency operations, which should conflict 
	def test_executeHazard():
		return ({ 's1' : 7, 's2' : 9 }, '''
				getcr s0, 0 ; get strand ID
				btrue s0, do_single		; strands 1-3 do single operations

				move s0, 15
				setcr s0, 30 ; start all strands

				nop
				nop
				nop
				nop
				nop
				mul_i s3, s1, s2			; single cycle operation
		wait:	goto wait

		do_single:	
				add_i s3, s3, 1
				add_i s3, s3, 2
				add_i s3, s3, 3
				add_i s3, s3, 4
				add_i s3, s3, 5
				add_i s3, s3, 6
				goto ___done
		''', {
			's0' : None,
			't0s3' : 63, 
			't1s3' : 21, 
			't2s3' : 21,
			't3s3' : 21
		}, None, None, None)

	def test_shl0():
		return ({'s1' : 1, 's2' : 0xffffffff },
			'shl s3, s1, s2',
			{ 's0s3' : 0 }, None, None, None)
			
	def test_sext():
		return ({
			's1' : 12, 
			's2' : 0xf4,
			's3' : 16292,
			's4' : 0xc05c },
			'''
				sext_8 s5, s1
				sext_8 s6, s2
				sext_16 s7, s3
				sext_16 s8, s4
			''',
			{ 
				't0s5' : 12, 
				't0s6' : -12, 
				't0s7' : 16292, 
				't0s8' : -16292, 
			}, None, None, None)
		