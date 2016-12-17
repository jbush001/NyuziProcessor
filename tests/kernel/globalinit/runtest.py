#!/usr/bin/env python
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

sys.path.insert(0, '../..')
from test_harness import *


@test_all_envs
def kernel_globalinit(name):
    underscore = name.rfind('_')
    if underscore == -1:
        raise TestException(
            'Internal error: unknown environment')

    environment = name[underscore + 1:]
    basename = name[0:underscore]

    build_program(['constructor.cpp'], image_type='user')
    result = run_kernel(environment=environment, timeout=120)
    check_result('constructor.cpp', result)

execute_tests()
