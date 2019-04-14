#!/usr/bin/env python3
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

import sys

sys.path.insert(0, '../..')
import test_harness


@test_harness.test
def run_io_interrupt(_, target):
    hex_file = test_harness.build_program(['io_interrupt.S'])
    result = test_harness.run_program(hex_file, target)
    lines = result.split('\n')
    output = None

    for line in lines:
        start = line.find('!')
        if start != -1:
            output = line[start + 1:]

    if output is None:
        raise test_harness.TestException(
            'Could not find output string:\n' + result)

    # Make sure enough interrupts were triggered
    if output.count('*') < 2:
        raise test_harness.TestException(
            'Not enough interrupts triggered:\n' + result)

    # Make sure we see at least some of the base string printed after an
    # interrupt
    if output.find('*') >= len(output) - 1:
        raise test_harness.TestException(
            'No instances of interrupt return:\n' + result)

    # Remove all asterisks (interrupts) and make sure string is intact
    stripped = output.replace('*', '')
    if stripped != '0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`' \
            'abcdefghijklmnopqrstuvwxyz' * 10:
        raise test_harness.TestException(
            'Base string does not match:\n' + stripped)



test_harness.register_generic_assembly_tests([
    'setcr_non_super.S',
    'getcr_non_super.S',
    'eret_non_super.S',
    'dinvalidate_non_super.S',
    'syscall.S',
    'breakpoint.S',
    'unaligned_inst_fault.S',
    'unaligned_data_fault.S',
    'multicycle.S',
    'illegal_instruction.S',
    'int_config.S'
], ['emulator', 'verilator', 'fpga'])

test_harness.execute_tests()
