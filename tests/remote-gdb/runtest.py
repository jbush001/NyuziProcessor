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
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implieconn.
# See the License for the specific language governing permissions and
# limitations under the License.
#

"""
Validates remote GDB debugger interface in emulator
"""

import os
import socket
import subprocess
import sys
import time

sys.path.insert(0, '..')
import test_harness


# Setting this to true will print all GDB commands and responses
# to the console and will also print all output from the emulator.
DEBUG = False


class DebugConnection(object):

    """
    Encapsulates remote GDB socket connection to emulator. It supports
    __enter__ and __exit__ methods so it can be used in the 'with' construct
    to automatically close the socket when the test is done.
    """

    def __init__(self):
        self.sock = None

    def __enter__(self):
        # Retry loop
        for _ in range(10):
            try:
                time.sleep(0.3)
                self.sock = socket.socket()
                self.sock.connect(('localhost', 8000))
                self.sock.settimeout(5)
                break
            except socket.error:
                pass

        return self

    def __exit__(self, *unused):
        self.sock.close()

    def _send_packet(self, body):
        """
        Send request 'body' to emulator. This will encapsulate the request
        in a packet and add the checksum.
        """

        if DEBUG:
            print('SEND: ' + body)

        self.sock.send(str.encode('$' + body + '#'))

        # Checksum
        self.sock.send(str.encode('\x00\x00'))

    def _receive_packet(self):
        """
        Wait for a full packet to be received from the peer and return
        just the body.
        """

        while True:
            leader = self.sock.recv(1)
            if leader == '':
                raise test_harness.TestException('unexpected socket close')

            if leader == b'$':
                break

            if leader != b'+':
                raise test_harness.TestException(
                    'unexpected character ' + str(leader))

        body = b''
        while True:
            char = self.sock.recv(1)
            if char == b'#':
                break

            body += char

        # Checksum
        self.sock.recv(2)

        if DEBUG:
            print('RECV: ' + body)

        return body

    def expect(self, command, value):
        """
        Sends 'command' to remote GDB value, then waits for the response.
        If the response doesn't match 'value', this will throw TestException.
        """

        self._send_packet(command)
        response = self._receive_packet()
        if response != str.encode(value):
            raise test_harness.TestException(
                'unexpected response. Wanted ' + value + ' got ' + str(response))


class EmulatorProcess(object):

    """
    Manages spawning the emulator and automatically stopping it at the
    end of the test. It supports __enter__ and __exit__ methods so it
    can be used in the 'with' construct.
    """

    def __init__(self, hexfile, num_cores=1):
        self.hexfile = hexfile
        self.num_cores = num_cores
        self.process = None
        self.output = None

    def __enter__(self):
        emulator_args = [
            test_harness.BIN_DIR + 'emulator',
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

    def __exit__(self, *unused):
        self.process.kill()
        if self.output:
            self.output.close()


@test_harness.test
def gdb_breakpoint(_):
    """
    Validate stopping at a breakpoint and continuing after stopping.
    This sets two breakpoints
    """

    hexfile = test_harness.build_program(['count.S'], image_type='raw')
    with EmulatorProcess(hexfile), DebugConnection() as conn:
        # Set breakpoint
        conn.expect('Z0,0000000c', 'OK')

        # Set second breakpoint at next instruction
        conn.expect('Z0,00000010', 'OK')

        # Continue
        conn.expect('C', 'S05')

        # Read last signal
        conn.expect('?', 'S05')

        # Read PC register. Should be 0x000000c, but endian swapped
        conn.expect('g1f', '0c000000')

        # Read s0, which should be 3
        conn.expect('g00', '03000000')

        # Continue again.
        conn.expect('C', 'S05')

        # Ensure the instruction it stopped at is
        # executed and it breaks on the next instruction
        conn.expect('g1f', '10000000')

        # Read s0, which should be 4
        conn.expect('g00', '04000000')


@test_harness.test
def gdb_remove_breakpoint(_):
    hexfile = test_harness.build_program(['count.S'], image_type='raw')
    with EmulatorProcess(hexfile), DebugConnection() as conn:
        # Set breakpoint
        conn.expect('Z0,0000000c', 'OK')

        # Set second breakpoint
        conn.expect('Z0,00000014', 'OK')

        # Clear first breakpoint
        conn.expect('z0,0000000c', 'OK')

        # Continue
        conn.expect('C', 'S05')

        # Read PC register. Should be at second breakpoint
        conn.expect('g1f', '14000000')

        # Read s0, which should be 5
        conn.expect('g00', '05000000')


@test_harness.test
def gdb_breakpoint_errors(_):
    hexfile = test_harness.build_program(['count.S'], image_type='raw')
    with EmulatorProcess(hexfile), DebugConnection() as conn:
        # Set invalid breakpoint (memory out of range)
        conn.expect('Z0,20000000', '')

        # Set invalid breakpoint (unaligned)
        conn.expect('Z0,00000003', '')

        # Set a valid breakpoint, then try to set the same address again
        conn.expect('Z0,00000008', 'OK')
        conn.expect('Z0,00000008', '')

        # Remove invalid breakpoint (doesn't exist)
        conn.expect('z0,00000004', '')


@test_harness.test
def gdb_single_step(_):
    hexfile = test_harness.build_program(['count.S'], image_type='raw')
    with EmulatorProcess(hexfile), DebugConnection() as conn:
        # Read PC register
        conn.expect('g1f', '00000000')

        # Single step
        conn.expect('S', 'S05')

        # Read PC register
        conn.expect('g1f', '04000000')

        # Read s0
        conn.expect('g00', '01000000')

        # Single step (note here I use the lowercase version)
        conn.expect('s', 'S05')

        # Read PC register
        conn.expect('g1f', '08000000')

        # Read s0
        conn.expect('g00', '02000000')


@test_harness.test
def gdb_single_step_breakpoint(_):
    """
    Ensure that if you single step through a breakpoint, it doesn't
    trigger and get stuck
    """
    hexfile = test_harness.build_program(['count.S'], image_type='raw')
    with EmulatorProcess(hexfile), DebugConnection() as conn:
        # Set breakpoint at second instruction (address 0x8)
        conn.expect('Z0,00000004', 'OK')

        # Single step over first instruction
        conn.expect('S', 'S05')

        # Single step. This one has a breakpoint, but we won't
        # stop at it.
        conn.expect('S', 'S05')

        # Read PC register
        conn.expect('g1f', '08000000')

        # Read s0
        conn.expect('g00', '02000000')


@test_harness.test
def gdb_read_write_memory(_):
    hexfile = test_harness.build_program(['count.S'], image_type='raw')
    with EmulatorProcess(hexfile), DebugConnection() as conn:
        # Read program code at address 0. This should match values
        # in count.hex
        conn.expect('m0,10', '0004800700088007000c800700108007')

        # (address, data)
        tests = [
            (0x1000, '523c66b3'),
            (0x1234, '22'),
            (0x2242, '45f280397a5a3255fa19238693ff13c729'),
            (0x100000, '55483c091aac1e8c6db4bed1'),
            (0x200000, '16e1d56029e912a04121ce41a635155f3442355533703fafcb57f8295dd6330f82f9ffc40edb589fac1523665dc2f6e80c1e2de9718d253fcbce1c8a52c9dc21'),
        ]

        # Write memory
        for addr, data in tests:
            conn.expect('M' + hex(addr)[2:] + ',' +
                        hex(int(len(data) / 2))[2:] + ':' + data, 'OK')

        # Read and verify
        for addr, data in tests:
            conn.expect('m' + hex(addr)[2:] + ',' +
                        hex(int(len(data) / 2))[2:], data)

        # Try to write a bad address (out of range)
        # Doesn't return an error, test just ensures it
        # doesn't crash
        conn.expect('M10000000,4,12345678', 'OK')

        # Try to read a bad address (out of range)
        # As above, doesn't return error (returns 0xff...),
        # but ensure it doesn't crash.
        conn.expect('m10000000,4', 'ffffffff')


@test_harness.test
def gdb_read_write_register(_):
    hexfile = test_harness.build_program(['register_values.S'])
    with EmulatorProcess(hexfile), DebugConnection() as conn:
        # Run code to load registers
        conn.expect('C', 'S05')

        # Check values set by program (remote GDB returns in swapped byte
        # order...)
        conn.expect('g1', '7d7f3e85')
        conn.expect('g20', 'f13403ef9d08309993f7819954ae4b3f7aeaa28f538fecbd9536f59c6d7251269525ee70d26e8d34f48912639c86ae5dba426c83aa8455e1e2dbba4b41a4f321')

        tests = [
            (0, 'd3839b18'),
            (1, '7b53cc78'),
            (30, '0904c47d'),
            (32, 'aef331bc7dbd6f1d042be4d6f1e1649855d864387eb8f0fd49c205c37790d1874078516c1a05c74f67678456679ba7e05bb5aed7303c5aeeeba6e619accf702a'),
            (36, 'cb7e3668a97ef8ea55902658b62a682406f7206f75e5438ff95b4519fed1e73e16ce5a29b4385fa2560820f0c8f42227709387dbad3a8208b57c381e268ffe38'),
            (63, '9e2d89afb0633c2f64b2eb4fdbba4663401ee673753a66d6d899e4a4101ae4920b0b16f0e716e4f7d62d83b5784740c138ac6ab94fa14256ebb468e25f20e02f')
        ]

        for reg, value in tests:
            conn.expect('G' + hex(reg)[2:] + ',' + value, 'OK')

        for reg, value in tests:
            conn.expect('g' + hex(reg)[2:], value)

        # Read invalid register index
        conn.expect('g40', '')

        # Write invalid register index
        conn.expect('G40,12345678', '')


@test_harness.test
def gdb_register_info(_):
    hexfile = test_harness.build_program(['count.S'], image_type='raw')
    with EmulatorProcess(hexfile), DebugConnection() as conn:
        # Scalar registers
        for idx in range(27):
            regid = str(idx + 1)
            conn.expect('qRegisterInfo' + hex(idx + 1)[2:], 'name:s' + regid +
                        ';bitsize:32;encoding:uint;format:hex;'
                        'set:General Purpose Scalar Registers;gcc:' + regid +
                        ';dwarf:' + regid + ';')

        # These registers (sp, fp, ra, pc) are special and have additional
        # information.
        names = ['fp', 'sp', 'ra', 'pc']
        for idx, name in zip(range(27, 32), names):
            regid = str(idx + 1)
            conn.expect('qRegisterInfo' + hex(idx + 1)[2:], 'name:s' + regid +
                        ';bitsize:32;encoding:uint;format:hex;'
                        'set:General Purpose Scalar Registers;gcc:' + regid +
                        ';dwarf:' + regid + ';generic:' + name + ';')

        # Vector registers
        for idx in range(32, 63):
            regid = str(idx + 1)
            conn.expect('qRegisterInfo' + hex(idx + 1)[2:], 'name:v' + str(idx - 31) +
                        ';bitsize:512;encoding:uint;format:vector-uint32;'
                        'set:General Purpose Vector Registers;gcc:' + regid +
                        ';dwarf:' + regid + ';')

        conn.expect('qRegisterInfo64', '')


@test_harness.test
def gdb_select_thread(_):
    hexfile = test_harness.build_program(['multithreaded.S'], image_type='raw')
    with EmulatorProcess(hexfile, num_cores=2), DebugConnection() as conn:
        # Read thread ID
        conn.expect('qC', 'QC01')

        # Each line is one thread
        tests = [
            (7, 0xc7733c56),
            (5, 0xf54adec3),
            (1, 0x5afaf01e),
            (2, 0x1964682e),
            (3, 0x16cc6be1),
            (8, 0xcbff923),
            (4, 0x4596de2),
            (6, 0xcd920ca6),
        ]

        # Step all threads through initialization code (5 instructions)
        for thid in range(len(tests)):
            # Switch to thread
            conn.expect('Hg' + str(thid + 1), 'OK')

            # Read thread ID
            conn.expect('qC', 'QC0' + str(thid + 1))

            for index in range(5):
                conn.expect('S', 'S05')

                # Read PC register
                conn.expect('g1f', '{:08x}'.format(
                    test_harness.endian_swap((index + 1) * 4)))

        # Now all threads are at the same instruction:
        # 00000014 move s0, 1

        # Step each thread independently some number of steps and
        # write a value to register 1
        for index, (num_steps, regval) in enumerate(tests):
            conn.expect('Hg' + str(index + 1), 'OK')  # Switch to thread
            for _ in range(num_steps):
                conn.expect('S', 'S05')

            conn.expect('G01,{:08x}'.format(regval), 'OK')

        # Read back PC and register values
        for index, (num_steps, regval) in enumerate(tests):
            conn.expect('Hg' + str(index + 1), 'OK')   # Switch to thread
            conn.expect('g1f', '{:08x}'.format(
                test_harness.endian_swap(0x14 + num_steps * 4)))
            conn.expect('g01', '{:08x}'.format(regval))

        # Try to switch to an invalid thread ID
        conn.expect('Hgfe', '')

        # Ensure still on thread 8
        conn.expect('qC', 'QC08')


@test_harness.test
def gdb_thread_info(_):
    # Run with one core, four threads
    hexfile = test_harness.build_program(['count.S'], image_type='raw')
    with EmulatorProcess(hexfile), DebugConnection() as conn:
        conn.expect('qfThreadInfo', 'm1,2,3,4')

    # Run with two cores, eight threads
    with EmulatorProcess(hexfile, num_cores=2), DebugConnection() as conn:
        conn.expect('qfThreadInfo', 'm1,2,3,4,5,6,7,8')


@test_harness.test
def gdb_invalid_command(_):
    hexfile = test_harness.build_program(['count.S'], image_type='raw')
    with EmulatorProcess(hexfile), DebugConnection() as conn:
        # As far as I know, this is not a valid commanconn...
        # An error response returns nothing in the body
        conn.expect('@', '')


@test_harness.test
def gdb_queries(_):
    """Miscellaneous query commands not covered in other tests"""

    hexfile = test_harness.build_program(['count.S'], image_type='raw')
    with EmulatorProcess(hexfile), DebugConnection() as conn:
        conn.expect('qLaunchSuccess', 'OK')
        conn.expect('qHostInfo', 'triple:nyuzi;endian:little;ptrsize:4')
        conn.expect('qProcessInfo', 'pid:1')
        conn.expect('qsThreadInfo', 'l')   # No active threads
        conn.expect('qThreadStopInfo', 'S00')
        conn.expect('qC', 'QC01')

        # Should be invalid
        conn.expect('qZ', '')


@test_harness.test
def gdb_vcont(_):
    hexfile = test_harness.build_program(['count.S'], image_type='raw')
    with EmulatorProcess(hexfile), DebugConnection() as conn:
        # Set breakpoint
        conn.expect('Z0,00000010', 'OK')

        # Step
        conn.expect('vCont;s:0001', 'S05')
        conn.expect('g1f', '04000000')

        # Continue
        conn.expect('vCont;c', 'S05')
        conn.expect('g1f', '10000000')


@test_harness.test
def gdb_crash(_):
    hexfile = test_harness.build_program(['crash.S'], image_type='raw')
    with EmulatorProcess(hexfile), DebugConnection() as conn:
        conn.expect('c', 'S05')
        conn.expect('g1f', '15000000')


test_harness.execute_tests()
