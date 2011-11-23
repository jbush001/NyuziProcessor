import sys, struct

class DebugInfo:
	# a run is (start addr, length, filename index, startLine)
	def __init__(self, filename):
		file = open(filename, 'r')
		magic, numRuns, stringTableSize = struct.unpack('III', file.read(12))
		self.runs = [ struct.unpack('IIII', file.read(16)) for x in range(numRuns) ]
		print self.runs
		stringData = file.read(stringTableSize)
		rawStrings = stringData.split('\0')
		index = 0
		self.strings = {}
		for str in rawStrings:
			self.strings[index] = str
			index += len(str) + 1

	def lineForAddress(self, addr):
		low = 0
		high = len(self.runs)
		while low < high:
			mid = (low + high) / 2
			startAddr, length, filename, startLine = self.runs[mid]
			if addr < startAddr:
				high = mid - 1
			elif addr > startAddr + length * 4:
				low = mid + 1
			else:
				return ( self.strings[filename], ((addr - startAddr) / 4) + startLine )

		return None, None

def endianSwap(val):
	return ((val & 0xff) << 24) | ((val & 0xff00) << 8) | ((val & 0xff0000) >> 8) | ((val & 0xff000000) >> 24)
	
if len(sys.argv) != 2:
	print 'enter a hex filename'
	sys.exit(1)

sourceCodes = {}
path = sys.argv[1]
ext = path.rfind('.')
if ext == -1:
	print 'no extension'
	sys.exit(1)

debug = DebugInfo(path[:ext] + '.dbg')
file = open(path, 'r')
pc = 0
for line in file:
	filename, lineno = debug.lineForAddress(pc)
	if filename == None:
		src = ''
	elif filename == 'start.asm':
		src = '\t\tgoto\t_start'
	else:
		if filename not in sourceCodes:
			sourceCodes[filename] = open(filename).readlines()
		
		src = sourceCodes[filename][lineno - 1].strip('\n').replace('\t', '    ')

	print '%08x  %08x    %s' % (pc, endianSwap(int(line, 16)), src)	
	pc += 4
	
