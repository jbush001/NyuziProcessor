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

"""
Validate hardware JTAG debugging implementation. The Verilator model has a
stub module that simulates a JTAG host. This test communicates with it over
a socket, which allows sending and receiving data and instructions.
"""

import socket
import struct
import subprocess
import sys
import time
from threading import Thread

sys.path.insert(0, '..')
import test_harness

CONTROL_PORT = 8541
INSTRUCTION_LENGTH = 4
EXPECTED_IDCODE = 0x4d20dffb  # Derived from settings in hardware/core/config.sv

# JTAG instructions
INST_IDCODE = 0
INST_EXTEST = 1
INST_INTEST = 2
INST_CONTROL = 3
INST_INJECT_INST = 4
INST_TRANSFER_DATA = 5
INST_STATUS = 6
INST_BYPASS = 15

STATUS_READY = 0
STATUS_ISSUED = 1
STATUS_ROLLED_BACK = 2

# When passed, does not shift instruction register
INST_SAME = -1

# XXX does not test TRST signal


def mask_value(value, num_bits):
    return value & ((1 << num_bits) - 1)


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

        # The process may take a little time to start listening for incoming
        # connections so retry a few times if it isn't ready yet.
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
        self.process.kill()
        if self.sock:
            self.sock.close()

    def jtag_transfer(self, instruction, data_length, data):
        """
        Shift an instruction and/or data to the target.
        If instruction is set to INST_SAME, this will not shift an instruction
        If data_length is zero, it will not shift any data. If both are set to
        not transfer, it will initiate a reset of the target.
        """

        if test_harness.DEBUG:
            print('Sending JTAG command 0x{:x} data 0x{:x}'.format(
                instruction, data))

        if instruction == INST_SAME:
            instruction_length = 0
            instruction = 0
        else:
            instruction_length = INSTRUCTION_LENGTH

        self.sock.send(struct.pack('<BIBQ', instruction_length, instruction,
                                   data_length, data))

        response_data = self.sock.recv(12)
        if not response_data:
            raise test_harness.TestException(
                'error reading response:\n' + self.get_program_output())

        _, self.last_response = struct.unpack('<IQ', response_data)
        self.last_response = mask_value(self.last_response, data_length)
        if test_harness.DEBUG:
            print('received JTAG response 0x{:x}'.format(self.last_response))

    def test_instruction_shift(self, value):
        """
        Shift a value through the instruction register, then capture
        the bits that are shifted out and check that they match.
        """

        # Send an instruction that is twice as long as the instruction register.
        # The first bits shifted in should come right back out in the high
        # bits of the result.
        self.sock.send(struct.pack('<BIBQ', INSTRUCTION_LENGTH * 2, value,
                                   0, 0))
        response_data = self.sock.recv(12)
        if not response_data:
            raise test_harness.TestException(
                'error reading response:\n' + self.get_program_output())

        instr_response, _ = struct.unpack('<IQ', response_data)
        if instr_response != value << INSTRUCTION_LENGTH:
            raise test_harness.TestException('invalid response: wanted {}, got {}'.format(
                value, instr_response))

    def get_program_output(self):
        """
        Return everything verilator printed to stdout before exiting.
        This won't read anything if the program was killed (which is the
        common case if the program didn't die with an assertion), but
        we usually call in the case that it has exited with an error.
        """
        # Give the reader thread time to finish reading responses.
        if self.reader_thread:
            self.reader_thread.join(0.5)

        return self.output

    def expect_data(self, expected_data):
        """
        Throw an exception if the bits shifted out of TDO during the last data
        transfer do not match the passed value
        """
        if self.last_response != expected_data:
            raise test_harness.TestException('unexpected JTAG data response. Wanted {} got {}:\n{}'
                                             .format(expected_data, self.last_response,
                                                     self.get_program_output()))

    def _read_output(self):
        """
        Read text that is printed by the verilator process to standard out.
        This needs to happen on a separate thread to avoid blocking the
        main thread. This seems to be the only way to do it portably in
        python.
        """
        while True:
            got = self.process.stdout.read(0x100)
            if not got:
                break

            if test_harness.DEBUG:
                print(got)

            self.output += got.decode()


@test_harness.test(['verilator'])
def jtag_idcode(_, target):
    """
    Validate response to IDCODE request
    """
    hexfile = test_harness.build_program(['test_program.S'])
    with JTAGTestFixture(hexfile) as fixture:
        # Ensure the default instruction after reset is IDCODE
        fixture.jtag_transfer(INST_SAME, 32, 0xffffffff)
        fixture.expect_data(EXPECTED_IDCODE)

        # Explicitly shift the IDCODE instruction to make sure it is
        # correct.
        fixture.jtag_transfer(INST_IDCODE, 32, 0xffffffff)
        fixture.expect_data(EXPECTED_IDCODE)


@test_harness.test(['verilator'])
def jtag_reset(_, target):
    """
    Test transition to reset state
    """
    hexfile = test_harness.build_program(['test_program.S'])
    with JTAGTestFixture(hexfile) as fixture:
        # Load a different instruction
        fixture.jtag_transfer(INST_TRANSFER_DATA, 32, 0x3b643e9a)

        # Perform a reset (setting zero lengths)
        fixture.jtag_transfer(INST_SAME, 0, 0)

        # Perform data-only transfer. Ensure we get the idcode back.
        # If we hadn't performed a reset, we would get data value
        # that was shifted above.
        fixture.jtag_transfer(INST_SAME, 32, 0xffffffff)
        fixture.expect_data(EXPECTED_IDCODE)


@test_harness.test(['verilator'])
def jtag_bypass(_, target):
    """
    Validate BYPASS instruction, which is a single bit data register
    We should get what we send, shifted by one bit.
    """
    hexfile = test_harness.build_program(['test_program.S'])
    with JTAGTestFixture(hexfile) as fixture:
        value = 0x267521cf
        fixture.jtag_transfer(INST_BYPASS, 32, value)
        fixture.expect_data(value << 1)


@test_harness.test(['verilator'])
def jtag_instruction_shift(_, target):
    """
    Ensure instruction bits shifted into TDI come out TDO. This is necessary
    to properly chain JTAG devices together.
    """
    hexfile = test_harness.build_program(['test_program.S'])
    with JTAGTestFixture(hexfile) as fixture:
        fixture.test_instruction_shift(0xf)
        fixture.test_instruction_shift(0xa)
        fixture.test_instruction_shift(0x5)
        fixture.test_instruction_shift(0x3)
        fixture.test_instruction_shift(0xc)
        fixture.test_instruction_shift(0)


@test_harness.test(['verilator'])
def jtag_data_transfer(_, target):
    """
    Validate bi-directional transfer. The TRANSFER_DATA instruction
    returns the old value of the control register while shifting a new
    one in, so we should see the previous value come out each time
    we write a new one.
    """
    hexfile = test_harness.build_program(['test_program.S'])
    with JTAGTestFixture(hexfile) as fixture:
        fixture.jtag_transfer(INST_TRANSFER_DATA, 32, 0x4be49e7c)
        fixture.jtag_transfer(INST_SAME, 32, 0xb282dc16)
        fixture.expect_data(0x4be49e7c)
        fixture.jtag_transfer(INST_SAME, 32, 0x7ee4838)
        fixture.expect_data(0xb282dc16)


@test_harness.test(['verilator'])
def jtag_inject(_, target):
    """
    Test instruction injection, with multiple threads
    """
    hexfile = test_harness.build_program(['test_program.S'])
    with JTAGTestFixture(hexfile) as fixture:
        # Halt
        fixture.jtag_transfer(INST_CONTROL, 7, 0x1)

        # Load register values in thread 0
        # First value to transfer
        fixture.jtag_transfer(INST_TRANSFER_DATA, 32, 0x3b643e9a)
        fixture.jtag_transfer(INST_INJECT_INST, 32, 0xac0000b2)  # getcr s5, 18
        fixture.jtag_transfer(INST_STATUS, 2, 0)
        fixture.expect_data(STATUS_READY)

        # Second value to transfer
        fixture.jtag_transfer(INST_TRANSFER_DATA, 32, 0xd1dc20a3)
        fixture.jtag_transfer(INST_INJECT_INST, 32, 0xac0000d2)  # getcr s6, 18
        fixture.jtag_transfer(INST_STATUS, 2, 0)
        fixture.expect_data(STATUS_READY)

        # Load register values in thread 1
        fixture.jtag_transfer(INST_CONTROL, 7, 0x3)
        # First value to transfer
        fixture.jtag_transfer(INST_TRANSFER_DATA, 32, 0xa6532328)
        fixture.jtag_transfer(INST_INJECT_INST, 32, 0xac0000b2)  # getcr s5, 18
        fixture.jtag_transfer(INST_STATUS, 2, 0)
        fixture.expect_data(STATUS_READY)

        # Second value to transfer
        fixture.jtag_transfer(INST_TRANSFER_DATA, 32, 0xf01839a0)
        fixture.jtag_transfer(INST_INJECT_INST, 32, 0xac0000d2)  # getcr s6, 18
        fixture.jtag_transfer(INST_STATUS, 2, 0)
        fixture.expect_data(STATUS_READY)

        # Perform operation on thread 0
        fixture.jtag_transfer(INST_CONTROL, 7, 0x1)
        fixture.jtag_transfer(INST_INJECT_INST, 32,
                              0xc03300e5)  # xor s7, s5, s6
        fixture.jtag_transfer(INST_SAME, 32, 0x8c0000f2)  # setcr s7, 18
        fixture.jtag_transfer(INST_STATUS, 2, 0)
        fixture.expect_data(STATUS_READY)

        fixture.jtag_transfer(INST_TRANSFER_DATA, 32, 0)
        fixture.expect_data(0xeab81e39)

        # Perform operation on thread 1
        fixture.jtag_transfer(INST_CONTROL, 7, 0x3)
        fixture.jtag_transfer(INST_INJECT_INST, 32,
                              0xc03300e5)  # xor s7, s5, s6
        fixture.jtag_transfer(INST_SAME, 32, 0x8c0000f2)  # setcr s7, 18
        fixture.jtag_transfer(INST_STATUS, 2, 0)
        fixture.expect_data(STATUS_READY)

        fixture.jtag_transfer(INST_TRANSFER_DATA, 32, 0)
        fixture.expect_data(0x564b1a88)


@test_harness.test(['verilator'])
def jtag_inject_rollback(_, target):
    """
    Test reading status register. I put in an instruction that will miss the
    cache, so I know it will roll back.
    """
    hexfile = test_harness.build_program(['test_program.S'])
    with JTAGTestFixture(hexfile) as fixture:
        # Halt
        fixture.jtag_transfer(INST_CONTROL, 7, 0x1)

        # Load register values in thread 0
        # First value to transfer
        fixture.jtag_transfer(INST_TRANSFER_DATA, 32, 0x10000)  # High address, not cached
        fixture.jtag_transfer(INST_INJECT_INST, 32, 0xac000012)  # getcr s0, 18
        fixture.jtag_transfer(INST_STATUS, 2, 0)
        fixture.expect_data(STATUS_READY)
        fixture.jtag_transfer(INST_INJECT_INST, 32, 0xa8000000)  # load_32 s0, (s0)
        fixture.jtag_transfer(INST_STATUS, 2, 0)
        fixture.expect_data(STATUS_ROLLED_BACK)


# XXX currently disabled because of issue #128
#@test_harness.test(['verilator'])
def jtag_read_write_pc(_, target):
    """
    Use the call instruction to read the program counter. The injection
    logic is supposed to simulate each instruction having the PC of the
    interrupted thread. Then ensure performing a branch will properly
    update the PC of the selected thread. This then resumes the thread
    to ensure it operates properly.
    """
    hexfile = test_harness.build_program(['test_program.S'])
    with JTAGTestFixture(hexfile) as fixture:
        # Switch to thread 1, branch to new address
        fixture.jtag_transfer(INST_CONTROL, 7, 0x3)
        fixture.jtag_transfer(INST_TRANSFER_DATA, 32, 0x10e4)   # `jump_target`
        fixture.jtag_transfer(INST_INJECT_INST, 32, 0xac000012)  # getcr s0, 18
        fixture.jtag_transfer(INST_SAME, 32, 0xf0000000)  # b s0

        # Switch to thread 0, read PC to ensure it is read correctly
        # and that the branch didn't affect it.
        # (the return address will be the branch location + 4)
        fixture.jtag_transfer(INST_CONTROL, 7, 0x1)
        fixture.jtag_transfer(INST_INJECT_INST, 32, 0xf8000000)  # call 0
        fixture.jtag_transfer(INST_SAME, 32, 0x8c0003f2)  # setcr ra, 18
        fixture.jtag_transfer(INST_TRANSFER_DATA, 32, 0)
        fixture.expect_data(0x10d8)

        # Switch back to thread 1, read back PC to ensure it is in the new
        # location
        fixture.jtag_transfer(INST_CONTROL, 7, 0x3)
        fixture.jtag_transfer(INST_INJECT_INST, 32, 0xf8000000)  # call 0
        fixture.jtag_transfer(INST_SAME, 32, 0x8c0003f2)  # setcr ra, 18
        fixture.jtag_transfer(INST_TRANSFER_DATA, 32, 0)
        fixture.expect_data(0x10e8)

        # Resume the thread. It should now execute the instruction to
        # load a new value into s0
        fixture.jtag_transfer(INST_CONTROL, 7, 0x0)

        # Dummy transaction that ensures the processor has time to execute
        # the instructions
        fixture.jtag_transfer(INST_TRANSFER_DATA, 32, 0)

        # Halt again and verify register value.
        fixture.jtag_transfer(INST_CONTROL, 7, 0x3)
        fixture.jtag_transfer(INST_INJECT_INST, 32, 0x8c000012)  # setcr s0, 18
        fixture.jtag_transfer(INST_TRANSFER_DATA, 32, 0)
        fixture.expect_data(0x6bee68ca)


test_harness.execute_tests()
