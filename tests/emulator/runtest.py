#!/usr/bin/env python3
#
# Copyright 2018 Jeff Bush
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

'''
Many other tests in this tree validate parts of the emulator. This module is
for everything that isn't directly tested elsewhere.
'''

import os
import stat
import subprocess
import sys
import time

sys.path.insert(0, '..')
import test_harness

@test_harness.test(['emulator'])
def load_file(*ignored):
    BINARY_OUTPUT = test_harness.WORK_DIR + 'mem.bin'
    args = [test_harness.EMULATOR_PATH, '-d', BINARY_OUTPUT + ',0,0x3c', 'valid_file.data']
    subprocess.check_output(args, stderr=subprocess.STDOUT)
    EXPECTED = [
        0x18fcff4f,
        0x00100400,
        0x20fcff0f,
        0x20000088,
        0x000000f6,
        0xb56f49f,
        0xa4ea27d1,
        0x22e919ac,
        0x287451a5,
        0xcff70833,
        0xfe6a2d11,
        None,
        None,
        0x5148c78a,
        0x12345678
    ]

    with open(BINARY_OUTPUT, 'rb') as file:
        for check in EXPECTED:
            word = file.read(4)
            if not word:
                raise test_harness.TestException('unexpected end of binary output')

            value = (word[0] << 24) | (word[1] << 16) | (word[2] << 8) | word[3]
            if check != None and check != value:
                raise test_harness.TestException('incorrect value, expected {:x} got {:x}'.format(check, value))


def test_emulator_error(args, expected_error):
    args = [test_harness.EMULATOR_PATH] + args
    try:
        result = subprocess.check_output(args, stderr=subprocess.STDOUT)
        raise test_harness.TestException('emulator did not detect error')
    except subprocess.CalledProcessError as exc:
        result = exc.output.decode().strip()
        if not result.startswith(expected_error):
            raise test_harness.TestException('error string did not match, wanted \"{}\", got \"{}\"'
                                             .format(expected_error, result))


@test_harness.test(['emulator'])
def data_out_of_range(*ignored):
    test_emulator_error(['data_out_of_range.data'],
                        'read_hex_file: number out of range in line 2')


@test_harness.test(['emulator'])
def address_out_of_range(*ignored):
    test_emulator_error(['address_out_of_range.data'],
                        'read_hex_file: address out of range in line 2')

@test_harness.test(['emulator'])
def address_unaligned(*ignored):
    test_emulator_error(['address_unaligned.data'],
                        'read_hex_file: address not aligned in line 2')

@test_harness.test(['emulator'])
def bad_character(*ignored):
    test_emulator_error(
        ['bad_character.data'], 'read_hex_file: Invalid character ! in line 4')


@test_harness.test(['emulator'])
def missing_file(*ignored):
    test_emulator_error(['this_file_does_not_exist.hex'],
                        'read_hex_file: error opening hex file: No such file or directory')


@test_harness.test(['emulator'])
def no_file_specified(*ignored):
    test_emulator_error([], 'No image filename specified')

# Test the mechanism for delivering interrupts to the emulator from a
# separate host process (useful for co-emulation)
# XXX A number of error cases do not clean up resources

RECV_PIPE_NAME = test_harness.WORK_DIR + '/nyuzi_emulator_recvint'
SEND_PIPE_NAME = test_harness.WORK_DIR + '/nyuzi_emulator_sendint'


@test_harness.test(['emulator'])
def recv_host_interrupt(*unused):
    try:
        os.remove(RECV_PIPE_NAME)
    except OSError:
        pass    # Ignore if pipe doesn't exist

    test_harness.build_program(['recv_host_interrupt.S'])

    os.mknod(RECV_PIPE_NAME, stat.S_IFIFO | 0o666)

    args = [test_harness.EMULATOR_PATH,
            '-i', RECV_PIPE_NAME, test_harness.HEX_FILE]
    emulator_process = subprocess.Popen(args, stdout=subprocess.PIPE,
                                        stderr=subprocess.STDOUT)

    try:
        interrupt_pipe = os.open(RECV_PIPE_NAME, os.O_WRONLY)

        # Send periodic interrupts to process'
        try:
            for intnum in range(5):
                os.write(interrupt_pipe, str.encode(chr(intnum)))
                time.sleep(0.2)
        except OSError:
            # Broken pipe will occur if the emulator exits early.
            # We'll flag an error after communicate if we don't see a PASS.
            pass

        # Wait for completion
        result, _ = test_harness.TimedProcessRunner().communicate(emulator_process, 60)
        strresult = str(result)
        if 'PASS' not in strresult or 'FAIL' in strresult:
            raise test_harness.TestException('Test failed ' + strresult)
    finally:
        os.close(interrupt_pipe)
        os.unlink(RECV_PIPE_NAME)


@test_harness.test(['emulator'])
def send_host_interrupt(*unused):
    try:
        os.remove(SEND_PIPE_NAME)
    except OSError:
        pass    # Ignore if pipe doesn't exist

    test_harness.build_program(['send_host_interrupt.S'])

    os.mknod(SEND_PIPE_NAME, stat.S_IFIFO | 0o666)

    args = [test_harness.EMULATOR_PATH,
            '-o', SEND_PIPE_NAME, test_harness.HEX_FILE]
    emulator_process = subprocess.Popen(args, stdout=subprocess.PIPE,
                                        stderr=subprocess.STDOUT)

    try:
        interrupt_pipe = os.open(SEND_PIPE_NAME, os.O_RDONLY | os.O_NONBLOCK)
        test_harness.TimedProcessRunner().communicate(emulator_process, 60)

        # Interrupts should be in pipe now
        interrupts = os.read(interrupt_pipe, 5)
        if interrupts != b'\x05\x06\x07\x08\x09':
            raise test_harness.TestException(
                'Did not receive proper host interrupts')
    finally:
        os.close(interrupt_pipe)
        os.unlink(SEND_PIPE_NAME)

test_harness.execute_tests()
