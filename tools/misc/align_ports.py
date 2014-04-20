# 
# Copyright (C) 2011-2014 Jeff Bush
# 
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Library General Public
# License as published by the Free Software Foundation; either
# version 2 of the License, or (at your option) any later version.
# 
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Library General Public License for more details.
# 
# You should have received a copy of the GNU Library General Public
# License along with this library; if not, write to the
# Free Software Foundation, Inc., 51 Franklin St, Fifth Floor,
# Boston, MA  02110-1301, USA.
# 

import sys

def mkspace(n):
	st = ''
	for x in range(n):
		st += ' '
		
	return st
	
def alignPorts(fname):
	with open(fname, 'r') as fp:
		lines = fp.readlines()
		lineInfo = [(-1, -1) for x in range(len(lines))]

		# Figure out stuff about the lines
		maxColumn = 0
		for lineno, line in enumerate(lines):
			comment = line.find('//')
			if comment != -1:
				line = line[:comment]	# Ignore comments for now
	
			nextTok = line.find('input')
			if nextTok == -1 or line[nextTok - 1] not in [ '\t', ' ', '(']:
				nextTok = line.find('output')
				if nextTok == -1 or line[nextTok - 1] not in [ '\t', ' ', '(']:
					continue # Not a port
				else:
					endOfDecl = nextTok + 5
			else:
				endOfDecl = nextTok + 4
	
			nextTok = line.find(']')
			if nextTok == -1:
				# Not array form
				nextTok = line.find('reg')
				if nextTok != -1:
					endOfDecl = nextTok + 2	# Length of 'reg'
			else:
				endOfDecl = nextTok
		
			startOfId = endOfDecl + 1
			while line[startOfId] in [ '\t', ' ' ]:
				startOfId += 1

			lineInfo[lineno] = ( endOfDecl + 1, startOfId )
			if startOfId > maxColumn:
				maxColumn = startOfId

		alignColumn = maxColumn + 1

		# Walk through a fix spacing
		newlines = []
		for line, (left, right) in zip(lines, lineInfo):
			if left == -1:
				newlines += [ line ]
				pass
			else:
				newlines += [ line[:left] + mkspace(alignColumn - left) + line[right:] ]

	with open(fname, 'w') as fp:
		for line in newlines:
			fp.write(line)

for fname in sys.argv[1:]:
	alignPorts(fname)
