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

#
# Validates remote GDB debugger interface in emulator
#

import sys
import subprocess
import re
import os
import socket
import time

sys.path.insert(0, '..')
from test_harness import *


class DebugConnection:

    def __init__(self):
        pass

    def __enter__(self):
        for retry in range(10):
            try:
                time.sleep(0.3)
                self.sock = socket.socket()
                self.sock.connect(('localhost', 8000))
                self.sock.settimeout(5)
                break
            except Exception, e:
                pass

        return self

    def __exit__(self, type, value, traceback):
        self.sock.close()

    def sendPacket(self, body):
        self.sock.send('$')
        self.sock.send(body)
        self.sock.send('#')

        # Checksum
        self.sock.send('\x00')
        self.sock.send('\x00')

    def receivePacket(self):
        while True:
            leader = self.sock.recv(1)
            if leader == '$':
                break

            if leader != '+':
                raise Exception('unexpected character ' + leader);

        contents = ''
        while True:
            c = self.sock.recv(1)
            if c == '#':
                break

            contents += c

        # Checksum
        self.sock.recv(2)

        return contents

    def expect(self, value):
        response = self.receivePacket()
        if response != value:
            raise TestException('unexpected response. Wanted ' + value + ' got ' + response)


class EmulatorTarget:

    def __init__(self, hexfile):
        self.hexfile = hexfile

    def __enter__(self):
        emulator_args = [
            BIN_DIR + 'emulator',
            '-m',
            'gdb',
            self.hexfile
        ]

        self.fnull = open(os.devnull, 'w')
        self.process = subprocess.Popen(emulator_args, stdout=self.fnull,
                                        stderr=subprocess.STDOUT)
        return self

    def __exit__(self, type, value, traceback):
        self.process.kill()
        self.fnull.close()

# The file count.hex consists of instructions:
# move s0, 1
# move s0, 2
# move s0, 3
# ...
def test_breakpoint(name):
    with EmulatorTarget('count.hex') as p, DebugConnection() as d:
        # Set breakpoint at third instruction (address c)
        d.sendPacket('Z0,0000000c')
        d.expect('OK')

        # Continue
        d.sendPacket('C')
        d.expect('S05')

        # Read PC register. Should be 0x000000c, but endian swapped
        # XXX bug, ends up being address + 4 because of way register
        # increment works.
        #d.sendPacket('g1f')
        #d.expect('0c000000')

        # Read s0, which should be 2
        d.sendPacket('g00')
        d.expect('03000000')

        # Kill
        d.sendPacket('k')

def test_single_step(name):
    with EmulatorTarget('count.hex') as p, DebugConnection() as d:
        d.sendPacket('S')
        d.expect('S05')

        d.sendPacket('g1f')
        d.expect('04000000')

        d.sendPacket('g00')
        d.expect('01000000')

        d.sendPacket('S')
        d.expect('S05')

        d.sendPacket('g1f')
        d.expect('08000000')

        d.sendPacket('g00')
        d.expect('02000000')

        # Kill
        d.sendPacket('k')

def test_read_write_memory(name):
    with EmulatorTarget('count.hex') as p, DebugConnection() as d:
        d.sendPacket('M00100000,0c:55483c091aac1e8c6db4bed1')
        d.expect('OK')

        d.sendPacket('M00200000,8:b8d30e6f7cec41b1')
        d.expect('OK')

        d.sendPacket('m00100000,0c')
        d.expect('55483c091aac1e8c6db4bed1')

        d.sendPacket('m00200000,8')
        d.expect('b8d30e6f7cec41b1')

register_tests(test_breakpoint, ['gdb_breakpoint'])
register_tests(test_single_step, ['gdb_single_step'])
register_tests(test_read_write_memory, ['gdb_read_write_memory'])
execute_tests()
