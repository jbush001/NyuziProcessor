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
# Create non-parameterized instances of all FIFOs and SRAMS in the design, which may
# be required by some synthesis tools. This is invoked by the Makefile in the rtl/ 
# directory and isn't called directly.
#

import re
import sys

patterns = [
	[ re.compile('sram1r1w\s+(?P<width>\d+)\s+(?P<depth>\d+)'), [], 'sram1r1w_', '_GENERATE_SRAM1R1W' ],
	[ re.compile('sram2r1w\s+(?P<width>\d+)\s+(?P<depth>\d+)'), [], 'sram2r1w_', '_GENERATE_SRAM2R1W' ],
	[ re.compile('sync_fifo\s+(?P<width>\d+)\s+(?P<depth>\d+)'), [], 'fifo_', '_GENERATE_FIFO' ]
]

for line in sys.stdin.readlines():
	for regexp, itemlist, name, macro in patterns:
		match = regexp.search(line)
		if match:
			pair = (match.group('width'), match.group('depth'))
			if pair not in itemlist:
				itemlist.append(pair)

for regexp, itemlist, prefix, macro in patterns:
	print '`ifdef '  + macro
	first = True
	for width, depth in itemlist:
		if first:
			first = False
		else:
			print 'else',
		
		print 'if (WIDTH == ' + str(width) + ' && SIZE == ' + str(depth) + ')'
		instancename = prefix + str(width) + 'x' + str(depth)
		print '\t' + instancename  + ' ' + instancename + '(.*);'

	print ''
	print '`endif'

