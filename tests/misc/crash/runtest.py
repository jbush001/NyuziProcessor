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

# The purpose of this test is to ensure the test harness itself works
# correctly by properly returning an error when the test program crashes

import sys
import os

sys.path.insert(0, '../..')
import test_harness

def emulator_crash(name):
	test_harness.compile_test('crash.c')
	try:
		result = test_harness.run_emulator()

		# The test program deliberately crashes. If the harness doesn't throw
		# an exception, that is a failure.
		raise TestException('Did not catch crash')
	except:
		# ...and vice versa
		pass

def verilator_crash(name):
	test_harness.compile_test('crash.c')
	try:
		result = test_harness.run_verilator()
		raise TestException('Did not catch crash')
	except:
		pass

test_harness.register_tests(emulator_crash, ['crash (emulator)'])
test_harness.register_tests(verilator_crash, ['crash (verilator)'])
test_harness.execute_tests()

