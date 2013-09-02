#!/usr/bin/python
#
# profile <objdump> <pc dump>
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
	pcs = line.split(' ')
	if len(pcs) < 4:
		continue

	for pcStr in pcs:
		pc = int(pcStr, 16)
		func = findFunction(pc)
		if func:
			counts[func] += 1

f.close()

sortedTab = []
for name in counts:
	sortedTab += [ (counts[name], name) ]

for count, name in sorted(sortedTab, key=lambda func: func[0], reverse=True):
	if count == 0:
		break
		
	print count, name

