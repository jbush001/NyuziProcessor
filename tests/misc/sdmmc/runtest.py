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

import subprocess
import sys
import filecmp
import os

sys.path.insert(0, '../..')
import test_harness

FILE_SIZE = 8192
SOURCE_BLOCK_DEV = 'obj/bdevimage.bin'
EMULATOR_OUTPUT='obj/emumem.bin'
VERILATOR_OUTPUT='obj/verimem.bin'

hexfile = test_harness.compile_test('sdmmc.c')

# Create random file
with open(SOURCE_BLOCK_DEV, 'wb') as f:
	f.write(os.urandom(FILE_SIZE))

print 'testing in emulator'
subprocess.check_call(['../../../bin/emulator', '-b', SOURCE_BLOCK_DEV, '-d', EMULATOR_OUTPUT + ',0x200000,' 
	+ hex(FILE_SIZE), hexfile])
if not filecmp.cmp(SOURCE_BLOCK_DEV, EMULATOR_OUTPUT, False):
	print "FAIL: simulator final memory contents do not match"
	sys.exit(1)

print 'testing in verilator'
subprocess.check_call(['../../../bin/verilator_model', '+block=' + SOURCE_BLOCK_DEV, '+autoflushl2=1', 
	'+memdumpfile=' + VERILATOR_OUTPUT, '+memdumpbase=200000',  '+memdumplen=' + hex(FILE_SIZE)[2:], 
	'+bin=' + hexfile])
if not filecmp.cmp(SOURCE_BLOCK_DEV, VERILATOR_OUTPUT, False):
	print "FAIL: verilator final memory contents do not match"
	sys.exit(1)



