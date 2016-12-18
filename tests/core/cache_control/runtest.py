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
This test writes a pattern to memory and manually flushes it from code. It then
checks the contents of system memory to ensure the data was flushed correctly.
"""

import struct
import sys

sys.path.insert(0, '../..')
import test_harness

BASE_ADDRESS = 0x400000


@test_harness.test
def dflush(_):
    test_harness.build_program(['dflush.S'])
    test_harness.run_program(
        environment='verilator',
        dump_file='obj/vmem.bin',
        dump_base=BASE_ADDRESS,
        dump_length=0x40000)
    with open('obj/vmem.bin', 'rb') as memfile:
        for index in range(4096):
            val = memfile.read(4)
            if len(val) < 4:
                raise test_harness.TestException('output file is truncated')

            num_val, = struct.unpack('<L', val)
            expected = 0x1f0e6231 + (index // 16)
            if num_val != expected:
                raise test_harness.TestException('FAIL: mismatch at ' + hex(
                    BASE_ADDRESS + (index * 4)) + ' want ' + str(expected) + ' got ' + str(num_val))


@test_harness.test
def dinvalidate(_):
    test_harness.build_program(['dinvalidate.S'])
    result = test_harness.run_program(
        environment='verilator',
        dump_file='obj/vmem.bin',
        dump_base=0x2000,
        dump_length=4,
        flush_l2=True,
        trace=True)

    # 1. Check that the proper value was read into s2
    if '02 deadbeef' not in result:
        raise test_harness.TestException(
            'incorrect value was written back ' + result)

    # 2. Read the memory dump to ensure the proper value is flushed from the
    # L2 cache
    with open('obj/vmem.bin', 'rb') as memfile:
        num_val, = struct.unpack('<L', memfile.read(4))
        if num_val != 0xdeadbeef:
            raise test_harness.TestException(
                'memory contents were incorrect: ' + hex(num_val))


@test_harness.test
def dflush_wait(_):
    test_harness.build_program(['dflush_wait.S'])
    output = test_harness.run_program(environment='verilator')
    if 'PASS' not in output:
        raise test_harness.TestException('Test did not signal pass: ' + output)


@test_harness.test
def iinvalidate(_):
    test_harness.build_program(['iinvalidate.S'])
    output = test_harness.run_program(environment='verilator')
    if 'PASS' not in output:
        raise test_harness.TestException('Test did not signal pass: ' + output)


test_harness.execute_tests()
