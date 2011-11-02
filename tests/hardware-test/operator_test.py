from runcase import *

def runVectorCompareTests():	
	BU = 0xc0800018		# Big unsigned
	BS = 0x60123498		# Big signed
	SM = 1	# Small

	runTest({ 	'v0' : [ BU, BS, BU, BS, BU, SM, BS, SM, BU, BS, BU, BS, BU, SM, BS, SM ],
				'v1' : [ BU, BS, BS, BU, SM, BU, SM, BS, BU, BS, BS, BU, SM, BU, SM, BS ] },
		'''
			s0 = vi0 == vi1
			s1 = vi0 <> vi1
			s2 = vi0 > vi1  
			s3 = vi0 < vi1
			s4 = vi0 >= vi1
			s5 = vi0 <= vi1
			s6 = vu0 > vu1
			s7 = vu0 < vu1
			s8 = vu0 >= vu1
			s9 = vu0 <= vu1
			done goto done
		''',
		{ 	'u0' : 0xc0c0,
		 	'u1' : 0x3f3f,
		 	'u2' : 0x1616,   # 00010110
		 	'u3' : 0x2929,	 # 00101001
		 	'u4' : 0xd6d6,	 # 11010110
		 	'u5' : 0xe9e9,	 # 11101001
		 	'u6' : 0x2626,	 # 00100110
		 	'u7' : 0x1919,	 # 00011001
		 	'u8' : 0xe6e6,   # 11100110
		 	'u9' : 0xd9d9 }) # 11011001
	
def twos(x):
	if x < 0:
		return ((-x ^ 0xffffffff) + 1) & 0xffffffff
	else:
		return x
	
def runOperatorTests():
	OP1 = 0x19289adf
	OP2 = 0x2374bdad
		 
	runTest({ 'u0' : OP1, 'u1' : OP2},
		'''
			u2 = u0 | u1
			u3 = u0 & u1
			u4 = u0 &~ u1
			u5 = u0 ^ u1
			u6 = ~u0
			u7 = u0 + u1
			u8 = u0 - u1
			u9 = u0 >> 5
			u10 = u0 << 5
		''',
		{ 'u2' : (OP1 | OP2),
		'u3' : (OP1 & OP2),
		'u4' : (OP1 & ~OP2),
		'u5' : (OP1 ^ OP2),
		'u6' : 0xffffffff ^ OP1,
		'u7' : OP1 + OP2,
		'u8' : twos(OP1 - OP2) ,
		'u9' : OP1 >> 5,
		'u10' : (OP1 << 5) & 0xffffffff })
		 	
runVectorCompareTests()
runOperatorTests()
