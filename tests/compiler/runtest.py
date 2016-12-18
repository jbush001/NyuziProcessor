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
import subprocess
import sys

sys.path.insert(0, '..')
import test_harness


def run_verilator_test(source_file):
    test_harness.build_program([source_file])
    result = test_harness.run_program(environment='verilator')
    test_harness.check_result(source_file, result)


def run_host_test(source_file):
    subprocess.check_call(['c++', '-w', source_file, '-o', 'obj/a.out'])
    result = subprocess.check_output('obj/a.out')
    test_harness.check_result(source_file, result)


def run_emulator_test(source_file):
    test_harness.build_program([source_file])
    result = test_harness.run_program(environment='emulator')
    test_harness.check_result(source_file, result)

test_list = [fname for fname in test_harness.find_files(
    ('.c', '.cpp')) if not fname.startswith('_')]

if 'USE_VERILATOR' in os.environ:
    test_list = [fname for fname in test_list if 'noverilator' not in fname]
    test_harness.register_tests(run_verilator_test, test_list)
elif 'USE_HOSTCC' in os.environ:
    test_harness.register_tests(run_host_test, test_list)
else:
    test_harness.register_tests(run_emulator_test, test_list)

test_harness.execute_tests()
