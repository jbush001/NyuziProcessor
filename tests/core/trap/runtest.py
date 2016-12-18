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

import os
import stat
import subprocess
import sys
import time

sys.path.insert(0, '../..')
import test_harness


@test_harness.test_all_envs
def run_io_interrupt(name):
    underscore = name.rfind('_')
    if underscore == -1:
        raise test_harness.TestException(
            'Internal error: run_io_interrupt did not have type')

    environment = name[underscore + 1:]
    test_harness.build_program(['io_interrupt.S'])
    result = test_harness.run_program(environment=environment)
    lines = result.split('\n')
    output = None

    for line in lines:
        start = line.find('!')
        if start != -1:
            output = line[start + 1:]

    if output is None:
        raise test_harness.TestException(
            'Could not find output string:\n' + result)

    # Make sure enough interrupts were triggered
    if output.count('*') < 2:
        raise test_harness.TestException(
            'Not enough interrupts triggered:\n' + result)

    # Make sure we see at least some of the base string printed after an
    # interrupt
    if output.find('*') >= len(output) - 1:
        raise test_harness.TestException(
            'No instances of interrupt return:\n' + result)

    # Remove all asterisks (interrupts) and make sure string is intact
    stripped = output.replace('*', '')
    if stripped != '0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz' * 10:
        raise test_harness.TestException(
            'Base string does not match:\n' + stripped)

# Test the mechanism for delivering interrupts to the emulator from a
# separate host process (useful for co-emulation)
# XXX A number of error cases do not clean up resources

RECV_PIPE_NAME = '/tmp/nyuzi_emulator_recvint'
SEND_PIPE_NAME = '/tmp/nyuzi_emulator_sendint'


@test_harness.test
def recv_host_interrupt(_):
    try:
        os.remove(RECV_PIPE_NAME)
    except OSError:
        pass    # Ignore if pipe doesn't exist

    test_harness.build_program(['recv_host_interrupt.S'])

    os.mknod(RECV_PIPE_NAME, stat.S_IFIFO | 0o666)

    args = [test_harness.BIN_DIR + 'emulator',
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

# XXX A number of error cases do not clean up resources


@test_harness.test
def send_host_interrupt(_):
    try:
        os.remove(SEND_PIPE_NAME)
    except OSError:
        pass    # Ignore if pipe doesn't exist

    test_harness.build_program(['send_host_interrupt.S'])

    os.mknod(SEND_PIPE_NAME, stat.S_IFIFO | 0o666)

    args = [test_harness.BIN_DIR + 'emulator',
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

test_harness.register_generic_assembly_tests([
    'setcr_non_super',
    'eret_non_super',
    'dinvalidate_non_super',
    'syscall',
    'inst_align_fault',
    'unaligned_data_fault',
    'multicycle',
    'illegal_instruction'
])

test_harness.execute_tests()
