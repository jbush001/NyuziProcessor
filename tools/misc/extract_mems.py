# 
# Copyright (C) 2011-2014 Jeff Bush
# 
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
# 

#
# Create non-parameterized instances of all FIFOs and SRAMS in the design.
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

