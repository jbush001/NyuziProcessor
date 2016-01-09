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
import os

#
# Test reading blocks from SDMMC device
#

sys.path.insert(0, '../..')
from test_harness import *

FILE_SIZE = 8192
SOURCE_BLOCK_DEV = 'bdevimage.bin'
MEMDUMP = 'memory.bin'

def test_read(name):
    # Create random file
    with open(SOURCE_BLOCK_DEV, 'wb') as f:
        f.write(os.urandom(FILE_SIZE))

    compile_test('sdmmc_read.c')
    if name.endswith('_emulator'):
        run_emulator(
            block_device=SOURCE_BLOCK_DEV,
            dump_file=MEMDUMP,
            dump_base=0x200000,
            dump_length=FILE_SIZE)
    else:
        run_verilator(
            block_device=SOURCE_BLOCK_DEV,
            dump_file=MEMDUMP,
            dump_base=0x200000,
            dump_length=FILE_SIZE,
            extra_args=['+autoflushl2=1'])

    assert_files_equal(
        SOURCE_BLOCK_DEV, MEMDUMP, 'file mismatch')

register_tests(test_read, ['sdmmc_read_emulator', 'sdmmc_read_verilator'])
execute_tests()
