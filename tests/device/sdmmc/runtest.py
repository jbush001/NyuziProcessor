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

"""Test reading blocks from SDMMC device"""

import os
import sys

sys.path.insert(0, '../..')
import test_harness

FILE_SIZE = 8192
SOURCE_BLOCK_DEV = test_harness.WORK_DIR + '/bdevimage.bin'
MEMDUMP = test_harness.WORK_DIR + '/memory.bin'


@test_harness.test
def sdmmc_read(_, target):
    # Create random file
    with open(SOURCE_BLOCK_DEV, 'wb') as fsimage:
        fsimage.write(os.urandom(FILE_SIZE))

    test_harness.build_program(['sdmmc_read.c'])
    test_harness.run_program(
        target=target,
        block_device=SOURCE_BLOCK_DEV,
        dump_file=MEMDUMP,
        dump_base=0x200000,
        dump_length=FILE_SIZE,
        flush_l2=True)

    test_harness.assert_files_equal(SOURCE_BLOCK_DEV, MEMDUMP, 'file mismatch')

@test_harness.test
def sdmmc_write(_, target):
    with open(SOURCE_BLOCK_DEV, 'wb') as fsimage:
        fsimage.write(b'\xcc' * 1536)

    test_harness.build_program(['sdmmc_write.c'])
    result = test_harness.run_program(
        target=target,
        block_device=SOURCE_BLOCK_DEV)
    if 'FAIL' in result:
        raise test_harness.TestException('Test failed ' + result)

    with open(SOURCE_BLOCK_DEV, 'rb') as fsimage:
        end_contents = fsimage.read()

    # Check contents. First block is not modified
    for index in range(512):
        if end_contents[index] != 0xcc:
            raise test_harness.TestException('mismatch at {} expected 0xcc got 0x{:02x}'
                .format(index, end_contents[index]))

    # Second block has a pattern in it
    for index in range(512):
        expected = (index ^ (index >> 3)) & 0xff
        if end_contents[index + 512] != expected:
            raise test_harness.TestException('mismatch at {} expected 0x{:02x} got 0x{:02x}'
                .format(index + 512, expected, end_contents[index + 512]))

    # Third block is not modified
    for index in range(512):
        if end_contents[index + 1024] != 0xcc:
            raise test_harness.TestException('mismatch at {} expected 0xcc got 0x{:02x}'
                .format(index + 1024, end_contents[index + 1024]))

test_harness.execute_tests()
