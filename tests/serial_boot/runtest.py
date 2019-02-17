#!/usr/bin/env python3
#
# Copyright 2019 Jeff Bush
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

'''Verify the FPGA serial loader.

This uses a pseudo terminal to simulate the serial port, with
this acting as the FPGA board. These tests are marked somewhat
incorrectly as emulator tests, even though there's no emulator
running, as there wasn't an applicable target type.
'''

import os
import pty
import stat
import subprocess
import sys

sys.path.insert(0, '..')
import test_harness

LOAD_MEMORY_REQ = 0xc0
LOAD_MEMORY_ACK = 0xc1
EXECUTE_REQ = 0xc2
EXECUTE_ACK = 0xc3
PING_REQ = 0xc4
PING_ACK = 0xc5
CLEAR_MEMORY_REQ = 0xc6
CLEAR_MEMORY_ACK = 0xc7
BAD_COMMAND = 0xc8

class SerialLoader(object):
    def __init__(self, hexfile):
        self.serial_boot_process = None
        self.pipe = None
        self.hexfile = hexfile
        self.portsuffix =  'wf'

    def __enter__(self):
        # Create a virtual serial device
        self.pipe, slave = pty.openpty()
        sname = os.ttyname(slave)
        args = [test_harness.SERIAL_BOOT_PATH, sname, self.hexfile]
        self.serial_boot_process = subprocess.Popen(args, stdout=subprocess.PIPE,
            stderr=subprocess.PIPE)
        return self

    def __exit__(self, *unused):
        self.serial_boot_process.kill()
        os.close(self.pipe)


    def get_result(self):
        out, err = test_harness.TimedProcessRunner().communicate(
            self.serial_boot_process, 30)
        return out.decode('ascii'), err.decode('ascii')

    def expect_bytes(self, expect_sequence):
        for expect_byte in expect_sequence:
            got = self.recv()
            if got != expect_byte:
                raise test_harness.TestException('mismatch: expected '
                    + str(expect_byte) + ' got ' + str(got))

    def expect_error(self, error_message):
        out, err = self.get_result()
        if not self.serial_boot_process.poll():
            raise TestException('Loader did not return error result as expected')

        if err.find(error_message) == -1:
            raise test_harness.TestException('Did not get expected error message. Got: ' + err)

    def expect_normal_exit(self):
        self.send([4]) # ^D Exits interactive mode
        out, err = self.get_result()
        if self.serial_boot_process.poll():
            raise TestException('Process return error')

    def recv(self):
        return ord(os.read(self.pipe, 1))

    def send(self, values):
        os.write(self.pipe, bytes(values))


@test_harness.test(['emulator'])
def load_memory(*unused):
    with SerialLoader('testhex.txt') as loader:
        loader.expect_bytes([PING_REQ])
        loader.send([PING_ACK])
        loader.expect_bytes([LOAD_MEMORY_REQ, 0, 0, 0, 0, 16, 0, 0, 0])
        loader.expect_bytes([0xad, 0xde, 0x97, 0x20, 0x25, 0xb0, 0xf5, 0xa8, 0x25, 0xd5, 0x8d, 0x97, 0x2b, 0x01, 0xc1, 0x25])
        loader.send([LOAD_MEMORY_ACK, 0x99, 0x98, 0xf5, 0xd7])
        loader.expect_bytes([EXECUTE_REQ])
        loader.send([EXECUTE_ACK])
        loader.expect_normal_exit()


@test_harness.test(['emulator'])
def checksum_mismatch(*unused):
    with SerialLoader('testhex.txt') as loader:
        loader.expect_bytes([PING_REQ])
        loader.send([PING_ACK])
        loader.expect_bytes([LOAD_MEMORY_REQ, 0, 0, 0, 0, 16, 0, 0, 0])
        loader.expect_bytes([0xad, 0xde, 0x97, 0x20, 0x25, 0xb0, 0xf5, 0xa8, 0x25, 0xd5, 0x8d, 0x97, 0x2b, 0x01, 0xc1, 0x25])
        loader.send([LOAD_MEMORY_ACK, 0x99, 0x98, 0xf5, 0xd6])
        loader.expect_error('00000000 checksum mismatch want d7f59899 got d6f59899')

@test_harness.test(['emulator'])
def fill_ack_timeout(*unused):
    with SerialLoader('testhex.txt') as loader:
        loader.expect_bytes([PING_REQ])
        loader.send([PING_ACK])
        loader.expect_bytes([LOAD_MEMORY_REQ, 0, 0, 0, 0, 16, 0, 0, 0])
        # Send nothing, it will time out
        loader.expect_error('00000000 Did not get ack for load memory')


@test_harness.test(['emulator'])
def fill_bad_ack(*unused):
    with SerialLoader('testhex.txt') as loader:
        loader.expect_bytes([PING_REQ])
        loader.send([PING_ACK])
        loader.expect_bytes([LOAD_MEMORY_REQ, 0, 0, 0, 0, 16, 0, 0, 0])
        loader.send([0x00])
        loader.expect_error('00000000 Did not get ack for load memory, got 00 instead')


@test_harness.test(['emulator'])
def clear_mem(*unused):
    with SerialLoader('zerohex.txt') as loader:
        loader.expect_bytes([PING_REQ])
        loader.send([PING_ACK])
        loader.expect_bytes([CLEAR_MEMORY_REQ, 0, 0, 0, 0, 32, 0, 0, 0])
        loader.send([CLEAR_MEMORY_ACK])
        loader.expect_bytes([EXECUTE_REQ])
        loader.send([EXECUTE_ACK])
        loader.expect_normal_exit()


@test_harness.test(['emulator'])
def clear_mem_bad_ack(*unused):
    with SerialLoader('zerohex.txt') as loader:
        loader.expect_bytes([PING_REQ])
        loader.send([PING_ACK])
        loader.expect_bytes([CLEAR_MEMORY_REQ, 0, 0, 0, 0, 32, 0, 0, 0])
        loader.send([0x00])
        loader.expect_error('00000000 Did not get ack for clear memory')


@test_harness.test(['emulator'])
def clear_mem_ack_timeout(*unused):
    with SerialLoader('zerohex.txt') as loader:
        loader.expect_bytes([PING_REQ])
        loader.send([PING_ACK])
        loader.expect_bytes([CLEAR_MEMORY_REQ, 0, 0, 0, 0, 32, 0, 0, 0])
        # Send nothing, it will time out
        loader.expect_error('00000000 Did not get ack for clear memory')


@test_harness.test(['emulator'])
def ping_timeout(*unused):
    with SerialLoader('testhex.txt') as loader:
        loader.expect_bytes([PING_REQ, PING_REQ, PING_REQ, PING_REQ])
        # Send nothing, it should time out
        loader.expect_error('target is not responding')


test_harness.execute_tests()
