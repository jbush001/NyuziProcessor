#!/usr/bin/python
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
import re
import os
from os import path

sys.path.insert(0, '..')
import test_harness

#
# This reads the results of a program from stdin and a source file specified
# on the command line.  For each line in the source file prefixed with 
# 'CHECK:', it searches to see if that string occurs in the program output. 
# The strings must occur in order.  It ignores any other output between the
# strings.
#
def check_result(source_file, result):
	PREFIX = 'CHECK: '

	# Read expected results
	resultOffset = 0
	lineNo = 1
	foundCheckLines = False
	with open(source_file, 'r') as f:
		for line in f:
			chkoffs = line.find(PREFIX)
			if chkoffs != -1:
				foundCheckLines = True
				expected = line[chkoffs + len(PREFIX):].strip()
				regexp = re.compile(expected)
				got = regexp.search(result, resultOffset)
				if got:
					resultOffset = got.end()
				else:
					error = 'FAIL: line ' + str(lineNo) + ' expected string ' + expected + ' was not found\n'
					error += 'searching here:' + result[resultOffset:]
					raise test_harness.TestException(error)

			lineNo += 1

	if not foundCheckLines:
		raise test_harness.TestException('FAIL: no lines with CHECK: were found')
		
	return True
	
use_verilator = 'USE_VERILATOR' in os.environ

def run_verilator_test(source_file):
	test_harness.compile_test(source_file, optlevel='3')
	result = test_harness.run_verilator()
	check_result(source_file, result)
	
def run_host_test(source_file):
	subprocess.check_call(['c++', '-w', source_file, '-o', 'obj/a.out'])
	result = subprocess.check_output('obj/a.out')
	check_result(source_file, result)

def run_emulator_test(source_file):
	test_harness.compile_test(source_file, optlevel='3')
	result = test_harness.run_emulator()
	check_result(source_file, result)

test_list = [fname for fname in test_harness.find_files(('.c', '.cpp')) if not fname.startswith('_')]

if 'USE_VERILATOR' in os.environ:
	test_list = [fname for fname in test_list if fname.find('noverilator') == -1]
	test_harness.register_tests(run_verilator_test, test_list)
elif 'USE_HOSTCC' in os.environ:
	test_harness.register_tests(run_host_test, test_list)
else:
	test_harness.register_tests(run_emulator_test, test_list)

test_harness.execute_tests()
