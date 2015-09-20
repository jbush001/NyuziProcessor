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

#
# This test writes a pattern to memory and manually flushes it from code. It then
# checks the contents of system memory to ensure the data was flushed correctly.
#

import sys

sys.path.insert(0, '../..')
import test_harness

BASE_ADDRESS=0x400000

test_harness.compile_test('dflush.c')
test_harness.run_verilator(dump_file='obj/vmem.bin', dump_base=BASE_ADDRESS, dump_length=0x40000)
with open('obj/vmem.bin', 'rb') as f:
	index = 0
	while True:
		val = f.read(4)
		if val == '':
			break
		
		numVal = ord(val[0]) | (ord(val[1]) << 8) | (ord(val[2]) << 16) | (ord(val[3]) << 24)
		expected = 0x1f0e6231 + (index / 16)
		if numVal != expected:
			print 'FAIL: mismatch at', hex(BASE_ADDRESS + (index * 4)), 'want', expected, 'got', numVal 
			sys.exit(1)
			
		index += 1

print 'PASS'
