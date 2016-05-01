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
import re
import os
from os import path
import time

sys.path.insert(0, '..')
from test_harness import *


VERILATOR_MEM_DUMP = 'obj/vmem.bin'
EMULATOR_MEM_DUMP = 'obj/mmem.bin'

verilator_args = [
    '../../bin/verilator_model',
    '+trace',
    '+simcycles=2000000',
    '+memdumpfile=' + VERILATOR_MEM_DUMP,
    '+memdumpbase=800000',
    '+memdumplen=400000',
    '+autoflushl2'
]

if 'RANDSEED' in os.environ:
    verilator_args += ['+randseed=' + os.environ['RANDSEED']]

emulator_args = [
    '../../bin/emulator',
    '-m',
    'cosim',
    '-d',
    'obj/mmem.bin,0x800000,0x400000'
]

verbose = 'VERBOSE' in os.environ
if verbose:
    emulator_args += ['-v']


def run_cosimulation_test(source_file):
    global emulator_args
    global verilator_args

    hexfile = build_program([source_file])
    p1 = subprocess.Popen(
        verilator_args + ['+bin=' + hexfile], stdout=subprocess.PIPE)
    p2 = subprocess.Popen(
        emulator_args + [hexfile], stdin=p1.stdout, stdout=subprocess.PIPE)
    output = ''
    while True:
        got = p2.stdout.read(0x1000)
        if not got:
            break

        if verbose:
            print(str(got))
        else:
            output += str(got)

    p2.wait()
    time.sleep(1)  # Give verilator a chance to clean up
    p1.kill() 	# Make sure verilator has exited
    if p2.returncode != 0:
        raise TestException(
            'FAIL: cosimulation mismatch\n' + output)

    assert_files_equal(VERILATOR_MEM_DUMP, EMULATOR_MEM_DUMP,
                       'final memory contents to not match')

register_tests(run_cosimulation_test,
               find_files(('.s', '.S')))

execute_tests()
