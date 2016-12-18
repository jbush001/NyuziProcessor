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

"""
The purpose of this test is to ensure the test harness itself works
correctly by properly returning an error when the test program crashes
"""

import sys

sys.path.insert(0, '..')
import test_harness


@test_harness.test
def emulator_timeout(_):
    test_harness.build_program(['timeout.c'])
    test_harness.run_program(environment='emulator', timeout=3)


@test_harness.test
def verilator_timeout(_):
    test_harness.build_program(['timeout.c'])
    test_harness.run_program(environment='verilator', timeout=3)


@test_harness.test
def assemble_error(_):
    test_harness.build_program(['assemble_error.s'])


@test_harness.test
def files_not_equal(_):
    test_harness.assert_files_equal('compare_file1', 'compare_file2')


@test_harness.test
def exception(_):
    raise Exception('some exception')

test_harness.register_generic_test('crash')
test_harness.register_generic_test('check')
test_harness.register_generic_test('checkn')
test_harness.register_generic_test('compile_error')
test_harness.execute_tests()
