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

import stat
import subprocess
import sys
import time

sys.path.insert(0, '../..')
from test_harness import *


def run_io_interrupt(name):
    underscore = name.rfind('_')
    if underscore == -1:
        raise TestException(
            'Internal error: run_io_interrupt did not have type')

    environment = name[underscore + 1:]
    build_program(['io_interrupt.S'])
    result = run_program(environment=environment)
    lines = result.split('\n')
    output = None

    for x in lines:
        start = x.find('!')
        if start != -1:
            output = x[start + 1:]

    if output is None:
        raise TestException(
            'Could not find output string:\n' + result)

    # Make sure enough interrupts were triggered
    if output.count('*') < 2:
        raise TestException(
            'Not enough interrupts triggered:\n' + result)

    # Make sure we see at least some of the base string printed after an
    # interrupt
    if output.find('*') >= len(output) - 1:
        raise TestException(
            'No instances of interrupt return:\n' + result)

    # Remove all asterisks (interrupts) and make sure string is intact
    stripped = output.replace('*', '')
    if stripped != '0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\]^_`abcdefghijklmnopqrstuvwxyz' * 10:
        raise TestException('Base string does not match:\n' + stripped)

# Test the mechanism for delivering interrupts to the emulator from a
# separate host process (useful for co-emulation)
# XXX A number of error cases do not clean up resources


def run_recv_host_interrupt(name):
    PIPE_NAME = '/tmp/nyuzi_emulator_recvint'
    try:
        os.remove(PIPE_NAME)
    except:
        pass

    build_program(['recv_host_interrupt.S'])

    os.mknod(PIPE_NAME, stat.S_IFIFO | 0666)

    args = [BIN_DIR + 'emulator', '-i', PIPE_NAME, HEX_FILE]
    emulatorProcess = subprocess.Popen(args, stdout=subprocess.PIPE,
                                       stderr=subprocess.STDOUT)

    try:
        interruptPipe = os.open(PIPE_NAME, os.O_WRONLY)

        # Send periodic interrupts to process'
        try:
            for x in range(5):
                os.write(interruptPipe, chr(x))
                time.sleep(0.2)
        except OSError:
            # Broken pipe will occur if the emulator exits early.
            # We'll flag an error after communicate if we don't see a PASS.
            pass

        # Wait for completion
        result, unused_err = TimedProcessRunner().communicate(emulatorProcess, 60)
        if result.find('PASS') == -1 or result.find('FAIL') != -1:
            raise TestException('Test failed ' + result)
    finally:
        os.close(interruptPipe)
        os.unlink(PIPE_NAME)

# XXX A number of error cases do not clean up resources


def run_send_host_interrupt(name):
    PIPE_NAME = '/tmp/nyuzi_emulator_sendint'
    try:
        os.remove(PIPE_NAME)
    except:
        pass

    build_program(['send_host_interrupt.S'])

    os.mknod(PIPE_NAME, stat.S_IFIFO | 0666)

    args = [BIN_DIR + 'emulator', '-o', PIPE_NAME, HEX_FILE]
    emulatorProcess = subprocess.Popen(args, stdout=subprocess.PIPE,
                                       stderr=subprocess.STDOUT)

    try:
        interruptPipe = os.open(PIPE_NAME, os.O_RDONLY | os.O_NONBLOCK)
        result, unused_err = TimedProcessRunner().communicate(emulatorProcess, 60)

        # Interrupts should be in pipe now
        interrupts = os.read(interruptPipe, 5)
        if interrupts != '\x05\x06\x07\x08\x09':
            raise TestException('Did not receive proper host interrupts')
    finally:
        os.close(interruptPipe)
        os.unlink(PIPE_NAME)

register_tests(run_io_interrupt, ['io_interrupt_emulator', 'io_interrupt_verilator'])
register_tests(run_recv_host_interrupt, ['recv_host_interrupt'])
register_tests(run_send_host_interrupt, ['send_host_interrupt'])
register_generic_assembly_tests([
    'setcr_non_super',
    'eret_non_super',
    'dinvalidate_non_super',
    'syscall',
    'inst_align_fault',
    'unaligned_data_fault',
    'multicycle',
    'illegal_instruction'
])

execute_tests()
