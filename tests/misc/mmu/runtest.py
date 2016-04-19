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

def run_mmu_test(name):
    if name.endswith('_emulator'):
        basename = name[0:-len('_emulator')]
        isverilator = False
    elif name.endswith('_verilator'):
        basename = name[0:-len('_verilator')]
        isverilator = True

    assemble_test(basename + '.S')
    if isverilator:
        result = run_verilator()
    else:
        result = run_emulator()

    if result.find('PASS') == -1 or result.find('FAIL') != -1:
        raise TestException('Test failed ' + result)

def register_mmu_tests(list):
    for name in list:
        register_tests(run_mmu_test, [name + '_verilator'])
        register_tests(run_mmu_test, [name + '_emulator'])

# XXX dump memory contents and ensure they are written out properly

register_mmu_tests([
    'data_page_fault_read',
    'data_page_fault_write',
    'data_supervisor_fault_read',
    'data_supervisor_fault_write',
    'dflush_tlb_miss',
    'dinvalidate_tlb_miss',
    'dtlb_insert_user',
    'asid',
    'execute_fault',
    'instruction_page_fault',
    'instruction_super_fault',
    'write_fault',
    'tlb_invalidate',
    'tlb_invalidate_all',
    'synonym',
    'duplicate_tlb_insert',
    'itlb_insert_user',
    'io_supervisor_fault_read',
    'io_supervisor_fault_write',
    'io_write_fault',
    'io_map',
    'nested_fault'
]);

execute_tests()
