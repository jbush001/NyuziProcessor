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

def test_creg_non_supervisor_verilator(name):
	test_harness.compile_test(['creg_non_supervisor.c'])
	result = test_harness.run_verilator()
	test_harness.check_result('creg_non_supervisor.c', result)
	
def test_creg_non_supervisor_emulator(name):
	test_harness.compile_test(['creg_non_supervisor.c'])
	result = test_harness.run_emulator()
	test_harness.check_result('creg_non_supervisor.c', result)

def test_eret_non_supervisor_verilator(name):
	test_harness.compile_test(['eret_non_supervisor.c'])
	result = test_harness.run_verilator()
	test_harness.check_result('eret_non_supervisor.c', result)
	
def test_eret_non_supervisor_emulator(name):
	test_harness.compile_test(['eret_non_supervisor.c'])
	result = test_harness.run_emulator()
	test_harness.check_result('eret_non_supervisor.c', result)

test_harness.register_tests(test_creg_non_supervisor_verilator, ['creg_non_supervisor_verilator'])
test_harness.register_tests(test_creg_non_supervisor_emulator, ['creg_non_supervisor_emulator'])
test_harness.register_tests(test_eret_non_supervisor_verilator, ['eret_non_supervisor_verilator'])
test_harness.register_tests(test_eret_non_supervisor_emulator, ['eret_non_supervisor_emulator'])
test_harness.execute_tests()
