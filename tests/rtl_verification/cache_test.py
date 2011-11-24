from testcase import TestCase

class CacheTests(TestCase):
	# Simple test that does a store followed by a load.  Will cause a cache
	# miss on the first instruction and a cache hit on the second.
	def test_cacheStoreLoad():
		return ({ 'u0' : 0x12345678}, '''
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
		
