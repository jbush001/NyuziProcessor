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

XXX does not test error recovery
XXX does not test console mode
'''

import os
import pty
import select
import stat
import subprocess
import sys

sys.path.insert(0, '../..')
import test_harness

RECEIVE_TIMEOUT_S = 30

# From software/bootrom/protocol.h
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
    def __init__(self, hexfile, ramdisk = None):
        self.serial_boot_process = None
        self.pipe = None
        self.hexfile = hexfile
        self.ramdisk = ramdisk


    def __enter__(self):
        # Create a virtual serial device
        self.pipe, slave = pty.openpty()
        sname = os.ttyname(slave)
        args = [test_harness.SERIAL_BOOT_PATH, sname, self.hexfile]
        if self.ramdisk != None:
            args.append(self.ramdisk)

        self.serial_boot_process = subprocess.Popen(args, stdout=subprocess.PIPE,
            stderr=subprocess.PIPE)

        return self


    def __exit__(self, *unused):
        self.serial_boot_process.kill()
        os.close(self.pipe)


    def get_result(self):
        """Wait for the process to exit and return its output.

        This does not check the exit value of the program.

        Args:
            None

        Returns:
            (string, string) Standard out and standard error

        Raises:
            TestException if the program does not exit in
            RECEIVE_TIMEOUT_S seconds.
        """
        out, err = test_harness.TimedProcessRunner().communicate(
            self.serial_boot_process, RECEIVE_TIMEOUT_S)
        return out.decode('ascii'), err.decode('ascii')


    def expect_bytes(self, expect_sequence):
        """Receive a sequence of bytes from the serial loader and check them.

        Args:
            expect_sequence: list (int)
                The sequence of byte values that are expected to be received.

        Returns:
            Nothing

        Raises:
            TestException if the program doesn't send_bytes this sequence of bytes
        """
        if test_harness.DEBUG:
            print('expect bytes: ' + str(expect_sequence))

        for index, expect_byte in enumerate(expect_sequence):
            got = self.recv()
            if got != expect_byte:
                raise test_harness.TestException('serial mismatch @{}: expected {} got {}'.format(
                    index, expect_byte, got))

    def expect_int(self, expected):
        """Check a 32-bit value received from the serial port.

        The value is four bytes in little endian order.
        Args:
            expected: integer
                The value that should be received

        Returns:
            Nothing

        Raises:
            TestException if the number doesn't match.
        """
        if test_harness.DEBUG:
            print('expect int: ' + str(value))

        intval = self.recv()
        intval |= self.recv() << 8
        intval |= self.recv() << 16
        intval |= self.recv() << 24
        if intval != expected:
            raise test_harness.TestException('Int value mismatch: wanted {} got {}'.format(
                expected, intval))

    def expect_error(self, error_message):
        """Check for an error message printed to stderr by the serial loader.

        Args:
            error_message: string
                The message that should be printed. This should appear somewhere in the output,
                but other values before or after this will be ignored.

        Returns:
            Nothing

        Raises:
            TestException if the loader returns a zero exit value (no error) or
            it does not print the error message somewhere on stderr.
        """
        out, err = self.get_result()
        if not self.serial_boot_process.poll():
            raise test_harness.TestException('Loader did not return error result as expected')

        if err.find(error_message) == -1:
            raise test_harness.TestException('Did not get expected error message. Got: ' + err)


    def expect_normal_exit(self):
        """Check that the serial loader returns a 0 exit value.
        Args:
            None

        Returns:
            Nothing

        Raises:
            TestException if the program returns a non-zero exit value.
        """
        self.send_bytes([4]) # ^D Exits interactive mode
        out, err = self.get_result()
        if self.serial_boot_process.poll():
            raise test_harness.TestException('Process return error')


    def recv(self):
        """Receive a single byte from the serial loader program.

        The byte is meant to be sent to the dev board.
        Args:
            None

        Returns:
            integer byte value

        Raises:
            TestException if nothing can be read for over RECEIVE_TIMEOUT_S
            seconds.
        """
        r, w, e = select.select([self.pipe], [], [], RECEIVE_TIMEOUT_S)
        if self.pipe in r:
            return ord(os.read(self.pipe, 1))
        else:
            raise test_harness.TestException('serial read timed out')

    def send_bytes(self, values):
        """send_bytes a set of bytes to the serial loader program.

        Args:
            values: array (integer)
                Sequence of values to be sent. Each will be encoded as
                one byte.
        Returns:
            Nothing

        Raises:
            Nothing
        """

        if test_harness.DEBUG:
            print('send_bytes: ' + str(values))

        os.write(self.pipe, bytes(values))

    def send_int(self, value):
        """Send an integer to the serial loader.

        4 bytes in little endian order.

        Args:
            value: int
                The value to be send

        Returns:
            Nothing

        Raises:
            Nothing
        """
        bytevals = [value & 0xff, (value >> 8) & 0xff,
            (value >> 16) & 0xff, (value >> 24) & 0xff]
        os.write(self.pipe, bytes(bytevals))

def compute_checksum(byte_array):
    """Compute FNV-1 checksum.

    Args:
        byte_array: list (int)
            Each element represents a a byte

    Returns:
        integer Computed checksum

    Raises:
        Nothing
    """

    checksum = 2166136261
    for b in byte_array:
        checksum = ((checksum ^ b) * 16777619) & 0xffffffff

    return checksum


def check_load_memory_command(loader, address, values):
    if test_harness.DEBUG:
        print('check_load_memory_command 0x{:x} 0x{:x}'.format(address, len(values)))

    loader.expect_bytes([LOAD_MEMORY_REQ])
    loader.expect_int(address)
    loader.expect_int(len(values))
    loader.expect_bytes(values)
    loader.send_bytes([LOAD_MEMORY_ACK])
    loader.send_int(compute_checksum(values))


def int_to_be_bytes(x):
    """Convert an integer to an array of four integer values representing the big endian byte encoding."""
    return [(x >> 24) & 0xff, (x >> 16) & 0xff, (x >> 8) & 0xff, x & 0xff]


@test_harness.test(['emulator'])
def read_valid_hex(*unused):
    """Read a valid hex file.

    The passed file exercises of valid syntactic constructs."""
    with SerialLoader('testhex.txt') as loader:
        loader.expect_bytes([PING_REQ])
        loader.send_bytes([PING_ACK])

        values = [0xad, 0xde, 0x97, 0x20, 0x25, 0xb0, 0xf5, 0xa8, 0x25, 0xd5, 0x8d, 0x97, 0x2b, 0x01, 0xc1, 0x25]
        check_load_memory_command(loader, 0, values)

        loader.expect_bytes([EXECUTE_REQ])
        loader.send_bytes([EXECUTE_ACK])
        loader.expect_normal_exit()

@test_harness.test(['emulator'])
def load_memory_chunking(*unused):
    """Test loading values into memory.

    This uses multiple blocks to ensure they are chunked correctly.
    The source file is just a sequence of ascending values, starting at
    an arbitrary number.
    """
    with SerialLoader('sequence-hex.txt') as loader:
        loader.expect_bytes([PING_REQ])
        loader.send_bytes([PING_ACK])

        def make_sequence(base_index, count):
            bytevals = []
            for x in range(0, int(count / 4)):
                bytevals += int_to_be_bytes(x + base_index)

            return bytevals

        check_load_memory_command(loader, 0, make_sequence(0x12345678, 1024))
        check_load_memory_command(loader, 1024, make_sequence(0x12345678 + 256, 1024))

        # Partial block with one word
        check_load_memory_command(loader, 2048, make_sequence(0x12345678 + 512, 4))

        loader.expect_bytes([EXECUTE_REQ])
        loader.send_bytes([EXECUTE_ACK])
        loader.expect_normal_exit()


@test_harness.test(['emulator'])
def load_address_chunks(*unused):
    """Test using @ in hex file to specify address."""
    with SerialLoader('address-hex.txt') as loader:
        loader.expect_bytes([PING_REQ])
        loader.send_bytes([PING_ACK])

        # First chunk at 100000
        values = [0xb7, 0x6d, 0xff, 0xf1, 0x39, 0xe4, 0x84, 0x58, 0x11, 0xba, 0xda, 0x14, 0x39, 0xfb, 0x40, 0xf4]
        check_load_memory_command(loader, 0x100000, values)

        # Second chunk at 201234
        values = [0x9a, 0x01, 0x3b, 0x2a, 0xfb, 0xda, 0xe5, 0xba]
        check_load_memory_command(loader, 0x201234, values)

        loader.expect_bytes([EXECUTE_REQ])
        loader.send_bytes([EXECUTE_ACK])
        loader.expect_normal_exit()


@test_harness.test(['emulator'])
def load_ack_timeout(*unused):
    """After send_bytesing a load request, the target does not respond.

    Ensure the loader times out and returns an error"""
    with SerialLoader('testhex.txt') as loader:
        loader.expect_bytes([PING_REQ])
        loader.send_bytes([PING_ACK])

        loader.expect_bytes([LOAD_MEMORY_REQ])
        loader.expect_int(0) # Address
        loader.expect_int(16) # Length
        # send_bytes nothing, it will time out
        loader.expect_error('00000000 Did not get ack for load memory')


@test_harness.test(['emulator'])
def load_bad_ack(*unused):
    """After send_bytesing a load request, the target responds with an invalid command.

    Ensure the loader returns an error"""

    with SerialLoader('testhex.txt') as loader:
        loader.expect_bytes([PING_REQ])
        loader.send_bytes([PING_ACK])

        loader.expect_bytes([LOAD_MEMORY_REQ])
        loader.send_int(0) # Address
        loader.send_int(16) # Length
        loader.send_bytes([0x00])
        loader.expect_error('00000000 Did not get ack for load memory, got 00 instead')


@test_harness.test(['emulator'])
def load_checksum_timeout(*unused):
    """Timeout while waiting for checksum after load."""

    with SerialLoader('testhex.txt') as loader:
        loader.expect_bytes([PING_REQ])
        loader.send_bytes([PING_ACK])

        loader.expect_bytes([LOAD_MEMORY_REQ])
        loader.send_bytes([LOAD_MEMORY_ACK, 0x99, 0x98, 0xf5])
        # Don't send_bytes last byte of checksum, will time out
        loader.expect_error('00000000 timed out reading checksum')


@test_harness.test(['emulator'])
def checksum_mismatch(*unused):
    with SerialLoader('testhex.txt') as loader:
        loader.expect_bytes([PING_REQ])
        loader.send_bytes([PING_ACK])

        loader.expect_bytes([LOAD_MEMORY_REQ])
        loader.expect_int(0) # Address
        loader.expect_int(16) # Length
        values = [0xad, 0xde, 0x97, 0x20, 0x25, 0xb0, 0xf5, 0xa8, 0x25, 0xd5, 0x8d, 0x97, 0x2b, 0x01, 0xc1, 0x25]
        loader.expect_bytes(values)
        loader.send_bytes([LOAD_MEMORY_ACK])
        loader.send_int(compute_checksum(values) + 1)  # Invalid checksum
        loader.expect_error('00000000 checksum mismatch want')


@test_harness.test(['emulator'])
def clear_mem(*unused):
    """Successfully clear memory."""
    with SerialLoader('zerohex.txt') as loader:
        loader.expect_bytes([PING_REQ])
        loader.send_bytes([PING_ACK])

        loader.expect_bytes([CLEAR_MEMORY_REQ])
        loader.expect_int(0) # Address
        loader.expect_int(32) # Length
        loader.send_bytes([CLEAR_MEMORY_ACK])

        loader.expect_bytes([EXECUTE_REQ])
        loader.send_bytes([EXECUTE_ACK])
        loader.expect_normal_exit()


@test_harness.test(['emulator'])
def clear_mem_bad_ack(*unused):
    with SerialLoader('zerohex.txt') as loader:
        loader.expect_bytes([PING_REQ])
        loader.send_bytes([PING_ACK])

        loader.expect_bytes([CLEAR_MEMORY_REQ])
        loader.send_int(0) # Address
        loader.send_int(32) # Length
        loader.send_bytes([0x00])
        loader.expect_error('00000000 Did not get ack for clear memory')


@test_harness.test(['emulator'])
def clear_mem_ack_timeout(*unused):
    with SerialLoader('zerohex.txt') as loader:
        loader.expect_bytes([PING_REQ])
        loader.send_bytes([PING_ACK])

        loader.expect_bytes([CLEAR_MEMORY_REQ])
        loader.send_int(0) # Address
        loader.send_int(32) # Length
        # send_bytes nothing, it will time out
        loader.expect_error('00000000 Did not get ack for clear memory')


@test_harness.test(['emulator'])
def ping_retries(*unused):
    """If the target doesn't respond to pings, the loader should retry."""
    with SerialLoader('testhex.txt') as loader:
        loader.expect_bytes([PING_REQ, PING_REQ, PING_REQ, PING_REQ])
        loader.send_bytes([PING_ACK])

        loader.expect_bytes([LOAD_MEMORY_REQ])


@test_harness.test(['emulator'])
def ping_timeout(*unused):
    """...but if it retries long enough with no response, return an error"""
    with SerialLoader('testhex.txt') as loader:
        loader.expect_bytes([PING_REQ, PING_REQ, PING_REQ, PING_REQ])
        # send_bytes nothing, it should time out
        loader.expect_error('target is not responding')


@test_harness.test(['emulator'])
def invalid_character(*ignored):
    """Invalid character in hex file"""
    with SerialLoader('invalid-character-hex.txt') as loader:
        loader.expect_error('read_hex_file: Invalid character ! in line 4')


@test_harness.test(['emulator'])
def number_out_of_range(*ignored):
    """A number is too big"""
    with SerialLoader('number-out-of-range-hex.txt') as loader:
        loader.expect_error('read_hex_file: number out of range in line 3')


@test_harness.test(['emulator'])
def load_ramdisk(*ignored):
    with SerialLoader('testhex.txt', 'ramdisk-bin') as loader:
        loader.expect_bytes([PING_REQ])
        loader.send_bytes([PING_ACK])

        # Load program
        values = [0xad, 0xde, 0x97, 0x20, 0x25, 0xb0, 0xf5, 0xa8, 0x25, 0xd5, 0x8d, 0x97, 0x2b, 0x01, 0xc1, 0x25]
        check_load_memory_command(loader, 0, values)

        # Load the ramdisk
        values = [0x12, 0x34, 0x56, 0x78, 0xab, 0xcd, 0xef, 0x55]
        check_load_memory_command(loader, 0x4000000, values)

        loader.expect_bytes([EXECUTE_REQ])
        loader.send_bytes([EXECUTE_ACK])
        loader.expect_normal_exit()


@test_harness.test(['emulator'])
def missing_ramdisk_file(*ignored):
    with SerialLoader('testhex.txt', 'this_does_not_exist.bin') as loader:
        loader.expect_error('Error opening input file')


@test_harness.test(['emulator'])
def missing_hex_file(*ignored):
    with SerialLoader('this_does_not_exist.txt') as loader:
        loader.expect_error('read_hex_file: error opening hex file')


@test_harness.test(['emulator'])
def invalid_serial_port(*ignored):
    args = [test_harness.SERIAL_BOOT_PATH, 'this_device_does_not_exist', 'testhex.txt']
    try:
        process = subprocess.check_output(args, stderr=subprocess.STDOUT)
        raise test_harness.TestException('loader did not return error')
    except subprocess.CalledProcessError as exc:
        error_message = exc.output.decode()
        if error_message.find('couldn\'t open serial port') == -1:
            raise test_harness.TestException('returned unknown error: ' + error_message)


@test_harness.test(['emulator'])
def not_a_serial_port(*ignored):
    # Note serial port (2nd arg) is normal file
    args = [test_harness.SERIAL_BOOT_PATH, 'testhex.txt', 'testhex.txt']
    try:
        process = subprocess.check_output(args, stderr=subprocess.STDOUT)
        raise test_harness.TestException('loader did not return error')
    except subprocess.CalledProcessError as exc:
        error_message = exc.output.decode()
        if error_message.find('Unable to initialize serial port') == -1:
            raise test_harness.TestException('returned unknown error: ' + error_message)

@test_harness.test(['emulator'])
def execute_failure(*ignored):
    with SerialLoader('testhex.txt') as loader:
        loader.expect_bytes([PING_REQ])
        loader.send_bytes([PING_ACK])

        # Load program
        values = [0xad, 0xde, 0x97, 0x20, 0x25, 0xb0, 0xf5, 0xa8, 0x25, 0xd5, 0x8d, 0x97, 0x2b, 0x01, 0xc1, 0x25]
        check_load_memory_command(loader, 0, values)

        # Execute command
        loader.expect_bytes([EXECUTE_REQ])
        loader.send_bytes([0])    # Bad response
        loader.expect_error('Target returned invalid response starting execution')


test_harness.execute_tests()
