#!/usr/bin/env python
#
# Copyright 2011-2015 Jeff Bush
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

"""
 Generate a pseudorandom instruction stream.

 v0, s0 - Base registers for shared data segment (read only)
 v1, s1 - Computed address registers.  Guaranteed to be 64 byte aligned and
          in private memory segment.
 v2, s2 - Base registers for private data segment (read/write, per thread)
 v3-v8, s3-s8 - Operation registers
 s9 - pointer to register mapped IO space (0xffff0000)

 Memory map:
  000000 start of code (thread0, 1, 2, 3...), shared data segment (read only)
  800000 start of private data (read/write), thread 0
  900000 start of private data (read/write), thread 1
  a00000 start of private data (read/write), thread 2
  b00000 start of private data (read/write), thread 3
"""


import argparse
import random
import sys


def generate_arith_reg():
    """Return a random register number for an arithmetic operation"""

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
    #    'add_f',
    #    'sub_f',
    #   'mul_f'
]


def generate_binary_arith(outfile):
    """Write a single binary arithmetic instruction to a file"""

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
    opstr = '\t\t{}{} {}{}, '.format(mnemonic, suffix, typed, dest)
    if suffix != '':
        opstr += 's{}, '.format(maskreg)  # Add mask register

    opstr += '{}{}, '.format(typea, rega)
    if typeb == 'i':
        opstr += str(random.randint(-0x7f, 0x7f))  # Immediate value
    else:
        opstr += '{}{}'.format(typeb, regb)

    outfile.write(opstr + '\n')

UNARY_OPS = [
    'clz',
    'ctz',
    'move'
]


def generate_unary_arith(outfile):
    """Write a single unary arithmetic instruction to a file"""

    mnemonic = random.choice(UNARY_OPS)
    dest = generate_arith_reg()
    rega = generate_arith_reg()
    fmt = random.randint(0, 3)
    if fmt == 0:
        maskreg = generate_arith_reg()
        outfile.write('\t\t{}_mask  v{}, s{}, v{}\n'.format
                      (mnemonic, dest, maskreg, rega))
    elif fmt == 1:
        outfile.write('\t\t{} v{}, v{}\n'.format(mnemonic, dest, rega))
    else:
        outfile.write('\t\t{} s{}, s{}\n'.format(mnemonic, dest, rega))

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
    #    'gt_f',
    #    'ge_f',
    #    'lt_f',
    #    'le_f'
]


def generate_compare(outfile):
    """Write a single comparison instruction to a file"""

    typea, typeb = random.choice(COMPARE_FORMS)
    dest = generate_arith_reg()
    rega = generate_arith_reg()
    regb = generate_arith_reg()
    opsuffix = random.choice(COMPARE_OPS)
    opstr = '\t\tcmp{} s{}, {}{}, '.format(opsuffix, dest, typea, rega)
    if random.randint(0, 1) == 0 and not opsuffix.endswith('_f'):
        opstr += str(random.randint(-0x1ff, 0x1ff))  # Immediate value
    else:
        opstr += '{}{}'.format(typeb, regb)

    outfile.write(opstr + '\n')

LOAD_OPS = [
    ('_32', 4),
    ('_s16', 2),
    ('_u16', 2),
    ('_s8', 1),
    ('_u8', 1)
]

STORE_OPS = [
    ('_32', 4),
    ('_16', 2),
    ('_8', 1)
]


def generate_memory_access(outfile):
    """ Write a random single memory load or store instruction to the file"""

    # v0/s0 represent the shared segment, which is read only
    # v1/s1 represent the private segment, which is read/write
    ptr_reg = random.randint(0, 1)

    opstr = 'load' if ptr_reg == 0 or random.randint(0, 1) else 'store'

    op_type = random.randint(0, 2)
    if op_type == 0:
        # Block vector
        offset = random.randint(0, 16) * 64
        opstr += '_v v{}, {}(s{})'.format(generate_arith_reg(),
                                          offset, ptr_reg)
    elif op_type == 1:
        # Scatter/gather
        offset = random.randint(0, 16) * 4
        if opstr == 'load':
            opstr += '_gath'
        else:
            opstr += '_scat'

        mask_type = random.randint(0, 1)
        if mask_type == 1:
            opstr += '_mask'

        opstr += ' v{}'.format(generate_arith_reg())
        if mask_type:
            opstr += ', s{}'.format(generate_arith_reg())

        opstr += ', {}(v{})'.format(offset, ptr_reg)
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
        opstr += '{} s{}, {}(s{})'.format(suffix, generate_arith_reg(),
                                          offset, ptr_reg)

    outfile.write('\t\t' + opstr + '\n')


def generate_device_io(outfile):
    """
    Write a random single memory load or store instruction that accesses
    device space (0xffff0000-0xffffffff) to the file.
    """

    if random.randint(0, 1):
        outfile.write('\t\tload_32 s{}, {}(s9)\n'.format(
            generate_arith_reg(), random.randint(0, 1) * 4))
    else:
        outfile.write('\t\tstore_32 s{}, (s9)\n'.format(generate_arith_reg()))

BRANCH_TYPES = [
    ('bfalse', True),
    ('btrue', True),
    ('ball', True),
    ('bnall', True),
    ('call', False),
    ('goto', False)
]


def generate_branch(outfile):
    """
    Write a single branch instruction to outfile. This will use a relative
    forward branch to an anonymous label 1-6 instructions away.
    """

    branch_type, is_cond = random.choice(BRANCH_TYPES)
    if is_cond:
        outfile.write('\t\t{} s{}, {}f\n'.format(
            branch_type, generate_arith_reg(), random.randint(1, 6)))
    else:
        outfile.write('\t\t{} {}f\n'.format(branch_type, random.randint(1, 6)))


def generate_computed_pointer(outfile):
    """
    Generate an arithmetic instruction that writes to one of the special
    'computed pointer' registers. These are guaranteed to be valid memory
    locations
    """

    if random.randint(0, 1) == 0:
        outfile.write('\t\tadd_i s1, s2, {}\n'.format(
            random.randint(0, 16) * 64))
    else:
        outfile.write('\t\tadd_i v1, v2, {}\n'.format(
            random.randint(0, 16) * 64))

CACHE_CONTROL_INSTRS = [
    'dflush s1',
    'iinvalidate s1',
    'membar'
]


def generate_cache_control(outfile):
    """Generate a single cache control instruction"""

    outfile.write('\t\t{}\n'.format(random.choice(CACHE_CONTROL_INSTRS)))

GENERATE_FUNCS = [
    (0.1, generate_computed_pointer),
    (0.5, generate_binary_arith),
    (0.05, generate_unary_arith),
    (0.1, generate_compare),
    (0.2, generate_memory_access),
    (0.01, generate_device_io),
    (0.03, generate_cache_control),
    (1.0, generate_branch),
]


def generate_test(filename):
    """Write a complete assembly file with a pseudorandom instruction stream"""

    with open(filename, 'w') as outfile:
        outfile.write('# This file auto-generated by ' + sys.argv[0] + '''

                .include "../asm_macros.inc"

                .globl _start
_start:         start_all_threads

                ##### Set up pointers #####################
                getcr s2, CR_CURRENT_THREAD
                add_i s2, s2, 8    # Start at 8 MB
                shl s2, s2, 20    # Multiply by 1meg: private base address

                load_v v2, ptrvec
                add_i v2, v2, s2    # Set up vector private base register (for scatter/gather)

                # Copy base addresses into computed addresses
                move v1, v2
                move s1, s2

                # Zero out shared base registers
                move v0, 0
                move s0, 0

                load_32 s9, device_ptr

                ######### Fill private memory with a random pattern ######
                move s3, s2    # Base Address
                load_32 s4, fill_length    # Size to copy
                getcr s5, CR_CURRENT_THREAD    # Use thread ID as seed
                load_32 s6, generator_a
                load_32 s7, generator_c

fill_loop:      store_32 s5, (s3)

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

        if enable_interrupts:
            outfile.write('''
                ###### Set up interrupt handler ###################################
                lea s10, interrupt_handler
                setcr s10, CR_TRAP_HANDLER
                move s10, (FLAG_INTERRUPT_EN | FLAG_SUPERVISOR_EN)
                setcr s10, CR_FLAGS   # Enable interrupts
                move s10, 1
                setcr s10, CR_INTERRUPT_MASK

''')

        outfile.write('''
                ###### Compute address of per-thread code and branch ######
                getcr s3, CR_CURRENT_THREAD
                shl s3, s3, 2
                lea s4, branch_addrs
                add_i s3, s3, s4
                load_32 s3, (s3)
                move pc, s3

interrupt_handler:
                getcr s11, CR_TRAP_PC
                getcr s12, CR_TRAP_REASON
                setcr s0, CR_SCRATCHPAD0
                setcr s1, CR_SCRATCHPAD1

                # Ack interrupt
                move s1, 1
                setcr s1, CR_INTERRUPT_ACK

                getcr s0, CR_SCRATCHPAD0
                getcr s1, CR_SCRATCHPAD1
                eret

                .align 64
ptrvec:         .long 0, 4, 8, 12, 16, 20, 24, 28, 32, 36, 40, 44, 48, 52, 56, 60
branch_addrs:   .long ''')

        for i in range(num_threads):
            if i:
                outfile.write(', ')

            outfile.write('start_thread{}'.format(i))

        outfile.write('''
fill_length:    .long 0x1000 / 4
generator_a:    .long 1103515245
generator_c:    .long 12345
device_ptr:     .long 0xffff0004
''')

        for thread in range(num_threads):
            outfile.write('\nstart_thread{}:\n'.format(thread))
            label_idx = 1
            for i in range(num_instructions):
                outfile.write('{}:'.format(label_idx + 1))
                label_idx = (label_idx + 1) % 6
                inst_type = random.random()
                cumul_prob = 0.0
                for prob, func in GENERATE_FUNCS:
                    cumul_prob += prob
                    if inst_type < cumul_prob:
                        func(outfile)
                        break

            outfile.write('''
        1: nop
        2: nop
        3: nop
        4: nop
        5: nop
        6: nop
        nop
        nop
        halt_current_thread
        ''')

parser = argparse.ArgumentParser()
parser.add_argument('-o', help='File to write result into',
                    type=str, default='random.s')
parser.add_argument('-m', help='Write multiple test files', type=int)
parser.add_argument(
    '-n',
    help='number of instructions to generate per thread',
    type=int,
    default=60000)
parser.add_argument('-i', help='Enable interrupts', action='store_true')
parser.add_argument('-t', help='Number of threads', type=int, default=4)
args = vars(parser.parse_args())
num_instructions = args['n']
enable_interrupts = args['i']
num_threads = args['t']

if (num_instructions + 120) * num_threads * 4 > 0x800000:
    print('Instruction space exceeds available memory.')

if args['m']:
    for fileno in range(args['m']):
        output_file = 'random{:04d}.s'.format(fileno)
        print('generating ' + output_file)
        generate_test(output_file)
else:
    print('generating ' + args['o'])
    generate_test(args['o'])
