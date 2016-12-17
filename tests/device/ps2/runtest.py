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

# Test PS/2 keyboard peripheral

sys.path.insert(0, '../..')
from test_harness import *


def ps2_test(name):
    build_program(['ps2.c'])
    result = run_program(environment='verilator')
    if 'PASS' not in result:
        raise TestException(
            'program did not indicate pass\n' + result)

register_tests(ps2_test, ['ps2'])
execute_tests()
