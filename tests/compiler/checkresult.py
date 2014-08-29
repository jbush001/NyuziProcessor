#!/usr/bin/python

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

import sys
import re

#
# This reads the results of a program from stdin and a source file specified 
# on the command line.  For each line in the source file prefixed with 'CHECK:',
# it searches to see if that string occurs in the program output. The strings
# must occur in order.  It ignores any other output between the strings.
#

result = sys.stdin.read()

# Read expected results
resultOffset = 0
lineNo = 1
foundCheckLines = False
f = open(sys.argv[1], 'r')
for line in f.readlines():
	chkoffs = line.find('CHECK: ')
	if chkoffs != -1:
		foundCheckLines = True
		expected = line[chkoffs + 7:].strip()
		regexp = re.compile(expected)
		got = regexp.search(result, resultOffset)
		if got:
			resultOffset = got.end()
		else:
			print 'FAIL: line ' + str(lineNo) + ' expected string ' + expected + ' was not found'
			print 'searching here:' + result[resultOffset:]
			sys.exit(1)
			
	lineNo += 1

if foundCheckLines:
	print 'PASS'	
else:
	print 'FAIL: no lines with CHECK: were found'

