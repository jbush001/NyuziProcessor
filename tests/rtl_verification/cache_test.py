from testcase import TestCase

class CacheTests(TestCase):
	# Simple test that does a store followed by a load.  Will cause a cache
	# miss and write through on the first instruction and a cache hit on 
	# the second.
	def test_cacheStoreLoad():
		return ({ 'u0' : 0x12345678}, '''
					mem_l[dat1] = u0
					u1 = mem_l[dat1]
			done	goto done
			dat1	.word 0	
		''', { 'u1' : 0x12345678 }, None, None, None)

	# Similar to above, except the line is resident.  The store will write
	# through, but it should also update the cache line
	def test_cacheLoadStoreLoad():
		return ({ 'u0' : 0x12345678}, '''
					u1 = mem_l[dat1]		# load line into cache...
					mem_l[dat1] = u0
					u1 = mem_l[dat1]
			done	goto done
			dat1	.word 0	
		''', { 'u1' : 0x12345678 }, None, None, None)


	# These addresses all target the same set.  This will force a writeback
	# to L2, followed by a re-load
	def test_cacheAlias():
		return ({ 'u0' : 128,
			'u20' : 2048,
			'u1' : 0x01010101, 
			'u2' : 0x02020202,
			'u3' : 0x03030303,
			'u4' : 0x04040404,
			'u5' : 0x05050505,
			'u6' : 0x06060606,
			'u7' : 0x07070707 }, '''
					u8 = u0
					mem_l[u0] = u1
					u0 = u0 + u20
					mem_l[u0] = u2
					u0 = u0 + u20
					mem_l[u0] = u3
					u0 = u0 + u20
					mem_l[u0] = u4
					u0 = u0 + u20
					mem_l[u0] = u5
					u0 = u0 + u20
					mem_l[u0] = u6
					u0 = u0 + u20
					mem_l[u0] = u7
					
					u9 = mem_l[u8]
					u8 = u8 + u20
					u10 = mem_l[u8]
					u8 = u8 + u20
					u11 = mem_l[u8]
					u8 = u8 + u20
					u12 = mem_l[u8]
					u8 = u8 + u20
					u13 = mem_l[u8]
					u8 = u8 + u20
					u14 = mem_l[u8]
					u8 = u8 + u20
					u15 = mem_l[u8]
		''', { 'u0' : None,
		'u8' : None,
		'u9' : 0x01010101, 
		'u10' : 0x02020202, 
		'u11' : 0x03030303, 
		'u12' : 0x04040404, 
		'u13' : 0x05050505, 
		'u14' : 0x06060606, 
		'u15' : 0x07070707
		}, None, None, None)
		
	def test_icacheMiss():
		return ({}, '''
					goto label1

					.align 2048
		label5		s0 = s0 + 5
					s1 = s1 + s0
					goto label6

					.align 2048
		label4		s0 = s0 + 4
					s1 = s1 + s0
					goto label5

					.align 2048
		label3		s0 = s0 + 3
					s1 = s1 + s0
					goto label4
				
					.align 2048
		label2		s0 = s0 + 2
					s1 = s1 + s0
					goto label3

					.align 2048
		label6		s0 = s0 + 6
					s1 = s1 + s0
					goto done

		label1		s0 = s0 + 1
					s1 = s1 + s0
					goto label2
					
		done		nop
		''', { 'u0' : 21, 'u1' : 56 }, None, None, None)
