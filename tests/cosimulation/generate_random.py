#!/usr/bin/env python
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
# Generate a pseudorandom instruction stream.
#
# v0, s0 - Base registers for shared data segment (read only)
# v1, s1 - Computed address registers.  Guaranteed to be 64 byte aligned and in private memory segment.
# v2, s2 - Base registers for private data segment (read/write, per thread)
# v3-v8, s3-s8 - Operation registers
# s9 - pointer to register mapped IO space (0xffff0000)
#
# Memory map:
#  000000 start of code (strand0, 1, 2, 3), shared data segment (read only)
#  100000 start of private data (read/write), strand 0
#  200000 start of private data (read/write), strand 1
#  300000 start of private data (read/write), strand 2
#  400000 start of private data (read/write), strand 3
#

import random
import sys
import argparse

def generate_arith_reg():
	return random.randint(3, 8)

FP_FORMS = [
	('s', 's', 's', ''),
	('v', 'v', 's', ''),
	('v', 'v', 's', '_mask'),
	('v', 'v', 'v', ''),
	('v', 'v', 'v', '_mask'),
]

INT_FORMS = [
	('s', 's', 's', ''),
	('v', 'v', 's', ''),
	('v', 'v', 's', '_mask'),
	('v', 'v', 'v', ''),
	('v', 'v', 'v', '_mask'),
	('s', 's', 'i', ''),
	('v', 'v', 'i', ''),
	('v', 'v', 'i', '_mask'),
	('v', 's', 'i', ''),
	('v', 's', 'i', '_mask'),
]

BINARY_OPS = [
	'or',
	'and',
	'xor',
	'add_i',
	'sub_i',
	'ashr',
	'shr',
	'shl',
	'mull_i',
	'mulh_i',
	'mulh_u',
	'shuffle',
	'getlane'
	
# Disable for now because there are still some rounding bugs that cause
# mismatches
#	'add_f',
#	'sub_f',
#   'mul_f'
]

def generate_binary_arith(file):
	mnemonic = random.choice(BINARY_OPS)
	if mnemonic == 'shuffle':
		typed = 'v'
		typea = 'v'
		typeb = 'v'
		suffix = '' if random.randint(0, 1) == 0 else '_mask'
	elif mnemonic == 'getlane':
		typed = 's'
		typea = 'v'
		typeb = 's' if random.randint(0, 1) == 0 else 'i'
		suffix = ''
	elif mnemonic.endswith('_f'):
		typed, typea, typeb, suffix = random.choice(FP_FORMS)
	else:
		typed, typea, typeb, suffix = random.choice(INT_FORMS)

	dest = generate_arith_reg()
	rega = generate_arith_reg()
	regb = generate_arith_reg()
	maskreg = generate_arith_reg()
	opstr = '\t\t%s%s %c%d, ' % (mnemonic, suffix, typed, dest)
	if suffix != '':
		opstr += 's%d, ' % maskreg # Add mask register

	opstr += typea + str(rega) + ', '
	if typeb == 'i':
		opstr += str(random.randint(-0x1ff, 0x1ff))	# Immediate value
	else:
	 	opstr += typeb + str(regb)

	file.write(opstr + '\n')

UNARY_OPS = [
	'clz',
	'ctz',
	'move'
]

def generate_unary_arith(file):
	mnemonic = random.choice(UNARY_OPS)
	dest = generate_arith_reg()
	rega = generate_arith_reg()
	fmt = random.randint(0, 3)
	if fmt == 0:
		maskreg = generate_arith_reg()
		file.write('\t\t%s_mask  v%d, s%d, v%d\n' % (mnemonic, dest, maskreg, rega))
	elif fmt == 1:
		file.write('\t\t%s v%d, v%d\n' % (mnemonic, dest, rega))
	else: 
		file.write('\t\t%s s%d, s%d\n' % (mnemonic, dest, rega))

COMPARE_FORMS = [
	('v', 'v'),
	('v', 's'),
	('s', 's')
]

COMPARE_OPS = [
	'eq_i',
	'ne_i',
	'gt_i',
	'ge_i',
	'lt_i',
	'le_i',
	'gt_u',
	'ge_u',
	'lt_u',
	'le_u',
# Floating point comparisons don't handle specials correctly in all situations
#	'gt_f',
#	'ge_f',
#	'lt_f',
#	'le_f'
]


def generate_compare(file):
	typea, typeb = random.choice(COMPARE_FORMS)
	dest = generate_arith_reg()
	rega = generate_arith_reg()
	regb = generate_arith_reg()
	opsuffix = random.choice(COMPARE_OPS)
	opstr = '\t\tcmp%s s%d, %c%d, ' % (opsuffix, dest, typea, rega)
	if random.randint(0, 1) == 0 and not opsuffix.endswith('_f'):
		opstr += str(random.randint(-0x1ff, 0x1ff))	# Immediate value
	else:
	 	opstr += typeb + str(regb)
		
	file.write(opstr + '\n')

LOAD_OPS = [
	('_sync', 4),
	('_32', 4),
	('_s16', 2),
	('_u16', 2),
	('_s8', 1),
	('_u8', 1)
]

STORE_OPS = [
	('_sync', 4),
	('_32', 4),
	('_16', 2),
	('_8', 1)
]

def generate_memory_access(file):
	# v0/s0 represent the shared segment, which is read only
	# v1/s1 represent the private segment, which is read/write
	ptrReg = random.randint(0, 1)

	opstr = 'load' if ptrReg == 0 or random.randint(0, 1) else 'store'

	opType = random.randint(0, 2)
	if opType == 0:
		# Block vector
		offset = random.randint(0, 16) * 64
		opstr += '_v v%d, %d(s%d)' % (generate_arith_reg(), offset, ptrReg)
	elif opType == 1:
		# Scatter/gather
		offset = random.randint(0, 16) * 4
		if opstr == 'load':
			opstr += '_gath'
		else:
			opstr += '_scat'

		maskType = random.randint(0, 1)
		if maskType == 1:
			opstr += '_mask'

		opstr += ' v%d' % generate_arith_reg()
		if maskType != 0:
			opstr += ', s%d' % generate_arith_reg()
	
		opstr += ', %d(v%d)' % (offset, ptrReg)
	else:
		# Scalar
		if opstr == 'load':
			suffix, align = random.choice(LOAD_OPS)
		else:
			suffix, align = random.choice(STORE_OPS)

		# Because we don't model the store queue in the emulator,
		# a store can invalidate a synchronized load that is issued subsequently.
		# A membar guarantees order.
		if opstr == 'load' and suffix == '_sync':
			opstr = 'membar\n\t\t' + opstr

		offset = random.randint(0, 16) * align
		opstr += '%s s%d, %d(s%d)' % (suffix, generate_arith_reg(), offset, ptrReg)

	file.write('\t\t' + opstr + '\n')

def generate_device_io(file):
	if random.randint(0, 1):
		file.write('\t\tload_32 s%d, %d(s9)\n' % (generate_arith_reg(), random.randint(0, 1) * 4))
	else:
		file.write('\t\tstore_32 s%d, (s9)\n' % generate_arith_reg())

BRANCH_TYPES = [
	('bfalse', True),
	('btrue', True),
	('ball', True),
	('bnall', True),
	('call', False),
	('goto', False)
]

def generate_branch(file):
	# Branch
	branchType, isCond = random.choice(BRANCH_TYPES)
	if isCond:
		file.write('\t\t%s s%d, %df\n' % (branchType, generate_arith_reg(), random.randint(1, 6)))
	else:
		file.write('\t\t%s %df\n' % (branchType, random.randint(1, 6)))

def generate_computed_pointer(file):
	if random.randint(0, 1) == 0:
		file.write('\t\tadd_i s1, s2, %d\n' % (random.randint(0, 16) * 64))
	else:
		file.write('\t\tadd_i v1, v2, %d\n' % (random.randint(0, 16) * 64))

CACHE_CONTROL_INSTRS = [
	'dflush s1',
	'iinvalidate s1',
	'membar'
]

def generate_cache_control(file):
	file.write('\t\t%s\n' % random.choice(CACHE_CONTROL_INSTRS))

generate_funcs = [
	(0.1,  generate_computed_pointer),
	(0.5,  generate_binary_arith),
	(0.05, generate_unary_arith),
	(0.1,  generate_compare),
	(0.2,  generate_memory_access),
	(0.01, generate_device_io),
	(0.03, generate_cache_control),
	(1.0, generate_branch),
]

def generate_test(filename, numInstructions, enableInterrupts):
	file = open(filename, 'w')
	file.write('# This file auto-generated by ' + sys.argv[0] + '''

				.globl _start
_start:			move s1, 15
				setcr s1, 30	# start all threads
			
				##### Set up pointers #####################
				getcr s2, 0
				add_i s2, s2, 1
				shl s2, s2, 20	# Multiply by 1meg: private base address
				
				load_v v2, ptrvec
				add_i v2, v2, s2	# Set up vector private base register (for scatter/gather)

				# Copy base addresses into computed addresses
				move v1, v2
				move s1, s2
				
				# Zero out shared base registers
				move v0, 0
				move s0, 0
				
				load_32 s9, device_ptr

				######### Fill private memory with a random pattern ######
				move s3, s2	# Base Address
				load_32 s4, fill_length	# Size to copy
				getcr s5, 0	# Use thread ID as seed
                load_32 s6, generator_a
                load_32 s7, generator_c

fill_loop:		store_32 s5, (s3)
				
				# Compute next random number
                mull_i s5, s5, s6
                add_i s5, s5, s7
				
				# Increment and loop
                add_i s3, s3, 4      # Increment pointer
                sub_i s4, s4, 1      # Decrement count
                btrue s4, fill_loop

				####### Initialize registers with non-zero contents #######
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
				move s8, 112
				move v8, 73
''')
			
	if enableInterrupts:
		file.write('''
				###### Set up interrupt handler ###################################
				lea s10, interrupt_handler
			    setcr s10, 1			# Set interrupt handler address
				move s10, 1
				setcr s10, 4			# Enable interrupts
''')


	file.write('''
				###### Compute address of per-thread code and branch ######
				getcr s3, 0
				shl s3, s3, 2
				lea s4, branch_addrs
				add_i s3, s3, s4
				load_32 s3, (s3)
				move pc, s3

				# Interrupt handler
interrupt_handler: 	getcr s11, 2		# PC
					getcr s12, 3		# Reason
					eret

				.align 64
ptrvec: 		.long 0, 4, 8, 12, 16, 20, 24, 28, 32, 36, 40, 44, 48, 52, 56, 60
branch_addrs: 	.long start_strand0, start_strand1, start_strand2, start_strand3
fill_length: 	.long 0x1000 / 4
generator_a: 	.long 1103515245
generator_c: 	.long 12345
device_ptr:		.long 0xffff0004
''')

	for strand in range(4):
		file.write('start_strand%d: ' % strand)
		labelIdx = 1
		for x in range(numInstructions):
			file.write(str(labelIdx + 1) + ': ')
			labelIdx = (labelIdx + 1) % 6
			instType = random.random()
			cumulProb = 0.0
			for prob, func in generate_funcs:
				cumulProb += prob
				if instType < cumulProb:
					func(file)
					break
			
		file.write('''
		1: nop
		2: nop
		3: nop
		4: nop
		5: nop
		6: nop
		nop
		nop
	
		''')
		
		file.write('setcr s0, 29')
		for x in range(8):
			file.write('\t\tnop\n')

		file.write('1:\tgoto 1b\n')

	file.close()

parser = argparse.ArgumentParser()
parser.add_argument('-o', nargs=1, default=['random.s'], help='File to write result into', type=str)
parser.add_argument('-m', nargs=1, help='Write multiple test files', type=int)
parser.add_argument('-n', nargs=1, help='number of instructions to generate per thread', type=int,
	default=[60000])
parser.add_argument('-i', help='Enable interrupts', action='store_true')
args = vars(parser.parse_args())
numInstructions = args['n'][0]
enableInterrupts = args['i']

if args['m']:
	for x in range(args['m'][0]):
		filename = 'random%04d.s' % x
		print 'generating ' + filename
		generate_test(filename, numInstructions, enableInterrupts)
else:
	generate_test(args['o'][0], numInstructions, enableInterrupts)



