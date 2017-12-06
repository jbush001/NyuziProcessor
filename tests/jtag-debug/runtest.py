#!/usr/bin/env python3
#
# Copyright 2017 Jeff Bush
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

import socket
import subprocess
import sys
import time
import struct
from threading import Thread

sys.path.insert(0, '..')
import test_harness

DEBUG = False
CONTROL_PORT = 8541
INSTRUCTION_LENGTH = 4
EXPECTED_IDCODE = 0x20e129f4    # Matches value in hardware/core/config.sv

# JTAG instructions
INST_IDCODE = 0
INST_EXTEST = 1
INST_INTEST = 2
INST_CONTROL = 3
INST_INJECT_INST = 4
INST_READ_DATA = 5
INST_WRITE_DATA = 6
INST_BYPASS = 15


# XXX need to test that the TAP powers up with the proper instruction (BYPASS)
# This may require a different mode that only shifts the data bits.


class JTAGTestFixture(object):

    """
    Spawns the Verilator model and opens a socket to communicate with it
    Supports __enter__ and __exit__ methods so it can be used in the 'with'
    construct to automatically clean up after itself.
    """

    def __init__(self, hexfile):
        self.hexfile = hexfile
        self.process = None
        self.sock = None
        self.output = ''
        self.reader_thread = None
        self.last_response = 0

    def __enter__(self):
        verilator_args = [
            test_harness.BIN_DIR + 'verilator_model',
            '+bin=' + self.hexfile,
            '+jtag_port=' + str(CONTROL_PORT),
            self.hexfile
        ]

        self.process = subprocess.Popen(verilator_args, stdout=subprocess.PIPE,
                                        stderr=subprocess.STDOUT)

        # Retry loop
        for _ in range(10):
            try:
                time.sleep(0.3)
                self.sock = socket.socket()
                self.sock.connect(('localhost', CONTROL_PORT))
                self.sock.settimeout(5)
                break
            except socket.error:
                pass
        else:
            self.process.kill()
            raise test_harness.TestException(
                'failed to connect to verilator model')

        self.reader_thread = Thread(target=self._read_output)
        self.reader_thread.daemon = True
        self.reader_thread.start()
        return self

    def __exit__(self, *unused):
        if self.reader_thread.isAlive():
            self.reader_thread.join(0.5)

        self.process.kill()
        if self.sock:
            self.sock.close()

    def jtag_transfer(self, instruction, data_length, data):
        if DEBUG:
            print('Sending JTAG command 0x{:x} data 0x{:x}'.format(
                instruction, data))

        self.sock.send(struct.pack('<BIBQ', INSTRUCTION_LENGTH, instruction,
                                   data_length, data))

        response_data = self.sock.recv(8)

        # Read output from program to check for errors
        if not response_data:
            raise test_harness.TestException(
                'socket closed prematurely:\n' + self.get_program_output())

        self.last_response = struct.unpack('<Q', response_data)[
            0] & ((1 << data_length) - 1)
        if DEBUG:
            print('received JTAG response 0x{:x}'.format(self.last_response))

        return self.last_response

    def get_program_output(self):
        '''
        Return everything verilator printed to stdout before exiting.
        This won't return anything if the program was killed (which is the
        common case if the program didn't die with an assertion)
        '''

        if self.reader_thread:
            self.reader_thread.join(0.5)

        return self.output

    def expect_response(self, expected):
        if self.last_response != expected:
            raise test_harness.TestException('unexpected JTAG response. Wanted {} got {}:\n{}'
                                             .format(expected, self.last_response,
                                             self.get_program_output()))

    def _read_output(self):
        '''
        Need to read output on a separate thread, otherwise this will lock
        up until the process exits. This seems to be the only way to do it
        portably in python.
        '''
        while True:
            got = self.process.stdout.read(0x100)
            if not got:
                break

            if DEBUG:
                print(got)

            self.output += got.decode()


@test_harness.test
def jtag_id(_):
    hexfile = test_harness.build_program(['test_program.S'])
    with JTAGTestFixture(hexfile) as fixture:
        fixture.jtag_transfer(INST_IDCODE, 32, 0xffffffff)
        fixture.expect_response(EXPECTED_IDCODE)


@test_harness.test
def jtag_bypass(_):
    hexfile = test_harness.build_program(['test_program.S'])
    with JTAGTestFixture(hexfile) as fixture:
        value = 0x267521cf
        fixture.jtag_transfer(INST_BYPASS, 32, value)
        fixture.expect_response(value << 1)


@test_harness.test
def jtag_inject(_):
    hexfile = test_harness.build_program(['test_program.S'])
    with JTAGTestFixture(hexfile) as fixture:
        # Enable second thread
        fixture.jtag_transfer(INST_CONTROL, 7, 0x1)
        # Address of thread resume register
        fixture.jtag_transfer(INST_WRITE_DATA, 32, 0xffff0100)
        fixture.jtag_transfer(INST_INJECT_INST, 32, 0xac000012)  # getcr s0, 18
        fixture.jtag_transfer(INST_INJECT_INST, 32, 0x0f000c20)  # move s1, 3
        fixture.jtag_transfer(INST_INJECT_INST, 32,
                              0x88000020)  # store s1, (s0)

        # Load register values in thread 0
        # First value to transfer
        fixture.jtag_transfer(INST_WRITE_DATA, 32, 0x3b643e9a)
        fixture.jtag_transfer(INST_INJECT_INST, 32, 0xac0000b2)  # getcr s5, 18
        # Second value to transfer
        fixture.jtag_transfer(INST_WRITE_DATA, 32, 0xd1dc20a3)
        fixture.jtag_transfer(INST_INJECT_INST, 32, 0xac0000d2)  # getcr s6, 18

        # Load register values in thread 1
        fixture.jtag_transfer(INST_CONTROL, 7, 0x3)
        # First value to transfer
        fixture.jtag_transfer(INST_WRITE_DATA, 32, 0xa6532328)
        fixture.jtag_transfer(INST_INJECT_INST, 32, 0xac0000b2)  # getcr s5, 18
        # Second value to transfer
        fixture.jtag_transfer(INST_WRITE_DATA, 32, 0xf01839a0)
        fixture.jtag_transfer(INST_INJECT_INST, 32, 0xac0000d2)  # getcr s6, 18

        # Perform operation on thread 0
        fixture.jtag_transfer(INST_CONTROL, 7, 0x1)
        fixture.jtag_transfer(INST_INJECT_INST, 32,
                              0xc03300e5)  # xor s7, s5, s6
        fixture.jtag_transfer(INST_INJECT_INST, 32, 0x8c0000f2)  # setcr s7, 18
        fixture.jtag_transfer(INST_READ_DATA, 32, 0)
        fixture.expect_response(0xeab81e39)

        # Perform operation on thread 1
        fixture.jtag_transfer(INST_CONTROL, 7, 0x3)
        fixture.jtag_transfer(INST_INJECT_INST, 32,
                              0xc03300e5)  # xor s7, s5, s6
        fixture.jtag_transfer(INST_INJECT_INST, 32, 0x8c0000f2)  # setcr s7, 18
        fixture.jtag_transfer(INST_READ_DATA, 32, 0)
        fixture.expect_response(0x564b1a88)


@test_harness.test
def jtag_stress(_):
    """
    Transfer a bunch of messages. The JTAG test harness stub randomizes the
    path through the state machine, so this will help get better coverage.
    """

    hexfile = test_harness.build_program(['test_program.S'])
    with JTAGTestFixture(hexfile) as fixture:
        fixture.jtag_transfer(INST_CONTROL, 7, 0x1)
        fixture.jtag_transfer(INST_INJECT_INST, 32,
                              0x0f3ab800)  # move s0, 0xeae
        fixture.jtag_transfer(INST_INJECT_INST, 32,
                              0x0f48d020)  # move s1, 0x1234
        for _ in range(40):
            fixture.jtag_transfer(INST_INJECT_INST, 32,
                                  0x8c000012)  # setcr s0, 18
            fixture.jtag_transfer(INST_READ_DATA, 32, 0)
            fixture.expect_response(0xeae)
            fixture.jtag_transfer(INST_INJECT_INST, 32,
                                  0x8c000032)  # setcr s1, 18
            fixture.jtag_transfer(INST_READ_DATA, 32, 0)
            fixture.expect_response(0x1234)

test_harness.execute_tests()
