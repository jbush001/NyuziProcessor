#!/usr/bin/env python
#
# Copyright 2016 Jeff Bush
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
import random

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
    compile_test('coprocessor.c')

    # Start the emulator
    memoryFile = tempfile.NamedTemporaryFile()
    args = [BIN_DIR + 'emulator', '-s', memoryFile.name, HEX_FILE]
    process = subprocess.Popen(args, stdout=subprocess.PIPE,
                               stderr=subprocess.STDOUT)

    try:
        # Hack: Need to wait for the emulator to create the shared memory
        # file and initialize it. There's currently no way for the emulator
        # to signal that this has completed, so just sleep a bit and hope
        # it's done.
        time.sleep(1.0)
        memory = mmap.mmap(memoryFile.fileno(), 0)
        testvalues = [ random.randint(0, 0xffffffff) for x in range(10) ]
        for value in testvalues:
            computed = sharedmem_transact(memory, value)
            if computed != (value ^ 0xffffffff):
                raise TestException('Incorrect value from coprocessor expected ' + hex(value ^ 0xffffffff)
                                    + ' got ' + hex(computed))
    finally:
        process.kill()

register_tests(sharedmem_test, ['shared_memory'])
execute_tests()
