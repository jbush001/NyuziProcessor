#!/usr/bin/env python3
#
# Copyright 2018 Jeff Bush
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

sys.path.insert(0, '..')
import test_harness

def test_emulator_error(filename, expected_error):
    args = [test_harness.EMULATOR_PATH, filename]
    try:
        result = subprocess.check_output(args, stderr=subprocess.STDOUT)
        raise test_harness.TestException('emulator did not detect error')
    except subprocess.CalledProcessError as exc:
        result = exc.output.decode().strip()
        if not result.startswith(expected_error):
            raise test_harness.TestException('error string did not match, wanted \"{}\", got \"{}\"'
                .format(expected_error, result))

@test_harness.test(['emulator'])
def out_of_range_hexfile1(filename, _):
    '''Constant is larger than 32 bits. strtoul is successful, but the loader flags an error.'''
    test_emulator_error('out_of_range1', 'Invalid constant in hex file at line 2')

@test_harness.test(['emulator'])
def out_of_range_hexfile2(filename, _):
    '''Constant is larger than 64 bits. strtoul  returns ERANGE'''
    test_emulator_error('out_of_range2', 'Invalid constant in hex file at line 5')

@test_harness.test(['emulator'])
def bad_character(filename, _):
    '''Checks when entire line is not consumed by strtoul'''
    error = test_emulator_error('bad_character', 'Invalid constant in hex file at line 4')

@test_harness.test(['emulator'])
def missing_file(filename, _):
    test_emulator_error('this_file_does_not_exist.hex', 'load_hex_file: error opening hex file: No such file or directory')

test_harness.execute_tests()
