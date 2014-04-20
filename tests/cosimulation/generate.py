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


#
# Generate a pseudorandom instruction stream
#
# Register 0-1 are reserved as memory address pointers
#   s0, v0 - pointer to base of shared region
#   s1, v1 - pointer to base of private region (for this strand)
#
# Memory map:
#  00000 start of code (strand0, 1, 2, 3)
#  40000 start of private data (64k each), strand 0
#  50000 start of private data, strand 1
#  60000 start of private data, strand 2
#  70000 start of private data, strand 3
# 

from random import randint
import math, sys, argparse

STRAND_CODE_SEG_SIZE = 0x10000	# 256k code area / 4 strands = 64k each
MAX_INSTRUCTIONS = STRAND_CODE_SEG_SIZE / 4 - 100

class Generator:
	def __init__(self, profile):
		self.aProb = profile[0]
		self.bProb = profile[1] + self.aProb
		self.cProb = profile[2] + self.bProb
		self.dProb = profile[3] + self.cProb

	# Note: this will endian swap the data
	def writeWord(self, instr):
		self.file.write('\t\t.long 0x%08x\n' % instr)

	def generate(self, path, numInstructions):
		if numInstructions > MAX_INSTRUCTIONS:
			raise Exception('too many instructions')

		self.file = open(path, 'w')

		initCode = '''

		.globl _start
_start:	move s1, 15
		setcr s1, 30	; start all threads
			
		; Initialize registers
		move s0, 0
		move s3, 4051
		mul_i s3, s3, 4049
		mul_i s4, s3, 59
		mul_i s5, s4, 103
		xor s6, s5, s4
		mul_i s7, s6, 17
		move s8, 0
		move s9, 0
		move s10, 0
		move v0, 0
		move v1, 0
		move v2, 0
		move v3, s3
		move v4, s4
		move v5, s5
		move v6, s6
		move v7, s7
		move_mask v3, s7, v4
		move_mask v4, s6, v5
		move_mask v5, s5, v6
		move_mask v6, s4, v7
		move_mask v7, s3, v3
		move v8, 0
		move v9, 0
		move v10, 0

		; Load memory pointers
		getcr s2, 0
		add_i s1, s2, 4 ; (start of data segment)
		shl s1, s1, 16 ; (multiply by 64k)
		move s8, 1
		shl s8, s8, 16
		sub_i s8, s8, 1
loop0: 	add_i_mask v0, s8, v0, 8
		shr s8, s8, 1
		btrue s8, loop0
		add_i v1, v0, s1

		; Compute initial code branch address
		getcr s2, 0
		shl s2, s2, 2
		lea s3, branch_addrs
		add_i s2, s2, s3
		load_32 s2, (s2)
		move pc, s2

branch_addrs: .long start_strand0, start_strand1, start_strand2, start_strand3
'''

		finalizeCode = '''
		nop   ; Because random jumps can be generated above,
		nop   ; We need to pad with 8 NOPs to ensure
		nop   ; The last instruction doesn't jump over our
		nop   ; Cleanup code.
		nop
		nop
		nop
		nop
		setcr s0, 29  ; Store to cr29, which will halt this strand
		nop           ; Flush rest of pipeline
		nop
		nop
		nop
		nop
0:		goto 0b		; loop forever
'''

		# Shared initialization code
		self.file.write(initCode)
		
		for strand in range(4):
			self.file.write('\nstart_strand%d:\n' % strand)
			
			# Generate instructions
			for x in range(numInstructions):
				self.writeWord(self.nextInstruction())

			# Generate code to terminate strand
			self.file.write(finalizeCode)

		# Fill in strand local memory areas with random data
		self.file.write('\t\t; Random data\n')
		self.file.write('\t\t.data\n')
		for x in range(0x10000):
			self.writeWord(randint(0, 0xffffffff))
		
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

parser = argparse.ArgumentParser()
parser.add_argument('-o', nargs=1, default=['random.s'], help='File to write result into', type=str)
parser.add_argument('-m', nargs=1, help='Write multiple test files', type=int)
parser.add_argument('-p', nargs=1, help='profile ID (0-3)', type=int)
parser.add_argument('-n', nargs=1, help='number of instructions to generate per thread', type=int,
	default=[MAX_INSTRUCTIONS])
args = vars(parser.parse_args())

numInstructions = args['n'][0]

if args['m']:
	for x in range(args['m'][0]):
		filename = 'random%04d.s' % x
		print 'generating ' + filename
		profileIndex = randint(0, 3)
		Generator(profiles[profileIndex]).generate(filename, numInstructions)
else:
	if args['p']:
		profileIndex = args['p'][0]
	else:
		profileIndex = randint(0, 3)

	print 'using profile', profileIndex, 'generating', numInstructions, 'instructions'
	Generator(profiles[profileIndex]).generate(args['o'][0], numInstructions)
	

