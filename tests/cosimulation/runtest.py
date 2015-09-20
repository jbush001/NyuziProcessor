#!/usr/bin/python
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
import re
import os
import filecmp
from os import path

sys.path.insert(0, '..')
import test_harness

if len(sys.argv) > 1:
	files = sys.argv[1:]
else:
	files = [fname for fname in os.listdir('.') if fname.endswith(('.s'))]

VERILATOR_MEM_DUMP='obj/vmem.bin'
EMULATOR_MEM_DUMP='obj/mmem.bin'

verilator_args = [
	'../../bin/verilator_model',
	'+regtrace',
	'+simcycles=2000000',
	'+memdumpfile=' + VERILATOR_MEM_DUMP,
	'+memdumpbase=0',
	'+memdumplen=A0000',
	'+autoflushl2'
]

if 'RANDSEED' in os.environ:
	verilator_args += [ '+randseed=' + os.environ['RANDSEED'] ]

emulator_args = [
	'../../bin/emulator',
	'-m',
	'cosim',
	'-d',
	'obj/mmem.bin,0,0xA0000'
]

if 'EMULATOR_DEBUG_ARGS' in os.environ:
	emulator_args += [ os.environ['EMULATOR_DEBUG_ARGS'] ]

for source_file in files:
	print 'testing ' + source_file,
	hexfile = test_harness.assemble_test(source_file)
	p1 = subprocess.Popen(verilator_args + [ '+bin=' + hexfile ], stdout=subprocess.PIPE)
	p2 = subprocess.Popen(emulator_args + [ hexfile ], stdin=p1.stdout, stdout=subprocess.PIPE)
	p1.stdout.close() # Allow P1 to receive SIGPIPE if p2 exits
	while True:
		got = p2.stdout.read(0x1000)
		if not got:
			break
			
		print got

	if not filecmp.cmp(VERILATOR_MEM_DUMP, EMULATOR_MEM_DUMP, False):
		print "FAIL: simulator final memory contents do not match"
		sys.exit(1)
	else:
		print 'PASS'
