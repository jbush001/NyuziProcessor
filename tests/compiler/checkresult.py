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
import re

#
# This reads the results of a program from stdin and a source file specified 
# on the command line.  For each line in the source file prefixed with 'CHECK:',
# it searches to see if that string occurs in the program output. The strings
# must occur in order.  It ignores any other output between the strings.
#

result = sys.stdin.read()

# Read expected results
resultOffset = 0
lineNo = 1
foundCheckLines = False
f = open(sys.argv[1], 'r')
for line in f.readlines():
	chkoffs = line.find('CHECK: ')
	if chkoffs != -1:
		foundCheckLines = True
		expected = line[chkoffs + 7:].strip()
		regexp = re.compile(expected)
		got = regexp.search(result, resultOffset)
		if got:
			resultOffset = got.end()
		else:
			print 'FAIL: line ' + str(lineNo) + ' expected string ' + expected + ' was not found'
			print 'searching here:' + result[resultOffset:]
			sys.exit(1)
			
	lineNo += 1

if foundCheckLines:
	print 'PASS'	
else:
	print 'FAIL: no lines with CHECK: were found'

