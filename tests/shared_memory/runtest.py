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
import random
import struct
import subprocess
import sys
import tempfile
import time

sys.path.insert(0, '..')
import test_harness


def write_shared_memory(memory, address, value):
    memory[address:address + 4] = struct.pack('<I', value)


def read_shared_memory(memory, address):
    return struct.unpack('<I', memory[address:address + 4])[0]

OWNER_ADDR = 0x100000
VALUE_ADDR = 0x100004
OWNER_HOST = 0
OWNER_COPROCESSOR = 1


def sharedmem_transact(memory, value):
    """
    Send a request through shared memory to the emulated process and read
    the response from it.
    """

    write_shared_memory(memory, VALUE_ADDR, value)
    write_shared_memory(memory, OWNER_ADDR, OWNER_COPROCESSOR)
    starttime = time.time()
    while read_shared_memory(memory, OWNER_ADDR) != OWNER_HOST:
        if (time.time() - starttime) > 10:
            raise test_harness.TestException(
                'timed out waiting for response from coprocessor')

        time.sleep(0.1)

    return read_shared_memory(memory, VALUE_ADDR)

@test_harness.test
def shared_memory(_):
    """See coprocessor.c for an explanation of this test"""

    test_harness.build_program(['coprocessor.c'])

    # Start the emulator
    memory_file = tempfile.NamedTemporaryFile()
    args = [test_harness.BIN_DIR + 'emulator', '-s',
            memory_file.name, test_harness.HEX_FILE]
    process = subprocess.Popen(args, stdout=subprocess.PIPE,
                               stderr=subprocess.STDOUT)

    try:
        # Hack: Need to wait for the emulator to create the shared memory
        # file and initialize it. There's currently no way for the emulator
        # to signal that this has completed, so just sleep a bit and hope
        # it's done.
        time.sleep(1.0)
        memory = mmap.mmap(memory_file.fileno(), 0)
        testvalues = [random.randint(0, 0xffffffff) for __ in range(10)]
        for value in testvalues:
            computed = sharedmem_transact(memory, value)
            if computed != (value ^ 0xffffffff):
                raise test_harness.TestException('Incorrect value from coprocessor expected ' +
                                                 hex(value ^ 0xffffffff) +
                                                 ' got ' + hex(computed))
    finally:
        process.kill()

test_harness.execute_tests()
