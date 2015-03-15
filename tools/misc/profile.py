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
# USAGE: profile <objdump file> <pc dump file>
# Prints a breakdown of time spent per function. 
# - 'objdump file' parameter points to a file that was produced using:
#   /usr/local/llvm-nyuzi/bin/llvm-objdump -t <path to ELF file>
# - 'pc dump file' points to a file that was produced by the verilog model
#   using +profile=<filename>.  It is a list of hexadecimal program counter
#   samples, one per line.
# 

import sys
import re

symbolre = re.compile('(?P<addr>[A-Fa-f0-9]+) g\s+F\s+\.text\s+[A-Fa-f0-9]+\s+(?P<symbol>\w+)')

functions = []	# Each element is (address, name)
counts = {}

def findFunction(pc):
	global functions
	
	low = 0
	high = len(functions)
	while low < high:
		mid = (low + high) / 2
		if pc < functions[mid][0]:	
			high = mid
		else:
			low = mid + 1

	if low == len(functions):
		return None

	return functions[low - 1][1]

# Read symbols
with open(sys.argv[1], 'r') as f:
	for line in f.readlines():
		got = symbolre.search(line)
		if got:
			sym = got.group('symbol')
			functions += [(int(got.group('addr'), 16), sym)]
			counts[sym] = 0

functions.sort(key=lambda a: a[0])

# Read profile trace
linesProcessed = 0
with open(sys.argv[2], 'r') as f:
	for line in f.readlines():
		pc = int(line, 16)
		func = findFunction(pc)
		if func:
			counts[func] += 1

totalCycles = 0
sortedTab = []
for name in counts:
	sortedTab += [ (counts[name], name) ]
	totalCycles += counts[name]

for count, name in sorted(sortedTab, key=lambda func: func[0], reverse=True):
	if count == 0:
		break
		
	print count, str(float(count * 10000 / totalCycles) / 100) + '%', name

