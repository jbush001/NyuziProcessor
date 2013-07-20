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

#
# Generate a pseudorandom instruction stream
#
# Register 0-1 are reserved as memory address pointers
#   s0, v0 - pointer to base of shared region
#   s1, v1 - pointer to base of private region (for this strand)
#
# Memory map:
#  00000 start of code (64k each), strand 0
#  10000 start of code, strand 1
#  20000 start of code, strand 2
#  30000 start of code, strand 3
#  40000 start of private data (64k each), strand 0
#  50000 start of private data, strand 1
#  60000 start of private data, strand 2
#  70000 start of private data, strand 3
# 

from random import randint
import math, sys

STRAND_CODE_SEG_SIZE = 0x10000	# 256k code area / 4 strands = 64k each

class Generator:
	def __init__(self, profile):
		self.aProb = profile[0]
		self.bProb = profile[1] + self.aProb
		self.cProb = profile[2] + self.bProb
		self.dProb = profile[3] + self.cProb

	# Note: this will endian swap the data
	def writeWord(self, instr):
		self.file.write('%02x%02x%02x%02x\n' % ((instr & 0xff), ((instr >> 8) & 0xff), ((instr >> 16) & 0xff), ((instr >> 24) & 0xff)))

	def generate(self, path, numInstructions):
		if numInstructions > STRAND_CODE_SEG_SIZE / 4 - 100:
			raise Exception('too many instructions')

		self.file = open(path, 'w')

		# NOTE: number of instructions is hard-coded into this code chunk.  Must
		# reassemble it if that changes
		initialize = [
			0x07803c20, # si0 = 15
			0x8c00003e, # cr30 = s0
			
			# Initialize registers with non-zero values
			0x07bf4c60, # si3 = 4051
			0x03bf4463, # si3 = si3 * 4049
			0x0380ec83, # si4 = si3 * 59
			0x03819ca4, # si5 = si4 * 103
			0xc03204c5, # si6 = si5 ^ si4
			0x038044e6, # si7 = si6 * 17
			0x40000063, # vi3 = si3
			0x40000084, # vi4 = si4
			0x400000a5, # vi5 = si5
			0x400000c6, # vi6 = si6
			0x400000e7, # vi7 = si7
			0xd4321c63, # vi3{si7} = vi3 ^ vi4
			0xd4329884, # vi4{si6} = vi4 ^ vi5
			0xd43314a5, # vi5{si5} = vi5 ^ vi6
			0xd43390c6, # vi6{si4} = vi6 ^ vi7
			0xd4318ce7, # vi7{si3} = vi7 ^ vi3

			# Load memory pointers
			0xac000040, # s2 = cr0
			0x02801022, # si1 = si2 + 4 (start of data segment)
			0x05804021, # si1 = si1 << 16 (multiply by 64k)
			0x07800500, # si8 = 1
			0x05804108, # si8 = si8 << 16
			0x03000508, # si8 = si8 - 1
			0x22842000, # loop0: vi0{si8} = vi0 + 8
			0x04800508, # si8 = si8 >> 1
			0xf5fffe88, # if si8 goto loop0
			0xc4508420, # vi1 = vi0 + si1
			
			# Compute initial code branch address
			0x05804042, # si2 = si2 << 16
			0xc05107ff # si31 = si31 + si2
		]

		finalize = [
			0x00000000,	# Because random jumps can be generated above,
			0x00000000, # We need to pad with 8 NOPs to ensure
			0x00000000, # The last instruction doesn't jump over our
			0x00000000, # Cleanup code.
			0x00000000,
			0x00000000,
			0x00000000,	
			0x8c00001d, # Store to cr29, which will halt this strand
			0x00000000, # Flush rest of pipeline
			0x00000000,
			0x00000000,
			0x00000000,
			0xf7ffff80  # done goto done
		]

		# Shared initialization code
		for word in initialize:
			self.writeWord(word)		
		
		for strand in range(4):
			# Generate instructions
			for x in range(numInstructions - len(finalize)):
				self.writeWord(self.nextInstruction())

			# Generate code to terminate strand
			for word in finalize:
				self.writeWord(word)		
				
			# Pad out to total size
			for x in range((STRAND_CODE_SEG_SIZE / 4) - numInstructions):
				self.writeWord(0)

		# Fill in strand local memory areas with random data
		for x in range(0x10000):
			self.writeWord(randint(0, sys.maxint))
		
		self.file.close()

	# Only allocate 8 registers so we are more likely to have dependencies
	def randomRegister(self):
		return randint(2, 10)

	def nextInstruction(self):
		instructionType = randint(0, 100)
		if instructionType < self.aProb:
			# format A (register arithmetic)
			dest = self.randomRegister()
			src1 = self.randomRegister()
			src2 = self.randomRegister()
			mask = self.randomRegister()
			fmt = randint(0, 6)
			while True:
				opcode = randint(0, 0x1a)	
				if opcode == 8:
					continue	# Don't allow division (could generate div by zero)
					
				if opcode == 13 and (opcode != 4 and opcode != 5 and opcode != 6):
					continue	# Shuffle can only be used with vector/vector forms
					
				if opcode == 0x1a and fmt != 1:
					continue	# getlane must be v, s
					
				break

			return 0xc0000000 | (fmt << 26) | (opcode << 20) | (src2 << 15) | (mask << 10) | (dest << 5) | src1
		elif instructionType < self.bProb:	
			# format B (immediate arithmetic)
			dest = self.randomRegister()
			src1 = self.randomRegister()
			fmt = randint(0, 6)
			while True:
				opcode = randint(0, 0x1a)	
				if opcode != 13 and opcode != 8:	# Don't allow shuffle for format B or division
					break

			if opcode == 0x1a:
				fmt = 1		# getlane must be v, s

			if fmt == 2 or fmt == 3 or fmt == 5 or fmt == 6:
				# Masked, short immediate value
				mask = self.randomRegister()
				imm = randint(0, 0xff)
				return (fmt << 28) | (opcode << 23) | (imm << 15) | (mask << 10) | (dest << 5) | src1
			else:
				# Not masked, longer immediate value
				imm = randint(0, 0x1fff)
				return (fmt << 28) | (opcode << 23) | (imm << 10) | (dest << 5) | src1
 		elif instructionType < self.cProb:	
			# format C (memory access)
			offset = randint(0, 0x7f) * 4	# Note, restrict to unsigned.  Word aligned.
			while True:
				op = randint(0, 15)
				if op != 5 and op != 6:	# Don't do synchronized or control transfer
					break

			if op == 7 or op == 8 or op == 9:
				# Vector load, must be 64 byte aligned
				offset &= ~63

			load = randint(0, 1)
			mask = self.randomRegister()
			destsrc = self.randomRegister()
			if load:
				ptr = randint(0, 1)     # can load from private or shared region
			else:
				ptr = 1         # can only store in private region

			inst = 0x80000000 | (load << 29) | (op << 25) | (destsrc << 5) | ptr

			if op == 8 or op == 9 or op == 11 or op == 12 or op == 14 or op == 15:
				# Masked
				inst |= (offset << 15) | (mask << 10)
			else:
				inst |= (offset << 10)	# Not masked


			# CHECK
			chkop = (inst >> 25) & 0xf
			if chkop == 7 or chkop == 8 or chkop == 9:
				if chkop == 7:
					chkoffs = inst >> 10
				else:
					chkoffs = inst >> 15
					
				if (chkoffs & 0xf) != 0:
					print 'GENERATED BAD INSTR'
					sys.exit(1)
			return inst
		elif instructionType < self.dProb:
			while True:
				op = randint(0, 4)
				if op != 1:	# Don't do dinvalidate: c emulator can't do this.
					break

			ptrReg = randint(0, 1)
			offset = randint(0, 0x1ff) & ~3
			return 0xe0000000 | (op << 25) | (offset << 15) | ptrReg
		else:
			# format E (branch)
			branchtype = randint(0, 5)
			reg = self.randomRegister()
			offset = randint(0, 6) * 4		# Only forward, up to 6 instructions
			return 0xf0000000 | (branchtype << 25) | (offset << 5) | reg

# Percent change of generating instruction of format (0-100)
# A, B, C, D, (e is remainder)
profiles = [
	[ 50, 0, 0, 0 ],	# Branches and register operations
	[ 30, 30, 30, 5 ],	# More general purpose (5% branches)
	[ 0, 0, 100, 0 ],	# Only memory accesses
	[ 35, 35, 30, 0 ]	# No branches
]

if len(sys.argv) < 2:
	print 'Usage: python generate.py <profile> [num instructions]'
else:
	profileIndex = int(sys.argv[1])
	if len(sys.argv) > 2:
		numInstructions = int(sys.argv[2])
	else:
		numInstructions = 768
	
	print 'using profile', profileIndex, 'generating', numInstructions, 'instructions'
	Generator(profiles[profileIndex]).generate('random.hex', numInstructions)
	print 'wrote random test program into "random.hex"'
