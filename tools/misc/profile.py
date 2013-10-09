#!/usr/bin/python2
# 
# Copyright 2011-2012 Jeff Bush
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
# USAGE: profile <objdump> <pc dump>
# Prints a breakdown of time spent per function 
#

import sys, re

symbolre = re.compile('(?P<addr>[A-Fa-f0-9]+) g\s+F\s+\.text\s+[A-Fa-f0-9]+\s+(?P<symbol>\w+)')

# Read symbols
functions = []
counts = {}
f = open(sys.argv[1], 'r')
for line in f.readlines():
	got = symbolre.search(line)
	if got:
		sym = got.group('symbol')
		functions += [(int(got.group('addr'), 16), sym)]
		counts[sym] = 0

f.close()

def findFunction(pc):
	for address, name in reversed(functions):
		if pc >= address:
			return name

	return None

# Read profile trace
linesProcessed = 0
f = open(sys.argv[2], 'r')
for line in f.readlines():
	pc = int(line, 16)
	func = findFunction(pc)
	if func:
		counts[func] += 1

f.close()

totalCycles = 0
sortedTab = []
for name in counts:
	sortedTab += [ (counts[name], name) ]
	totalCycles += counts[name]

for count, name in sorted(sortedTab, key=lambda func: func[0], reverse=True):
	if count == 0:
		break
		
	print count, str(float(count * 10000 / totalCycles) / 100) + '%', name
