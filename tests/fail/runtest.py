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

# The purpose of this test is to ensure the test harness itself works
# correctly by properly returning an error when the test program crashes

import sys
import os

sys.path.insert(0, '..')
from test_harness import *


def emulator_timeout(name):
    build_program(['timeout.c'])
    result = run_program(environment='emulator', timeout=3)


def verilator_timeout(name):
    build_program(['timeout.c'])
    result = run_program(environment='verilator', timeout=3)


def assemble_error(name):
    build_program(['assemble_error.s'])


def files_not_equal(name):
    assert_files_equal('compare_file1', 'compare_file2')


def exception(name):
    raise Exception('some exception')

register_generic_test('crash')
register_generic_test('check')
register_generic_test('checkn')
register_generic_test('compile_error')
register_tests(emulator_timeout, ['timeout_emulator'])
register_tests(assemble_error, ['assemble_error'])
register_tests(verilator_timeout, ['timeout_verilator'])
register_tests(files_not_equal, ['files_not_equal'])
register_tests(exception, ['exception'])
execute_tests()
