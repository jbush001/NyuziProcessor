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
					print 'FAIL: line ' + str(lineNo) + ' expected string ' + expected + ' was not found'
					print 'searching here:' + result[resultOffset:]
					return False

			lineNo += 1

	if not foundCheckLines:
		print 'FAIL: no lines with CHECK: were found'
		return False
		
	return True
	
if len(sys.argv) > 1:
	files = sys.argv[1:]
else:
	files = [fname for fname in os.listdir('.') if (fname.endswith(('.c', '.cpp')) and not fname.startswith('_')) ]

failing_tests = 0

if 'USE_HOSTCC' in os.environ:
	for source_file in files:
		print 'Testing ' + source_file + ' (host)',
		try:
			subprocess.check_call(['cc', '-w', source_file, '-o', 'obj/a.out'])
			result = subprocess.check_output('obj/a.out')
			if not check_result(source_file, result):
				failing_tests += 1
				print 'FAIL'
			else:
				print 'PASS'
		except KeyboardInterrupt:
			sys.exit(1)
		except:
			print 'FAIL'
			failing_tests += 1
elif 'USE_VERILATOR' in os.environ:
	for source_file in files:
		if source_file.find('noverilator') != -1:
			continue
		
		print 'Testing ' + source_file + ' (verilator)',
		try:
			hexfile = test_harness.compile_test(source_file)
			result = subprocess.check_output(['../../bin/verilator_model', '+bin=' + hexfile])
			if not check_result(source_file, result):
				failing_tests += 1
				print 'FAIL'
			else:
				print 'PASS'
		except KeyboardInterrupt:
			sys.exit(1)
		except:
			print 'FAIL'
			failing_tests += 1
else:
	# Emulator
	for source_file in files:
		for optlevel in ['s', '0', '3']:
			print 'Testing ' + source_file + ' at -O' + optlevel + ' (emulator)',
			try:
				hexfile = test_harness.compile_test(source_file, optlevel=optlevel)
				result = subprocess.check_output(['../../bin/emulator', hexfile])
				if not check_result(source_file, result):
					failing_tests += 1
					print 'FAIL'
				else:
					print 'PASS'
			except KeyboardInterrupt:
				sys.exit(1)
			except:
				print 'FAIL'
				failing_tests += 1

print 'total tests', len(files)
print 'failed', failing_tests
if failing_tests > 0:
	sys.exit(1)

