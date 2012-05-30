#
# Parse Value Change Dump (VCD) files
# 

class VCDFile:
	def __init__(self, filename):
		self.file = open(filename, 'r')
		self.moduleStack = []
		self.timescale = ''
		self.netNames = {}
		self.netValues = {}
		self.currentTimestamp = 0

		self.parseDefinitions()

	def parseDefinitions(self):
		while True:
			tok = self.readToken()
			if tok == '$scope':
				self.readToken()	# Scope type (ignore)
				self.moduleStack += [ self.readToken() ]
				self.match('$end')
			elif tok == '$var':
				self.readToken() # type
				self.readToken() # size
				id = self.readToken()
				name = self.readToken()
				while True:
					tok = self.readToken()
					if tok == '':
						return True
						
					if tok == '$end':
						break
				
				str = ''
				for element in self.moduleStack + [ name ]:
					if str != '':
						str += '.'
						
					str += element

				self.netNames[str] = id
				self.netValues[id] = 'Z'
			elif tok == '$upscope':
				self.match('$end')
				self.moduleStack.pop()
			elif tok == '$timescale':
				self.timescale = self.readToken()
				self.match('$end')
			elif tok == '$enddefinitions':
				self.match('$end')
				break

	def match(self, expect):
		tok = self.readToken()
		if tok != expect:
			raise Exception('parse error')

	def readToken(self):
		token = ''
		eatLeadingSpace = True
		while True:
			c = self.file.read(1)
			if c == '':
				return ''
			elif c == ' ' or c == '\t' or c == '\r' or c == '\n':
				if not eatLeadingSpace:
					return token
			else:
				eatLeadingSpace = False
				token += c

	def parseTransition(self):
		foundTransitions = False
		oldTime = 0
		while True:
			tok = self.readToken()
			if tok == '':
				if foundTransitions:
					return oldTime
				else:
					return None
			elif tok[0] == '#':
				# This is a timestamp
				oldTime = self.currentTimestamp
				self.currentTimestamp = int(tok[1:])
				return oldTime
			elif tok == '$dumpvars' or tok == '$end':
				continue
			elif tok[0] == 'b':
				# Multi value net.  Value appears first, followed by space, then ID
				foundTransitions = True
				net = self.readToken()
				value = 0
				for bit in tok[1:]:
					value <<= 1
					if bit == '1':
						value |= 1

				self.netValues[net] = value
			else:
				# Single value net.  Single digit value, then identifier
				foundTransitions = True
				self.netValues[tok[1:]] = 1 if tok[0] == '1' else 0
		
	def getNetValue(self, name):
		return self.netValues[self.netNames[name]]
