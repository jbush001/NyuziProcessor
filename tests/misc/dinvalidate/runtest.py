#!/usr/bin/env python
# 
# Copyright 2011-2015 Jeff Bush
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

import sys
import struct

sys.path.insert(0, '../..')
import test_harness

def dinvalidate_test(name):
	test_harness.assemble_test('dinvalidate.s')
	result = test_harness.run_verilator(dump_file='obj/vmem.bin', dump_base=0x100, dump_length=4, 
		extra_args=['+trace=1', '+autoflushl2=1'])

	# 1. Check that the proper value was read into s2
	if result.find('02 deadbeef') == -1:
		raise TestException('incorrect value was written back ' + result)

	# 2. Read the memory dump to ensure the proper value is flushed from the L2 cache
	with open('obj/vmem.bin', 'rb') as f:
		numVal = struct.unpack('<L', f.read(4))[0]
		if numVal != 0xdeadbeef:
			print(hex(numVal))
			raise test_harness.TestException('memory contents were incorrect')
	
test_harness.register_tests(dinvalidate_test, ['dinvalidate'])
test_harness.execute_tests()


