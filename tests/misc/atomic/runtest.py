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

# Test load_sync/store_sync instructions by having four threads update
# variables round-robin.

sys.path.insert(0, '../..')
import test_harness

def atomic_test(name):
	test_harness.compile_test('atomic.c')
	test_harness.run_verilator(dump_file='obj/vmem.bin', dump_base=0x100000, dump_length=0x800,
		extra_args=['+autoflushl2=1'])

	with open('obj/vmem.bin', 'rb') as f:
		while True:
			val = f.read(4)
			if len(val) == 0:
				break

			numVal = struct.unpack('<L', val)[0]
			if numVal != 10:
				raise test_harness.TestException('FAIL: mismatch: ' + str(numVal))

test_harness.register_tests(atomic_test, ['atomic'])
test_harness.execute_tests()
