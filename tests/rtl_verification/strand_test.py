from testcase import TestCase

class StrandTest(TestCase):
	def test_strands():
		return ({},
			'''
				s0 = cr0
				s0 = s0 + 0x10
				s0 = s0 + 0x20
				s0 = s0 + 0x30
			''',
			{}, None, None, None)