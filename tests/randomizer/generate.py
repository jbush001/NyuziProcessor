
#
# Register 0-1 are reserved as memory address pointers
#   s0, v0 - pointer to base of shared region
#   s1, v1 - pointer to base of private region
#

from random import randint
import math, sys

NUM_INSTRUCTIONS = 256

class Generator:
	def __init__(self, profile):
		self.aProb = profile[0]
		self.bProb = profile[1] + self.aProb
		self.cProb = profile[2] + self.bProb
		self.dProb = profile[3] + self.cProb

	# Note: this will endian swap the data
	def writeWord(self, instr):
		self.file.write('%02x%02x%02x%02x\n' % ((instr & 0xff), ((instr >> 8) & 0xff), ((instr >> 16) & 0xff), ((instr >> 24) & 0xff)))

	def generate(self, path):
		self.file = open(path, 'w')

		# NOTE: number of instructions is hard-coded into this code chunk.  Must
		# reassemble it if that changes
		initialize = [
			0x3c003c40, # s0 = 0xf
			0x8c00005e, # cr30 = s0      ; Enable all strands

			# Load interesting values into scratchpad registers
			0x3c3f4c60, # s3 = 4051
			0x1c3f4463, # s3 = s3 * 4049
			0x1c00ec83, # s4 = s3 * 59
			0x1c019ca4, # s5 = s4 * 103
			0xc18204c5, # s6 = s5 ^ s4
			0x1c0044e6, # s7 = s6 * 17
			0x2000063,	# v3 = s3
			0x2000084,	# v4 = s4
			0x20000a5,	# v5 = s5
			0x20000c6,	# v6 = s6
			0x20000e7,	# v7 = s7
			0xc1d21c63,	# v3{s7} = v3 ^ v4
			0xc1d29884,	# v4{s6} = v4 ^ v5
			0xc1d314a5,	# v5{s5} = v5 ^ v6
			0xc1d390c6,	# v6{s4} = v6 ^ v7
			0xc1d18ce7,	# v7{s3} = v7 ^ v3

			# Set up memory areas and branch
			0xac000040, # s2 = cr0       ; Get strand ID
			0x14000422, # s1 = s2 + 1	
			0x2c004421, # s1 = s1 << 17  ; Multiply by 128k, so each strand starts on a new page
			0x02000021, # v1 = s1        ; set up vector register as the same
			0x2c002842, # s2 = s2 << 10   ; Multiply strand by 1024 bytes (256 instructions)
			0xc28107ff  # pc = pc + s2	 ; jump to start address for this strand
		]

		finalize = [
			0x00000000,	# Because random jumps can be generated above,
			0x00000000, # We need to pad with 8 NOPs to ensure
			0x00000000, # The last instruction doesn't jump over our
			0x00000000, # Cleanup code.
			0x00000000,
			0x00000000,
			0x00000000,
			0x00000000,
			0x00000000,
			0x00000000,
			0x00000000,
			0x00000000,
			0xf7ffff80  # done goto done
		]
		
		for word in initialize:
			self.writeWord(word)		
		
		for strand in range(4):
			for x in range(NUM_INSTRUCTIONS - len(finalize)):
				self.writeWord(self.nextInstruction())

			# stop the strand	
			for word in finalize:
				self.writeWord(word)		
		
		for x in range(128 * 1024):
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

			return 0xc0000000 | (opcode << 23) | (fmt << 20) | (src2 << 15) | (mask << 10) | (dest << 5) | src1
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
				return (opcode << 26) | (fmt << 23) | (imm << 15) | (mask << 10) | (dest << 5) | src1
			else:
				# Not masked, longer immediate value
				imm = randint(0, 0x1fff)
				return (opcode << 26) | (fmt << 23) | (imm << 10) | (dest << 5) | src1
 		elif instructionType < self.cProb:	
			# format C (memory access)
			offset = randint(0, 0x1ff)	# Note, restrict to unsigned
			while True:
				op = randint(0, 15)
				if op != 5 and op != 6:	# Don't do synchronized or control transfer
					break

			if op == 2 or op == 3:
				# Short load, must be 2 byte aligned
				offset &= ~1
			elif op == 7 or op == 8 or op == 9:
				# Vector load, must be 64 byte aligned
				offset &= ~63
			elif op != 0 and op != 1:
				# Word load, must be 4 byte aligned
				offset &= ~3
			# Else this is a byte access and no alignment is required

			load = randint(0, 1)
			mask = self.randomRegister()
			destsrc = self.randomRegister()
			if load:
				ptr = randint(0, 1)	# can load from private or shared region
			else:
				ptr = 1		# can only store in private region

			return 0x80000000 | (load << 29) | (op << 25) | (offset << 15) | (mask << 10) | (destsrc << 5) | ptr
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
