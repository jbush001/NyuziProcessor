import sys
from vcd_file import *
from disassemble import *
from l2cache import *
from register import *

vcd = VCDFile(sys.argv[1])
annotators = [ L2CacheInterfaceAnnotator(), RegisterAnnotator(), L2LineUpdate(),
	SystemMemoryInterface(), L2DirtyBits() ]

lastClock = 0
while True:
	ts = vcd.parseTransition()
	if ts == None:
		break

	newClock = vcd.getNetValue('pipeline_sim.core.pipeline.clk')
	if newClock == 1 and lastClock == 0:
		for a in annotators:
			a.clockTransition(vcd)

	lastClock = newClock
	
