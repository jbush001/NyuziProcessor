import sys
from vcd_file import *
from disassemble import *
from l2cache import L2CacheAnnotator
from register import RegisterAnnotator

vcd = VCDFile(sys.argv[1])
annotators = [ L2CacheAnnotator(), RegisterAnnotator() ]

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
	
