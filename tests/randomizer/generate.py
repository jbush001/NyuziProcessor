
#
# Register 0-1 are reserved as memory address pointers
#   s0, v0 - pointer to base of shared region
#   s1, v1 - pointer to base of private region
#

from random import randint
import math

NUM_INSTRUCTIONS = 64

class Generator:
	def __init__(self):
		pass

	# Note: this will endian swap the data
	def writeWord(self, instr):
		self.file.write('%02x%02x%02x%02x\n' % ((instr & 0xff), ((instr >> 8) & 0xff), ((instr >> 16) & 0xff), ((instr >> 24) & 0xff)))

	def generate(self, path):
		self.file = open(path, 'w')

		# NOTE: number of instructions is hard-coded into this code chunk.  Must
		# reassemble it if that changes
		prolog = [
			0x3c003c40, # s0 = 0xf
			0x8c00005e, # cr30 = s0      ; Enable all strands

			# Load interesting values into scratchpad registers
			0x3c3f4c60, # s3 = 4051
			0x1c3f4463, # s3 = s3 * 4049
			0x1c00ec83, # s4 = s3 * 59
			0x1c019ca4, # s5 = s4 * 103
			0xc18204c5, # s6 = s5 ^ s4
			0x1c0044e6, # s7 = s6 * 17

			# Set up memory areas and branch
			0xac000040, # s2 = cr0       ; Get strand ID
			0x14000422, # s1 = s2 + 1	
			0x2c004421, # s1 = s1 << 17  ; Multiply by 128k, so each strand starts on a new page
			0x02000021, # v1 = s1        ; set up vector register as the same
			0x2c002442, # s2 = s2 << 8   ; Multiply strand by 256 bytes (64 instructions)
			0xc28107ff  # pc = pc + s2	 ; jump to start address for this strand
		]

		epilog = [
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
		
		for word in prolog:
			self.writeWord(word)		
		
		for strand in range(4):
			for x in range(NUM_INSTRUCTIONS - len(epilog)):
				self.writeWord(self.nextInstruction())

			# stop the strand	
			for word in epilog:
				self.writeWord(word)		
		
		self.file.close()

	# Only allocate 8 registers so we are more likely to have dependencies
	def randomRegister(self):
		return randint(2, 10)

	def nextInstruction(self):
		instructionType = randint(0, 10)
		if instructionType < 3:		# 30% chance of format A
			# format A (register arithmetic)
			dest = self.randomRegister()
			src1 = self.randomRegister()
			src2 = self.randomRegister()
			mask = self.randomRegister()
			fmt = randint(0, 6)
			opcode = randint(0, 0x19)	# for now, no floating point
			while True:
				opcode = randint(0, 0x19)	
				if opcode != 8 and (opcode != 13 or fmt != 0):	# Don't allow shuffle for scalars or division
					break

			return 0xc0000000 | (opcode << 23) | (fmt << 20) | (src2 << 15) | (mask << 10) | (dest << 5) | src1
		elif instructionType < 6:	# 30% chance of format B
			# format B (immediate arithmetic)
			dest = self.randomRegister()
			src1 = self.randomRegister()
			fmt = randint(0, 6)
			while True:
				opcode = randint(0, 0x19)	
				if opcode != 13 and opcode != 8:	# Don't allow shuffle for format B or division
					break

			if fmt == 2 or fmt == 3 or fmt == 5 or fmt == 6:
				# Masked, short immediate value
				mask = self.randomRegister()
				imm = randint(0, 0xff)
				return (opcode << 26) | (fmt << 23) | (imm << 15) | (mask << 10) | (dest << 5) | src1
			else:
				# Not masked, longer immediate value
				imm = randint(0, 0x1fff)
				return (opcode << 26) | (fmt << 23) | (imm << 10) | (dest << 5) | src1
 		elif instructionType < 9:	# 30% chance of memory access
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
		else:	# 10% chance of branch
			# format E (branch)
			branchtype = randint(0, 5)
			reg = self.randomRegister()
			offset = randint(0, 6) * 4		# Only forward, up to 6 instructions
			return 0xf0000000 | (branchtype << 25) | (offset << 5) | reg
