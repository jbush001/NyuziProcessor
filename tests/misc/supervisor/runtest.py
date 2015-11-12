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
import subprocess

sys.path.insert(0, '../..')
import test_harness

def run_test(name):
	if name.endswith('_emulator'):
		basename = name[0:-len('_emulator')]
		isverilator = False
	elif name.endswith('_verilator'):
		basename = name[0:-len('_verilator')]
		isverilator = True
	
	test_harness.compile_test([basename + '.c'])
	if isverilator:
		result = test_harness.run_verilator()
	else:
		result = test_harness.run_emulator()
		
	test_harness.check_result(basename + '.c', result)

tests = [
	'creg_non_supervisor',
	'eret_non_supervisor',
	'dtlb_non_supervisor',
	'itlb_non_supervisor'
]

for name in tests:
	test_harness.register_tests(run_test, [name + '_verilator'])
	test_harness.register_tests(run_test, [name + '_emulator'])

test_harness.execute_tests()
