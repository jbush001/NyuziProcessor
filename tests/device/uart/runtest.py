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

import subprocess
import sys

sys.path.insert(0, '../..')
import test_harness


@test_harness.test(['verilator'])
def uart_hw_test(*unused):
    hex_file = test_harness.build_program(['uart_hw_test.c'])
    result = test_harness.run_program(hex_file, 'verilator')
    if 'PASS' not in result:
        raise test_harness.TestException(
            'test did not indicate pass\n' + result)

@test_harness.test(['emulator'])
def uart_echo_test(*unused):
    """Validate UART transfers  in both directions.

    The emulator direct all UART traffic through the terminal that
    it is launched from.
    """
    executable = test_harness.build_program(['uart_echo_test.c'])

    args = [
        test_harness.EMULATOR_PATH,
        executable
    ]

    in_str = 'THE QUICK brOwn FOX jumPED Over THE LAZY DOG\n'
    process = subprocess.Popen(args, stdin=subprocess.PIPE, stdout=subprocess.PIPE)
    out_str, _ = test_harness.TimedProcessRunner().communicate(process=process,
        timeout=10, input=in_str.encode('ascii'))
    out_str = out_str.decode()
    if 'the quick brown fox jumped over the lazy dog' not in out_str:
        raise test_harness.TestException('Subprocess returned incorrect result \"'
            + out_str + '"')

test_harness.execute_tests()
