#!/usr/bin/env python3
#
# Copyright 2017 Jeff Bush
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
Test virtual address translation by running a program that writes patterns
to memory, then reading back the values to see if they match what is expected.
More details are in random_access.S
"""

import struct
import sys

sys.path.insert(0, '../..')
import test_harness

NUM_THREADS = 4
PAGE_SIZE = 0x1000
MEMORY_SIZE = 0x20000   # Size of mapped region per thread
DUMP_BASE = 0x10000     # Physical address, is 4k in virtual address space


@test_harness.test(['verilator'])
def random_access_mmu_stress(_, target):
    test_harness.build_program(['random_access.S'])
    test_harness.run_program(
        target=target,
        dump_file='obj/vmem.bin',
        dump_base=DUMP_BASE,
        dump_length=MEMORY_SIZE * NUM_THREADS,
        timeout=240,
        flush_l2=True)

    # Check that threads have written proper values
    with open('obj/vmem.bin', 'rb') as memfile:
        for page_num in range(int(MEMORY_SIZE / PAGE_SIZE)):
            for thread_id in range(NUM_THREADS):
                for page_offset in range(0, PAGE_SIZE, 4):
                    val = memfile.read(4)
                    if len(val) < 4:
                        raise test_harness.TestException(
                            'output file is truncated')

                    num_val, = struct.unpack('<L', val)
                    va = page_num * PAGE_SIZE + \
                        page_offset + int(DUMP_BASE / 4)
                    expected = (thread_id << 24) | va
                    if num_val != expected:
                        raise test_harness.TestException(
                            'FAIL: mismatch @{:x} : got {:x} expected {:x}'.format((page_num * 4 + thread_id) * PAGE_SIZE,
                                                                                   num_val, expected))

test_harness.execute_tests()
