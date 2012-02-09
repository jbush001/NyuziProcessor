from testcase import TestCase

class StrandTest(TestCase):
	def test_strands():
		return ({},
			'''
				s0 = 15
				cr30 = s0	; Enable all threads
				
				s0 = cr0
				s0 = s0 + 0x10
				s0 = s0 + 0x20
				s0 = s0 + 0x30
			''',
			{ 't0u0' : 0x60, 't1u0' : 0x61, 't2u0' : 0x62, 't3u0' : 0x63 }, 
			None, None, None)