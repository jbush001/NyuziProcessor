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
        self.DEBUG = False

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
        if self.DEBUG:
            print('SEND: ' + body)

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

        body = ''
        while True:
            c = self.sock.recv(1)
            if c == '#':
                break

            body += c

        # Checksum
        self.sock.recv(2)

        if self.DEBUG:
            print('RECV: ' + body)

        return body

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
        # Read PC register
        d.sendPacket('g1f')
        d.expect('00000000')

        # Single step
        d.sendPacket('S')
        d.expect('S05')

        # Read PC register
        d.sendPacket('g1f')
        d.expect('04000000')

        # Read s0
        d.sendPacket('g00')
        d.expect('01000000')

        # Single step
        d.sendPacket('S')
        d.expect('S05')

        # Read PC register
        d.sendPacket('g1f')
        d.expect('08000000')

        # Read s0
        d.sendPacket('g00')
        d.expect('02000000')

        # Kill
        d.sendPacket('k')

def test_read_write_memory(name):
    with EmulatorTarget('count.hex') as p, DebugConnection() as d:
        # Write memory at 1M
        d.sendPacket('M00100000,0c:55483c091aac1e8c6db4bed1')
        d.expect('OK')

        # Write memory at 2M
        d.sendPacket('M00200000,8:b8d30e6f7cec41b1')
        d.expect('OK')

        # Read memory at 1M
        d.sendPacket('m00100000,0c')
        d.expect('55483c091aac1e8c6db4bed1')

        # Read memory at 2M
        d.sendPacket('m00200000,8')
        d.expect('b8d30e6f7cec41b1')

def test_register_info(name):
    with EmulatorTarget('count.hex') as p, DebugConnection() as d:
        for x in range(27):
            regid = str(x + 1)
            d.sendPacket('qRegisterInfo' + hex(x + 1)[2:])
            d.expect('name:s' + regid + ';bitsize:32;encoding:uint;format:hex;set:General Purpose Scalar Registers;gcc:'
                + regid + ';dwarf:' + regid + ';')

        # XXX skipped fp, sp, ra, pc, which have additional crud at the end.

        for x in range(32, 63):
            regid = str(x + 1)
            d.sendPacket('qRegisterInfo' + hex(x + 1)[2:])
            d.expect('name:v' + str(x - 31) + ';bitsize:512;encoding:uint;format:vector-uint32;set:General Purpose Vector Registers;gcc:'
                + regid + ';dwarf:' + regid + ';')

        d.sendPacket('qRegisterInfo64')
        d.expect('')

def test_select_thread(name):
    with EmulatorTarget('count.hex') as p, DebugConnection() as d:
        # Read thread ID
        d.sendPacket('qC')
        d.expect('QC01')

        # Step thread 1
        d.sendPacket('S')
        d.expect('S05')

        # Read PC register
        d.sendPacket('g1f')
        d.expect('04000000')

        # Read s0
        d.sendPacket('g00')
        d.expect('01000000')

        # Switch to thread 2. This is not enabled, so we can't step it, but
        # Make sure registers are different.
        d.sendPacket('H2')
        d.expect('OK')

        # Read thread ID
        d.sendPacket('qC')
        d.expect('QC02')

        # Read PC. Should be 0.
        d.sendPacket('g1f')
        d.expect('00000000')

        # XXX If set register were implemented, could check for known
        # value in s0.

        # Switch back to thread 1. Ensure state is correct.
        d.sendPacket('H1')
        d.expect('OK')

        # Read thread ID
        d.sendPacket('qC')
        d.expect('QC01')

        # Read PC register. Should be 4 again
        d.sendPacket('g1f')
        d.expect('04000000')

        # Read s0.
        d.sendPacket('g00')
        d.expect('01000000')


register_tests(test_breakpoint, ['gdb_breakpoint'])
register_tests(test_single_step, ['gdb_single_step'])
register_tests(test_read_write_memory, ['gdb_read_write_memory'])
register_tests(test_register_info, ['gdb_register_info'])
execute_tests()
