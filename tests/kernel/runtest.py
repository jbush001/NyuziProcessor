#!/usr/bin/env python3
#
# Copyright 2016 Jeff Bush
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

sys.path.insert(0, '../')
import test_harness


def run_kernel_test(source_file, target):
    elf_file = test_harness.build_program([source_file], image_type='user')
    result = test_harness.run_kernel(elf_file, target, timeout=240)
    test_harness.check_result(source_file, result)

test_list = test_harness.find_files(('.c', '.cpp'))
test_harness.register_tests(run_kernel_test, test_list, [
    'emulator', 'verilator', 'fpga'])
test_harness.execute_tests()
