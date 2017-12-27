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

import os
import subprocess
import sys

sys.path.insert(0, '..')
import test_harness


def run_compiler_test(source_file, target):
    if target == 'host':
        subprocess.check_call(['cc', source_file, '-o', 'obj/a.out'],
                              stderr=subprocess.STDOUT)
        result = subprocess.check_output('obj/a.out')
        test_harness.check_result(source_file, result.decode())
    else:
        test_harness.build_program([source_file])
        result = test_harness.run_program(target)
        test_harness.check_result(source_file, result)

test_list = [fname for fname in test_harness.find_files(
    ('.c', '.cpp')) if not fname.startswith('_')]

all_targets = [fname for fname in test_list if 'noverilator' not in fname]
test_harness.register_tests(run_compiler_test, all_targets, [
                            'emulator', 'verilator', 'host', 'fpga'])

noverilator_targets = [fname for fname in test_list if 'noverilator' in fname]
test_harness.register_tests(
    run_compiler_test, noverilator_targets, ['emulator', 'host', 'fpga'])

test_harness.execute_tests()
