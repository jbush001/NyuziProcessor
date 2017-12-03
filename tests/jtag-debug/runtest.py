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
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implieconn.
# See the License for the specific language governing permissions and
# limitations under the License.
#

import socket
import subprocess
import sys
import time
import struct
import os

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

class VerilatorProcess(object):

    """
    Manages spawning the emulator and automatically stopping it at the
    end of the test. It supports __enter__ and __exit__ methods so it
    can be used in the 'with' construct.
    """

    def __init__(self, hexfile):
        self.hexfile = hexfile
        self.process = None
        self.output = None

    def __enter__(self):
        verilator_args = [
            test_harness.BIN_DIR + 'verilator_model',
            '+bin=' + self.hexfile,
            '+jtag_port=' + str(CONTROL_PORT),
            self.hexfile
        ]

        # XXX in the event of an error, would like to capture the output of verilator
        # and report in exception.
        if DEBUG:
            self.output = None
        else:
            self.output = open(os.devnull, 'w')

        self.process = subprocess.Popen(verilator_args, stdout=self.output,
                                        stderr=subprocess.STDOUT)
        return self

    def __exit__(self, *unused):
        self.process.kill()
        if self.output:
            self.output.close()

class DebugConnection(object):

    """
    Encapsulates control socket connection to JTAG port on verilator. It supports
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
                self.sock.connect(('localhost', CONTROL_PORT))
                self.sock.settimeout(5)
                break
            except socket.error:
                pass

        return self

    def __exit__(self, *unused):
        self.sock.close()

    def jtag_transfer(self, instruction, data_length, data):
        if DEBUG:
            print('Sending JTAG command 0x{:x} data 0x{:x}'.format(instruction, data))

        self.sock.send(struct.pack('<BIBQ', INSTRUCTION_LENGTH, instruction,
                                   data_length, data))
        data_val = struct.unpack('<Q', self.sock.recv(8))[0] & ((1 << data_length) - 1)
        if DEBUG:
            print('received JTAG response 0x{:x}'.format(data_val))

        return data_val

@test_harness.test
def jtag_id(_):
    hexfile = test_harness.build_program(['test_program.S'])
    with VerilatorProcess(hexfile), DebugConnection() as conn:
        idcode = conn.jtag_transfer(INST_IDCODE, 32, 0xffffffff)
        test_harness.assert_equal(EXPECTED_IDCODE, idcode)

# Bypass is currently broken
#@test_harness.test
#def jtag_bypass(_):
#    hexfile = test_harness.build_program(['test_program.S'])
#    with VerilatorProcess(hexfile), DebugConnection() as conn:
#        VALUE = 0x267521cf
#        shifted = conn.jtag_transfer(INST_BYPASS, 32, VALUE)
#        test_harness.assert_equal(EXPECTED_IDCODE, VALUE)

# XXX todo: test with multiple threads
@test_harness.test
def jtag_inject(_):
    hexfile = test_harness.build_program(['test_program.S'])
    with VerilatorProcess(hexfile), DebugConnection() as conn:
        conn.jtag_transfer(INST_CONTROL, 7, 0x1)
        conn.jtag_transfer(INST_WRITE_DATA, 32, 0x3b643e9a)  # First value to transfer
        conn.jtag_transfer(INST_INJECT_INST, 32, 0xac0000b2) # getcr s5, 18
        conn.jtag_transfer(INST_WRITE_DATA, 32, 0xd1dc20a3)  # Second value to transfer
        conn.jtag_transfer(INST_INJECT_INST, 32, 0xac0000d2) # getcr s6, 18
        conn.jtag_transfer(INST_INJECT_INST, 32, 0xc03300e5) # xor s7, s5, s6
        conn.jtag_transfer(INST_INJECT_INST, 32, 0x8c0000f2) # setcr s7, 18
        test_harness.assert_equal(0xeab81e39, conn.jtag_transfer(INST_READ_DATA, 32, 0))

# Transfer a bunch of messages. The JTAG test harness stub randomizes the
# path through the state machine, so this will help get better coverage.
@test_harness.test
def jtag_stress(_):
    hexfile = test_harness.build_program(['test_program.S'])
    with VerilatorProcess(hexfile), DebugConnection() as conn:
        conn.jtag_transfer(INST_CONTROL, 7, 0x1)
        conn.jtag_transfer(INST_INJECT_INST, 32, 0x0f3ab800) # move s0, 0xeae
        conn.jtag_transfer(INST_INJECT_INST, 32, 0x0f48d020) # move s1, 0x1234
        for x in range(40):
            conn.jtag_transfer(INST_INJECT_INST, 32, 0x8c000012) # setcr s0, 18
            test_harness.assert_equal(0xeae, conn.jtag_transfer(INST_READ_DATA, 32, 0))
            conn.jtag_transfer(INST_INJECT_INST, 32, 0x8c000032) # setcr s1, 18
            test_harness.assert_equal(0x1234, conn.jtag_transfer(INST_READ_DATA, 32, 0))

test_harness.execute_tests()
