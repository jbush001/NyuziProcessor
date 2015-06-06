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

subprocess.check_call(['mkdir', '-p', 'WORK'])
subprocess.check_call(['/usr/local/llvm-nyuzi/bin/clang', '-o', 'WORK/test.elf', 'atomic.c', '../../../software/libs/libc/crt0.o'])
subprocess.check_call(['/usr/local/llvm-nyuzi/bin/elf2hex', '-o', 'WORK/test.hex', 'WORK/test.elf'])
subprocess.check_call(['../../../bin/verilator_model', '+memdumpfile=WORK/vmem.bin', 
	'+memdumpbase=100000', '+memdumplen=800', '+autoflushl2=1', '+bin=WORK/test.hex'])

with open('WORK/vmem.bin', 'rb') as f:
	while True:
		val = f.read(4)
		if val == '':
			break
		
		numVal = ord(val[0]) | (ord(val[1]) << 8) | (ord(val[2]) << 16) | (ord(val[3]) << 24)
		if numVal != 10:
			print 'FAIL: mismatch: ', numVal
			sys.exit(1)

print 'PASS'	
