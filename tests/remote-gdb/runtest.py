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
# The file count.hex consists of instructions:
# 00000000 move s0, 1
# 00000004 move s0, 2
# 00000008 move s0, 3
# 0000000c move s0, 4
# 00000010 move s0, 5
# ...
#

import sys
import subprocess
import re
import os
import socket
import time

sys.path.insert(0, '..')
from test_harness import *


DEBUG = False


class DebugConnection:

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
        global DEBUG

        if DEBUG:
            print('SEND: ' + body)

        self.sock.send('$')
        self.sock.send(body)
        self.sock.send('#')

        # Checksum
        self.sock.send('\x00')
        self.sock.send('\x00')

    def receivePacket(self):
        global DEBUG

        while True:
            leader = self.sock.recv(1)
            if leader == '$':
                break

            if leader != '+':
                raise Exception('unexpected character ' + leader)

        body = ''
        while True:
            c = self.sock.recv(1)
            if c == '#':
                break

            body += c

        # Checksum
        self.sock.recv(2)

        if DEBUG:
            print('RECV: ' + body)

        return body

    def expect(self, value):
        response = self.receivePacket()
        if response != value:
            raise TestException(
                'unexpected response. Wanted ' + value + ' got ' + response)


class EmulatorTarget:

    def __init__(self, hexfile, num_cores=1):
        self.hexfile = hexfile
        self.num_cores = num_cores

    def __enter__(self):
        global DEBUG

        emulator_args = [
            BIN_DIR + 'emulator',
            '-m',
            'gdb',
            '-p',
            str(self.num_cores),
            self.hexfile
        ]

        if DEBUG:
            self.output = None
        else:
            self.output = open(os.devnull, 'w')

        self.process = subprocess.Popen(emulator_args, stdout=self.output,
                                        stderr=subprocess.STDOUT)
        return self

    def __exit__(self, type, value, traceback):
        self.process.kill()
        if self.output:
            self.output.close()

# Validate stopping at a breakpoint and continuing after stopping.
# This sets two breakpoints
def test_breakpoint(name):
    with EmulatorTarget('count.hex') as p, DebugConnection() as d:
        # Set breakpoint
        d.sendPacket('Z0,0000000c')
        d.expect('OK')

        # Set second breakpoint at next instruction
        d.sendPacket('Z0,00000010')
        d.expect('OK')

        # Continue
        d.sendPacket('C')
        d.expect('S05')

        # Read last signal
        d.sendPacket('?')
        d.expect('S05')

        # Read PC register. Should be 0x000000c, but endian swapped
        d.sendPacket('g1f')
        d.expect('0c000000')

        # Read s0, which should be 3
        d.sendPacket('g00')
        d.expect('03000000')

        # Continue again.
        d.sendPacket('C')
        d.expect('S05')

        # Ensure the instruction it stopped at is
        # executed and it breaks on the next instruction
        d.sendPacket('g1f')
        d.expect('10000000')

        # Read s0, which should be 4
        d.sendPacket('g00')
        d.expect('04000000')


def test_remove_breakpoint(name):
    with EmulatorTarget('count.hex') as p, DebugConnection() as d:
        # Set breakpoint
        d.sendPacket('Z0,0000000c')
        d.expect('OK')

        # Set second breakpoint
        d.sendPacket('Z0,00000014')
        d.expect('OK')

        # Clear first breakpoint
        d.sendPacket('z0,0000000c')
        d.expect('OK')

        # Continue
        d.sendPacket('C')
        d.expect('S05')

        # Read PC register. Should be at second breakpoint
        d.sendPacket('g1f')
        d.expect('14000000')

        # Read s0, which should be 5
        d.sendPacket('g00')
        d.expect('05000000')

        # Try to remove an invalid breakpoint
        d.sendPacket('z0,00000004')
        d.expect('')


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

        # Single step (note here I use the lowercase version)
        d.sendPacket('s')
        d.expect('S05')

        # Read PC register
        d.sendPacket('g1f')
        d.expect('08000000')

        # Read s0
        d.sendPacket('g00')
        d.expect('02000000')


# Ensure that if you single step through a breakpoint, it doesn't
# trigger and get stuck
def test_single_step_breakpoint(name):
    with EmulatorTarget('count.hex') as p, DebugConnection() as d:
        # Set breakpoint at second instruction (address 0x8)
        d.sendPacket('Z0,00000004')
        d.expect('OK')

        # Single step over first instruction
        d.sendPacket('S')
        d.expect('S05')

        # Single step. This one has a breakpoint, but we won't
        # stop at it.
        d.sendPacket('S')
        d.expect('S05')

        # Read PC register
        d.sendPacket('g1f')
        d.expect('08000000')

        # Read s0
        d.sendPacket('g00')
        d.expect('02000000')


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


def test_read_write_register(name):
    with EmulatorTarget('count.hex') as p, DebugConnection() as d:
        # Write registers
        d.sendPacket('G01,7b53cc78')
        d.expect('OK')
        d.sendPacket('G14,0904c47d')
        d.expect('OK')
        d.sendPacket(
            'G20,aef331bc7dbd6f1d042be4d6f1e1649855d864387eb8f0fd49c205c37790d1874078516c1a05c74f67678456679ba7e05bb5aed7303c5aeeeba6e619accf702a')
        d.expect('OK')
        d.sendPacket(
            'G24,cb7e3668a97ef8ea55902658b62a682406f7206f75e5438ff95b4519fed1e73e16ce5a29b4385fa2560820f0c8f42227709387dbad3a8208b57c381e268ffe38')
        d.expect('OK')

        # Read registers
        d.sendPacket('g01')
        d.expect('7b53cc78')
        d.sendPacket('g14')
        d.expect('0904c47d')
        d.sendPacket('g20')
        d.expect('aef331bc7dbd6f1d042be4d6f1e1649855d864387eb8f0fd49c205c37790d1874078516c1a05c74f67678456679ba7e05bb5aed7303c5aeeeba6e619accf702a')
        d.sendPacket('g24')
        d.expect('cb7e3668a97ef8ea55902658b62a682406f7206f75e5438ff95b4519fed1e73e16ce5a29b4385fa2560820f0c8f42227709387dbad3a8208b57c381e268ffe38')

        # Read invalid register index
        d.sendPacket('g40')
        d.expect('')

        # Write invalid register index
        d.sendPacket('G40,12345678')
        d.expect('')


def test_register_info(name):
    with EmulatorTarget('count.hex') as p, DebugConnection() as d:
        for x in range(27):
            regid = str(x + 1)
            d.sendPacket('qRegisterInfo' + hex(x + 1)[2:])
            d.expect('name:s' + regid + ';bitsize:32;encoding:uint;format:hex;set:General Purpose Scalar Registers;gcc:'
                     + regid + ';dwarf:' + regid + ';')

        # XXX skipped fp, sp, ra, pc, which (correctly) have additional
        # info at the end.

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
        d.sendPacket('Hg2')
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
        d.sendPacket('Hg1')
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


def test_thread_info(name):
    # Run with one core, four threads
    with EmulatorTarget('count.hex') as p, DebugConnection() as d:
        d.sendPacket('qfThreadInfo')
        d.expect('m1,2,3,4')

    # Run with two cores, eight threads
    with EmulatorTarget('count.hex', num_cores=2) as p, DebugConnection() as d:
        d.sendPacket('qfThreadInfo')
        d.expect('m1,2,3,4,5,6,7,8')


def test_invalid_command(name):
    with EmulatorTarget('count.hex') as p, DebugConnection() as d:
        # As far as I know, this is not a valid command...
        d.sendPacket('@')

        # An error response returns nothing in the body
        d.expect('')

# Miscellaneous query commands not covered in other tests


def test_queries(name):
    with EmulatorTarget('count.hex') as p, DebugConnection() as d:
        d.sendPacket('qLaunchSuccess')
        d.expect('OK')

        d.sendPacket('qHostInfo')
        d.expect('triple:nyuzi;endian:little;ptrsize:4')

        d.sendPacket('qProcessInfo')
        d.expect('pid:1')

        d.sendPacket('qsThreadInfo')
        d.expect('l')   # No active threads

        d.sendPacket('qThreadStopInfo')
        d.expect('S00')

        d.sendPacket('qC')
        d.expect('QC01')

        # Should be invalid
        d.sendPacket('qZ')
        d.expect('')

# Test vCont command
def test_vcont(name):
    with EmulatorTarget('count.hex') as p, DebugConnection() as d:
        # Set breakpoint
        d.sendPacket('Z0,00000010')
        d.expect('OK')

        # Step
        d.sendPacket('vCont;s:0001')
        d.expect('S05')
        d.sendPacket('g1f')
        d.expect('04000000')

        # Continue
        d.sendPacket('vCont;c')
        d.expect('S05')
        d.sendPacket('g1f')
        d.expect('10000000')

register_tests(test_breakpoint, ['gdb_breakpoint'])
register_tests(test_remove_breakpoint, ['gdb_remove_breakpoint'])
register_tests(test_single_step, ['gdb_single_step'])
register_tests(test_single_step_breakpoint, ['gdb_single_step_breakpoint'])
register_tests(test_read_write_memory, ['gdb_read_write_memory'])
register_tests(test_read_write_register, ['gdb_read_write_register'])
register_tests(test_register_info, ['gdb_register_info'])
register_tests(test_select_thread, ['gdb_select_thread'])
register_tests(test_thread_info, ['gdb_thread_info'])
register_tests(test_invalid_command, ['gdb_invalid_command'])
register_tests(test_queries, ['gdb_queries'])
register_tests(test_vcont, ['gdb_vcont'])
execute_tests()
