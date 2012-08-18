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
	
