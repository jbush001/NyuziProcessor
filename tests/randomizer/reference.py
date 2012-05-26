#
# Processor emulation reference model
#

import struct

PC_REG = 31
NUM_VECTOR_LANES = 16

def bitField(value, lowBitOffset, length, signExtend = False):
	result = (value >> lowBitOffset) & ((1 << length) - 1)
	if signExtend and (result & (1 << (length - 1))) != 0:
		result = -((result ^ ((1 << length) - 1)) + 1) 

	return result

def clz(value):
	for i in range(32):
		if (value & 0x80000000) != 0:
			return i
			
		value <<= 1
	
	return 32

def ctz(value):
	for i in range(32):
		if (value & 1) != 0:
			return i
			
		value >>= 1
	
	return 32

OPERATIONS = { 
	0 : lambda x, y: x | y,
	1 : lambda x, y: x & y,
	2 : lambda x, y: -y,
	3 : lambda x, y: x ^ y,
	4 : lambda x, y: ~y,
	5 : lambda x, y: x + y,
	6 : lambda x, y: x - y,
	7 : lambda x, y: x * y,
	8 : lambda x, y: x / y,
	9 : lambda x, y: x >> (y & 0x1f),		# XXX signed right shift
	10 : lambda x, y: x >> (y & 0x1f),		# XXX unsigned right shift
	11 : lambda x, y: x << (y & 0x1f),
	12 : lambda x, y: clz(y),
	14 : lambda x, y: ctz(y),
	15 : lambda x, y: y,
	16 : lambda x, y: x == y,
	17 : lambda x, y: x != y,
	18 : lambda x, y: x > y,		# XXX signed comparisons
	19 : lambda x, y: x >= y,
	20 : lambda x, y: x < y,
	21 : lambda x, y: x <= y,
	22 : lambda x, y: x > y,			# XXX unsigned comparisons
	23 : lambda x, y: x >= y,
	24 : lambda x, y: x < y,
	25 : lambda x, y: x <= y
}

def isCompareOp(operation):
	return (operation >= 16 and operation <= 26) or (operation >= 44 and operation <= 47)

class Strand:
	def __init__(self, processor, id):	
		self.scalarRegs = [ 0 for x in range(32) ]
		self.vectorRegs = [ [ 0 for x in range(NUM_VECTOR_LANES) ] for y in range(32) ]
		self.pc = 0
		self.processor = processor
		self.regtrace = []
		self.id = id

	def setScalarReg(self, reg, value):
		self.scalarRegs[reg] = value
		self.regtrace += [ (self.pc, 's%2d' % reg, value) ]
		print str(self.id) + ' s' + str(reg) + ' <= ' + hex(value)
		
	def getScalarReg(self, reg):
		if reg == 31:
			return self.pc
		else:
			return self.scalarRegs[reg]
		
	def setVectorReg(self, reg, mask, value):
		for lane in range(NUM_VECTOR_LANES):
			if mask & (1 << lane):
				self.vectorRegs[reg][lane] = value[lane]

		self.regtrace += [ (self.pc, 'v%2d' % reg, mask, value) ]

	def executeAInstruction(self, instruction):
		fmt = bitField(instruction, 20, 3)
		op = bitField(instruction, 23, 6)
		op1reg = bitField(instruction, 0, 5)
		op2reg = bitField(instruction, 15, 5)
		destreg = bitField(instruction, 5, 5)
		maskreg = bitField(instruction, 10, 5)

		if op == 13 and fmt != 0:
			# This is a shuffle
			src = self.getVectorReg(op2reg)
			result = [ src[lane & 0x1f] for lane in range(NUM_VECTOR_LANES) ]
			self.setVectorReg(destreg, 0xffff, result)
			return
		
		if op not in OPERATIONS:
			raise Exception('bad A instruction op ' + str(op) + ' instruction ' + hex(instruction))
		
		operationFn = OPERATIONS[op]
		if fmt == 0:
			# Scalar operation
			result = operationFn(self.getScalarReg(op1reg), self.getScalarReg(op2reg))
			if destreg == PC_REG:
				self.pc = result

			self.setScalarReg(destreg, result)
		else:
			# Vector operation
			if fmt == 2 or fmt == 5:
				mask = self.getScalarReg(maskreg)
			elif fmt == 3 or fmt == 6:
				mask = self.getScalarReg(maskreg) ^ 0xffff
			else:
				mask = 0xffff

			if isCompareOp(op):
				result = 0
				operand1 = self.vectorRegs[op1reg]
			
				# Vector compares work a little differently than other arithmetic
				# operations: the results are packed together in the 16 low
				# bits of a scalar register
				if fmt < 4:
					# Vector/Scalar operation
					operand2 = self.getScalarReg(op2reg)
					for lane in range(NUM_VECTOR_LANES):
						if (mask & 1) != 0:
							result |= 0x8000 if operationFn(operand1[lane], operand2) != 0 else 0

						mask >>= 1
						result >>= 1
				else:
					# Vector/Vector operation
					operand2 = self.vectorRegs[op2reg]
					for lane in range(NUM_VECTOR_LANES):
						if (mask & 1) != 0:
							result |= 0x8000 if operationFn(operand1[lane], operand2[lane]) != 0 else 0

						mask >>= 1
						result >>= 1
				
				self.setScalarReg(destreg, result)
			else:
				# Vector arithmetic...
				operand1 = self.vectorRegs[op1reg]
				result = [ 0 for x in range(NUM_VECTOR_LANES) ]

				if fmt < 4:
					# Vector/Scalar operation
					operand2 = self.getScalarReg(op2reg)
					for lane in range(NUM_VECTOR_LANES):
						result[lane] = operationFn(operand1[lane], operand2)

					self.setVectorReg(destreg, mask, result)
				else:
					# Vector/Vector operation
					operand2 = self.vectorRegs[op2reg]
					for lane in range(NUM_VECTOR_LANES):
						result[lane] = operationFn(operand1[lane], operand2[lane])

					self.setVectorReg(destreg, mask, result)


	def executeBInstruction(self, instruction):
		fmt = bitField(instruction, 23, 3)
		op = bitField(instruction, 26, 5)
		op1reg = bitField(instruction, 0, 5)
		maskreg = bitField(instruction, 10, 5)
		destreg = bitField(instruction, 5, 5)
		hasMask = fmt == 2 or fmt == 3 or fmt == 5 or fmt == 6

		if hasMask:
			immediateValue = bitField(instruction, 15, 8, True)
		else:
			immediateValue = bitField(instruction, 10, 13, True)

		if op not in OPERATIONS:
			raise Exception('bad B instruction pc ' + str(self.pc) + ' op ' + str(op) + ' instruction ' + hex(instruction))

		operationFn = OPERATIONS[op]
		if fmt == 0:
			# Scalar
			result = operationFn(self.getScalarReg(op1reg), immediateValue)
			if destreg == PC_REG:
				self.pc = result
			else:
				self.setScalarReg(destreg, result)
		else:
			# Vector
			if fmt == 2 or fmt == 5: 
				mask = self.getScalarReg(maskreg)
			elif fmt == 3 or fmt == 6: 
				mask = ~self.getScalarReg(maskreg)
			else:
				mask = 0xffff
				
			if isCompareOp(op):
				# Vector compares work a little differently than other arithmetic
				# operations: the results are packed together in the 16 low
				# bits of a scalar register
				result = 0
				operand1 = self.vectorRegs[op1reg]
				for lane in range(NUM_VECTOR_LANES):
					if (mask & 1) != 0:
						result |= 0x8000 if operationFn(operand1[lane], immediateValue) != 0 else 0

					mask >>= 1
					result >>= 1

				self.setScalarReg(destreg, result)
			else:
				result = [ 0 for x in range(NUM_VECTOR_LANES) ]
				for lane in range(NUM_VECTOR_LANES):
					if fmt == 1 or fmt == 2 or fmt == 3:
						operand1 = self.vectorRegs[op1reg][lane]
					else:
						operand1 = self.getScalarReg(op1reg)
						
					result[lane] = operationFn(operand1, immediateValue)
					
				self.setVectorReg(destreg, mask, result)

	def executeScalarLoadStore(self, instruction):
		op = bitField(instruction, 25, 4)
		ptrreg = bitField(instruction, 0, 5)
		offset = bitField(instruction, 15, 10, True)
		destsrcreg = bitField(instruction, 5, 5)
		isLoad = bitField(instruction, 29, 1)
	
		ptr = self.getScalarReg(ptrreg) + offset
		# XXX check if pointer is out of range
		
		if isLoad:
			if op == 0: # Byte
				value = (self.processor.memory[ptr / 4] >> (ptr % 4)) & 0xff
			elif op == 1: # Byte, sign extend
				value = (self.processor.memory[ptr / 4] >> (ptr % 4)) & 0xff	### XXX sign extend
			elif op == 2: # Short
				value = (self.processor.memory[ptr / 2] >> (ptr % 2)) & 0xffff	
			elif op == 3: # Short, sign extend
				value = (self.processor.memory[ptr / 2] >> (ptr % 2)) & 0xffff	### XXX sign extend	
			elif op == 4 or op == 5: # Load word or load linked
				value = self.processor.memory[ptr / 4]
			elif op == 6: # Load control register
				value = 0
			
			if destsrcreg == PC_REG:
				self.pc = value

			self.setScalarReg(destsrcreg, value)
		else:
			# Store
			# Shift and mask in the value.
			valueToStore = self.getScalarReg(destsrcreg)
		
			# XXX need to align and mask
			if op == 0 or op == 1:
				self.processor.memory[ptr / 4] = valueToStore & 0xff
			elif op == 2 or op == 3:
				self.processor.memory[ptr / 4] = valueToStore & 0xffff
			elif op == 4 or op == 5:
				self.processor.memory[ptr / 4] = valueToStore


	def executeVectorLoadStore(self, instruction):
		op = bitField(instruction, 25, 4)
		ptrreg = bitField(instruction, 0, 5)
		offset = bitField(instruction, 15, 10, True)
		maskreg = bitField(instruction, 10, 5)
		destsrcreg = bitField(instruction, 5, 5)
		isLoad = bitField(instruction, 29, 1)
	
		# Compute pointers for lanes. Note that the pointers will be indices
		# into the memory array (which is an array of ints).
		if op == 7 or op == 8 or op == 9:	# Block vector access
			basePtr = (self.getScalarReg(ptrreg) + offset) / 4
			ptr = [ basePtr + lane for lane in range(NUM_VECTOR_LANES) ]
		elif op == 10 or op == 11 or op == 12:	# Strided vector access
			basePtr = self.getScalarReg(ptrreg) / 4
			ptr = [basePtr + lane * offset / 4 for lane in range(NUM_VECTOR_LANES) ]
		elif op == 13 or op == 14 or op == 15: # Scatter/gather load/store
			ptr = [ self.vectorRegs[ptrreg][lane] / 4 for lane in range(NUM_VECTOR_LANES) ]
		
		# Compute mask value
		if op == 7 or op == 10 or op == 13:	# Not masked
			mask = 0xffff
		elif op == 8 or op == 11 or op == 14: # Masked
			mask = self.getScalarReg(maskreg)
		elif op == 9 or op == 12 or op == 15: # Invert Mask
			mask = ~self.getScalarReg(maskreg)
	
		# Do the actual memory transfers
		if isLoad:
			# Load
			result = [ 0 for x in range(NUM_VECTOR_LANES) ]
			for lane in range(NUM_VECTOR_LANES):
				if mask & (1 << lane):
					result[lane] = self.processor.memory[ptr[lane]]
				
			self.setVectorReg(destsrcreg, mask, result)
		else:
			# Store
			for lane in range(NUM_VECTOR_LANES):
				if mask & 1:
					self.processor.memory[ptr[lane]] = self.vectorRegs[destsrcreg][lane]
					
				mask >>= 1

	def executeControlRegister(self, instruction):
		controlRegister = bitField(instruction, 0, 5)
		destsrcreg = bitField(instruction, 5, 5)
		if bitField(instruction, 29, 1):
			# Load
			if controlRegister == 30:
				self.setScalarResult(destsrcreg, self.processor.strandEnableMask)
			elif controlRegister == 0:
				self.setScalarReg(destsrcreg, self.id)
		else:
			# Store
			if controlRegister == 30:
				self.processor.strandEnableMask = self.getScalarReg(destsrcreg)
				print 'strand enable mask is now', self.processor.strandEnableMask
			elif controlRegister == 31:
				self.processor.halt = True

	def executeCInstruction(self, instruction):
		type = bitField(instruction, 25, 4)
		if type == 6:
			self.executeControlRegister(instruction)
		elif type < 6:
			self.executeScalarLoadStore(instruction)
		else:
			self.executeVectorLoadStore(instruction)

	def executeEInstruction(self, instruction):
		srcReg = bitField(instruction, 0, 5)
		branchType = bitField(instruction, 25, 3)
		if branchType == 0: 
			branchTaken = (self.getScalarReg(srcReg) & 0xffff) == 0xffff
		elif branchType == 1: 
			branchTaken = (self.getScalarReg(srcReg) & 0xffff) == 0
		elif branchType == 2:
			branchTaken = (self.getScalarReg(srcReg) & 0xffff) != 0
		elif branchType == 3:
			branchTaken = 1
		elif branchType == 4:	# call
			branchTaken = 1
			self.setScalarReg(30, self.pc + 4)
		elif branchType == 5: 
			branchTaken = (self.getScalarReg(srcReg) & 0xffff) != 0xffff
		else:
			raise Exception("bad branch type " + str(branchType))

		if branchTaken:
			offset = bitField(instruction, 5, 21, True)
			self.pc += offset

	def executeInstruction(self):
		instruction = self.processor.memory[self.pc / 4]
		print 'fetch instruction from %08x == %08x' % (self.pc, instruction)
		self.pc += 4

		if (instruction & 0xe0000000) == 0xc0000000:
			self.executeAInstruction(instruction)
		elif (instruction & 0x80000000) == 0:
			self.executeBInstruction(instruction)
		elif (instruction & 0xc0000000) == 0x80000000:
			self.executeCInstruction(instruction)
		elif (instruction & 0xf0000000) == 0xf0000000:
			self.executeEInstruction(instruction)
		else:
			print 'Bad Instruction', instruction

def swap(x):
	return ((x & 0xff000000) >> 24) | ((x & 0xff0000) >> 8) | ((x & 0xff00) << 8) | ((x & 0xff) << 24)

class Processor:
	def __init__(self):
		self.strands = [ Strand(self, id) for id in range(4) ]
		self.memory = [ 0 for x in range(768 * 1024) ]
		self.strandEnableMask = 1
		self.halt = False
		
	def runTest(self, filename):
		f = open(filename, "rb")
		index = 0
		for line in f:
			self.memory[index] = swap(int(line, 16))
			index += 1
		
		f.close()

		cycleCount = 0
		while cycleCount < 1000 and not self.halt and self.strandEnableMask != 0:
			self.instructionCycle()

		return [ self.strands[i].regtrace for i in range(4) ]
		
	def instructionCycle(self):
		for index, strand in enumerate(self.strands):
			if self.strandEnableMask & index:
				strand.executeInstruction()
