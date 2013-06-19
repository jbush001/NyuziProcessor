#
# Run Verilog simulation with GENERATE_PROFILE_DATA defined in strand select stage.
# This will output a list of program counters of issued instructions.  This
# program post processes that output and tabulates counts for functions.  The
# Addresses of functions must be manually entered in the list below.
#

import sys

# firmware/3d-engine
labels = [
	('StartFrame', 0x4),
	('FinishFrame', 0x208),
	('DrawTriangles', 0x210),
	('RasterizeTriangle', 0x2ac),
	('SetupEdge', 0x3bc),
	('SubdivideTile', 0x500),
	('TransformVertex', 0x6e4),
	('MulMatrixVec', 0x77c),
	('FillMasked', 0x840),
	('FillRects', 0x8a8),
	('FlushFrameBuffer', 0xa48),
	('AllocJob', 0xaa0),
	('EnqueueJob', 0xaec),
	('Spinlock', 0xb38),
	('StrandMain', 0xb78),
	('HandleFence', 0xc10),
	('_start', 0xc2c)
]

counts = { }
for name, address in labels:
	counts[name] = 0

for line in sys.stdin.readlines():
	pc = int(line, 16)
	for name, address in reversed(labels):
		if pc >= address:
			counts[name] += 1
			break

for name in counts:
	print name, counts[name]
