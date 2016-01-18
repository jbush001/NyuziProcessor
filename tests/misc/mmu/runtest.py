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

DUMP_FILE = 'obj/memdump.bin'
EXPECT_STRING = bytearray('Test String', encoding='ascii')


def test_alias_verilator(name):
    compile_test(['alias.c', 'wrap_tlb_miss_handler.s'])
    result = run_verilator(
        dump_file=DUMP_FILE,
        dump_base=0x100000,
        dump_length=32)
    if result.find('read 00900000 "Test String"') == -1:
        raise TestException(
            'did not get correct read string:\n' + result)

    with open(DUMP_FILE, 'rb') as f:
        if f.read(len(EXPECT_STRING)) != EXPECT_STRING:
            raise TestException('memory contents did not match')


def test_alias_emulator(name):
    compile_test(['alias.c', 'wrap_tlb_miss_handler.s'])
    result = run_emulator(dump_file=DUMP_FILE, dump_base=0x100000,
                          dump_length=32)
    if result.find('read 00900000 "Test String"') == -1:
        raise TestException(
            'did not get correct read string:\n' + result)

    with open(DUMP_FILE, 'rb') as f:
        if f.read(len(EXPECT_STRING)) != EXPECT_STRING:
            raise TestException('memory contents did not match')


def test_fill_verilator(name):
    compile_test(['fill_test.c', 'identity_tlb_miss_handler.s'])
    result = run_verilator()
    if result.find('FAIL') != -1 or result.find('PASS') == -1:
        raise TestException(
            result + '\ntest did not signal pass\n' + result)

    # XXX check number of DTLB misses to ensure it is above/below thresholds


def test_fill_emulator(name):
    compile_test(['fill_test.c', 'identity_tlb_miss_handler.s'])
    result = run_emulator()
    if result.find('FAIL') != -1 or result.find('PASS') == -1:
        raise TestException(
            result + '\ntest did not signal pass\n' + result)


def test_io_map_verilator(name):
    compile_test(['io_map.c'])
    result = run_verilator(
        dump_file=DUMP_FILE,
        dump_base=0x100000,
        dump_length=32)

    # Check value printed via virtual serial port
    if result.find('jabberwocky') == -1:
        raise TestException(
            'did not get correct read string:\n' + result)

    # Check value written to memory
    with open(DUMP_FILE, 'rb') as f:
        if f.read(len('galumphing')) != bytearray('galumphing', 'ascii'):
            raise TestException('memory contents did not match')


def test_io_map_emulator(name):
    compile_test(['io_map.c'])
    result = run_emulator(dump_file=DUMP_FILE, dump_base=0x100000,
                          dump_length=32)

    # Check value printed via virtual serial port
    if result.find('jabberwocky') == -1:
        raise TestException(
            'did not get correct read string:\n' + result)

    # Check value written to memory
    with open(DUMP_FILE, 'rb') as f:
        if f.read(len('galumphing')) != bytearray('galumphing', 'ascii'):
            raise TestException('memory contents did not match')


def test_nested_fault(name):
    compile_test(
        ['nested_fault.c', 'identity_tlb_miss_handler.s'])
    if name.find('_verilator') != -1:
        result = run_verilator()
    else:
        result = run_emulator()

    check_result('nested_fault.c', result)

register_tests(test_alias_verilator, ['alias_verilator'])
register_tests(test_alias_emulator, ['alias_emulator'])
register_tests(test_fill_verilator, ['fill_verilator'])
register_tests(test_fill_emulator, ['fill_emulator'])
register_tests(test_io_map_verilator, ['io_map_verilator'])
register_tests(test_io_map_emulator, ['io_map_emulator'])
register_tests(
    test_nested_fault, ['nested_fault_verilator', 'nested_fault_emulator'])
register_generic_test('dflush_tlb_miss')
register_generic_test('dinvalidate_tlb_miss')
register_generic_test('duplicate_tlb_insert')
register_generic_test('write_fault')
register_generic_test('data_supervisor_fault_read')
register_generic_test('data_supervisor_fault_write')
register_generic_test('instruction_supervisor_fault')
register_generic_test('tlb_invalidate')
register_generic_test('tlb_invalidate_all')
register_generic_test('asid')
register_generic_test('io_supervisor_fault_read')
register_generic_test('io_supervisor_fault_write')
register_generic_test('io_write_fault')
register_generic_test('dtlbinsert_user')
register_generic_test('itlbinsert_user')
register_generic_test('data_not_present_read')
register_generic_test('data_not_present_write')
register_generic_test('instruction_not_present')
execute_tests()
