import sys
from vcd_file import *
from l2cache import *
from register import *

vcd = VCDFile(sys.argv[1])
annotators = [ 
	L2CacheInterfaceAnnotator(), 
	L2LineUpdate(),
	L2DirtyBits(),
#	RegisterAnnotator(), 
	SystemMemoryInterface() ]

lastClock = 0
while True:
	ts = vcd.parseTransition()
	if ts == None:
		break

	newClock = vcd.getNetValue('simulator_top.core.pipeline.clk')
	if newClock == 1 and lastClock == 0:
		for a in annotators:
			a.clockTransition(vcd)

	lastClock = newClock
	
