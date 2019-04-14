#!/usr/bin/env python3
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

"""Test the test harness.

This ensures the test harness itself works correctly by properly
returning an error when the test program crashes.
"""

import sys

sys.path.insert(0, '..')
import test_harness


@test_harness.test(['emulator', 'verilator'])
def timeout(_, target):
    hex_file = test_harness.build_program(['timeout.c'])
    test_harness.run_program(hex_file, target, timeout=3)


@test_harness.test(['emulator'])
def assemble_error(*unused):
    test_harness.build_program(['assemble_error.s'])


@test_harness.test(['emulator'])
def files_not_equal(*unused):
    test_harness.assert_files_equal('compare_file1', 'compare_file2')


@test_harness.test(['emulator'])
def exception(*unused):
    raise Exception('some exception')


@test_harness.test(['emulator'])
def greater1(*unused):
    test_harness.assert_greater(5, 6)


@test_harness.test(['emulator'])
def greater2(*unused):
    test_harness.assert_greater(5, 5)


@test_harness.test(['emulator'])
def less1(*unused):
    test_harness.assert_less(6, 5)


@test_harness.test(['emulator'])
def less2(*unused):
    test_harness.assert_less(5, 5)


@test_harness.test(['emulator'])
def equal(*unused):
    test_harness.assert_equal(4, 5)


@test_harness.test(['emulator'])
def not_equal(*unused):
    test_harness.assert_not_equal(5, 5)


test_harness.register_generic_test(
    ['crash.c'], ['emulator', 'verilator'])
test_harness.register_generic_test(
    ['check.c', 'checkn.c', 'compile_error.c'], ['emulator'])

test_harness.execute_tests()
