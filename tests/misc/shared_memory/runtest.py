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

import mmap
import subprocess
import sys
import tempfile
import time
import struct

sys.path.insert(0, '../..')
from test_harness import *


def sharedmem_transact(memory, value):
    memory[0x100004:0x100008] = struct.pack('<I', value)
    memory[0x100000:0x100004] = '\x01\x00\x00\x00'
    starttime = time.time()
    while memory[0x100000:0x100004] != '\x00\x00\x00\x00':
        if (time.time() - starttime) > 10:
            raise TestException(
                'timed out waiting for response from coprocessor')

        time.sleep(0.1)

    return struct.unpack('<I', memory[0x100004:0x100008])[0]

#
# This test is explained in coprocessor.c
#


def sharedmem_test(name):
    MEM_FILE = '/tmp/nyuzi_shared_mem'

    compile_test('coprocessor.c')

    # Start the emulator
    args = [BIN_DIR + 'emulator', '-s', MEM_FILE, HEX_FILE]
    process = subprocess.Popen(args, stdout=subprocess.PIPE,
                               stderr=subprocess.STDOUT)

    try:
        # Hack: Need to wait for a sequence of things
        # to happen:
        #  - Emulator creates shared memory file, resizes it, and fills
        #    it with random data.
        #  - Test program starts and reads ready flag.
        # There's currently no way for the emulator to signal that this
        # has completed, so just sleep long enough that it should have
        # happened.
        time.sleep(1.0)

        with open(MEM_FILE, 'ab+') as f:
            memory = mmap.mmap(f.fileno(), 0)

            testvalues = [
                0xec59692d,
                0x1ae06e9b,
                0xe7a0dd99,
                0xfcc8baad,
                0x6ade3a42,
                0x6a8bbb5e,
                0x9df29708,
                0x4f308269,
                0x537191dd,
                0xa65d5314
            ]

            for value in testvalues:
                computed = sharedmem_transact(memory, value)
                if computed != (value ^ 0xffffffff):
                    raise TestException('Incorrect value from coprocessor expected ' + hex(value ^ 0xffffffff)
                                        + ' got ' + hex(computed))
    finally:
        process.kill()

register_tests(sharedmem_test, ['shared_memory'])
execute_tests()
