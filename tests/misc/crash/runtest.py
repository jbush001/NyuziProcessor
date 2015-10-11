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

test_harness.compile_test('crash.c')
print 'Testing Emulator'
try:
	result = test_harness.run_emulator()
	
	# The test program deliberately crashes. If the harness doesn't throw 
	# an exception, that is a failure.
	print 'FAIL'
	os._exit(1)	# Don't throw SystemExit exception
except:
	# ...and vice versa
	print 'PASS'

print 'Testing Verilator'
try:
	result = test_harness.run_verilator()
	print 'FAIL'
	os._exit(1)
except:
	print 'PASS'
