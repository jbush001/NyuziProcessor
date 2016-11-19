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
        self.elf_file = os.path.splitext(hexfile)[0]+'.elf'

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
            print('SEND: ' + cmd)

        self.outstr.write(cmd + '\n')
        return self.wait_response()

    def wait_response(self):
        response = ''
        while True:
            response += self.instr.read(1)
            if response.endswith('^done'):
                break

        if DEBUG:
            print('RECV: ' + response)

        return response

def test_breakpoint(name):
    hexfile = build_program(['test_program.c'], opt_level='-O0', cflags=['-g'])
    with LLDBHarness(hexfile) as lldb:
        lldb.send_command('file "obj/test.elf"')
        lldb.send_command('gdb-remote 8000\n')
        response = lldb.send_command('breakpoint set --file test_program.c --line 7')
        if response.find('Breakpoint 1: where = test.elf`sub_func + 20 at test_program.c:7') == -1:
            raise TestException('Did not find expected value ' + response)

        lldb.send_command('c')

        # XXX why is this required?
        lldb.send_command('process interrupt')

        response = lldb.send_command('print a')
        if response.find('= 12') == -1:
            raise TestException('Did not find expected value ' + response)

        response = lldb.send_command('print b')
        if response.find('= 7') == -1:
            raise TestException('Did not find expected value ' + response)


register_tests(test_breakpoint, ['lldb_breakpoint'])
execute_tests()
