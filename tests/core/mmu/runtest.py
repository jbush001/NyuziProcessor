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
import subprocess

sys.path.insert(0, '../..')
from test_harness import *

# XXX need test to dump memory contents and ensure they are written out
# properly

register_generic_assembly_tests([
    'data_page_fault_read',
    'data_page_fault_write',
    'data_supervisor_fault_read',
    'data_supervisor_fault_write',
    'dflush_tlb_miss',
    'dinvalidate_tlb_miss',
    'dtlb_insert_user',
    'asid',
    'execute_fault',
    'instruction_page_fault',
    'instruction_super_fault',
    'write_fault',
    'tlb_invalidate',
    'tlb_invalidate_all',
    'synonym',
    'duplicate_tlb_insert',
    'itlb_insert_user',
    'io_supervisor_fault_read',
    'io_supervisor_fault_write',
    'io_write_fault',
    'io_map',
    'nested_fault',
    'instruction_translate'
])

execute_tests()
