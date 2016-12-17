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

import re
import sys
import subprocess
import os
import time

sys.path.insert(0, '..')
from test_harness import *

DEBUG = False


class LLDBHarness:

    def __init__(self, hexfile):
        self.hexfile = hexfile
        self.elf_file = os.path.splitext(hexfile)[0] + '.elf'

    def __enter__(self):
        global DEBUG

        emulator_args = [
            BIN_DIR + 'emulator',
            '-m',
            'gdb',
            '-v',
            self.hexfile
        ]

        if DEBUG:
            self.output = None
        else:
            self.output = open(os.devnull, 'w')

        self.emulator_proc = subprocess.Popen(emulator_args, stdout=self.output,
                                              stderr=subprocess.STDOUT)

        lldb_args = [
            COMPILER_DIR + 'lldb-mi'
        ]

        # XXX race condition: the emulator needs to be ready before
        # lldb tries to connect to it.

        try:
            self.lldb_proc = subprocess.Popen(lldb_args, stdout=subprocess.PIPE,
                                              stdin=subprocess.PIPE)
            self.outstr = self.lldb_proc.stdin
            self.instr = self.lldb_proc.stdout
        except:
            self.emulator_proc.kill()
            raise

        return self

    def __exit__(self, type, value, traceback):
        self.emulator_proc.kill()
        self.lldb_proc.kill()

    def send_command(self, cmd):
        if DEBUG:
            print('LLDB send: ' + cmd)

        self.outstr.write(cmd + '\n')
        return self.wait_response()

    def wait_response(self):
        response = ''
        while True:
            response += self.instr.read(1)
            if response.endswith('^done'):
                break

        if DEBUG:
            print('LLDB recv: ' + response)

        return response

    def wait_stop(self):
        current_line = ''
        while True:
            ch = self.instr.read(1)
            current_line += ch
            if ch == '\n':
                if DEBUG:
                    print('LLDB recv: ' + current_line[:-1])

                if current_line.startswith('*stopped'):
                    break

                current_line = ''

frame_re = re.compile(
    'frame #[0-9]+:( 0x[0-9a-f]+)? [a-zA-Z_\.0-9]+`(?P<function>[a-zA-Z_0-9][a-zA-Z_0-9]+)')
at_re = re.compile(' at (?P<filename>[a-z_A-Z][a-z\._A-Z]+):(?P<line>[0-9]+)')


def parse_stack_crawl(response):
    lines = response.split('\n')
    stack_info = []
    for line in lines:
        frame_match = frame_re.search(line)
        if frame_match:
            func = frame_match.group('function')
            at_match = at_re.search(line)
            if at_match:
                stack_info += [(func, at_match.group('filename'),
                                int(at_match.group('line')))]
            else:
                stack_info += [(func, '', 0)]

    return stack_info


def test_lldb(name):
    hexfile = build_program(['test_program.c'], opt_level='-O0', cflags=['-g'])
    with LLDBHarness(hexfile) as lldb:
        lldb.send_command('file "obj/test.elf"')
        lldb.send_command('gdb-remote 8000\n')
        response = lldb.send_command(
            'breakpoint set --file test_program.c --line 27')
        if 'Breakpoint 1: where = test.elf`func2 + 96 at test_program.c:27' not in response:
            raise TestException(
                'breakpoint: did not find expected value ' + response)

        lldb.send_command('c')
        lldb.wait_stop()

        expected_stack = [
            ('func2', 'test_program.c', 27),
            ('func1', 'test_program.c', 35),
            ('main', 'test_program.c', 41),
            ('do_main', '', 0)
        ]

        response = lldb.send_command('bt')
        crawl = parse_stack_crawl(response)
        if crawl != expected_stack:
            raise TestException('stack crawl mismatch ' + str(crawl))

        response = lldb.send_command('print value')
        if '= 67' not in response:
            raise TestException(
                'print value: Did not find expected value ' + response)

        response = lldb.send_command('print result')
        if '= 128' not in response:
            raise TestException(
                'print result: Did not find expected value ' + response)

        # Up to previous frame
        lldb.send_command('frame select --relative=1')

        response = lldb.send_command('print a')
        if '= 12' not in response:
            raise TestException(
                'print a: Did not find expected value ' + response)

        response = lldb.send_command('print b')
        if '= 67' not in response:
            raise TestException(
                'print b: Did not find expected value ' + response)

        lldb.send_command('step')
        lldb.wait_stop()

        response = lldb.send_command('print result')
        if '= 64' not in response:
            raise TestException(
                'print b: Did not find expected value ' + response)


register_tests(test_lldb, ['lldb'])
execute_tests()
