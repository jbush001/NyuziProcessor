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

import sys
import subprocess

sys.path.insert(0, '../..')
from test_harness import *


def run_io_interrupt(name):
    compile_test(['io_interrupt.c', 'trap_handler.s'])
    result = run_verilator()
    lines = result.split('\n')
    output = None
    for x in lines:
        if x.startswith('>>'):
            output = x[2:]

    if output is None:
        raise TestException(
            'Could not find output string:\n' + result)

    # Make sure enough interrupts were triggered
    if output.count('*') < 2:
        raise TestException(
            'Not enough interrupts triggered:\n' + result)

    # Make sure we see at least some of the base string printed after an
    # interrupt
    if output.find('*') >= len(output) - 1:
        raise TestException(
            'No instances of interrupt return:\n' + result)

    # Remove all asterisks (interrupts) and make sure string is intact
    if output.replace(
            '*',
            '') != 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789':
        raise TestException(
            'Base string does not match:\n' + result)


def run_multicycle(name):
    assemble_test('multicycle.s')
    result = run_verilator()
    if result.find('PASS') == -1 or result.find('FAIL') != -1:
        raise TestException('Test failed:\n' + result)


def run_unaligned_data_fault(name):
    compile_test(['unaligned_data_fault.c', 'trap_handler.s'])
    if name.endswith('_emulator'):
        result = run_emulator()
    else:
        result = run_verilator()

    check_result('unaligned_data_fault.c', result)


def run_illegal_instruction(name):
    compile_test(
        ['illegal_instruction.c', 'trap_handler.s', 'gen_illegal_inst_trap.S'])
    if name.endswith('_emulator'):
        result = run_emulator()
    else:
        result = run_verilator()

    check_result('gen_illegal_inst_trap.S', result)

register_tests(run_io_interrupt, ['io_interrupt'])
register_tests(run_multicycle, ['multicycle'])
register_generic_test('creg_non_supervisor')
register_generic_test('eret_non_supervisor')
register_generic_test('inst_align_fault')
register_tests(
    run_unaligned_data_fault, [
        'unaligned_data_fault_emulator', 'unaligned_data_fault_verilator'])
register_tests(
    run_illegal_instruction, [
        'illegal_instruction_emulator', 'illegal_instruction_verilator'])
register_generic_test('syscall')

execute_tests()
