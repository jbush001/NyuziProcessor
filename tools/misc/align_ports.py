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
