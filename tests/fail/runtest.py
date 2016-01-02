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
import test_harness


def emulator_timeout(name):
    test_harness.compile_test('timeout.c')
    result = test_harness.run_emulator(timeout=3)


def verilator_timeout(name):
    test_harness.compile_test('timeout.c')
    result = test_harness.run_verilator(timeout=3)

test_harness.register_generic_test('crash')
test_harness.register_generic_test('check')
test_harness.register_generic_test('checkn')
test_harness.register_tests(emulator_timeout, ['timeout_emulator'])
test_harness.register_tests(verilator_timeout, ['timeout_verilator'])
test_harness.execute_tests()
