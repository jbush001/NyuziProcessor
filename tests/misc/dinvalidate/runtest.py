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

#!/usr/bin/env python

import subprocess
import sys

subprocess.check_call(['mkdir', '-p', 'WORK'])
subprocess.check_call(['/usr/local/llvm-nyuzi/bin/clang', '-o', 'WORK/test.elf', 'dinvalidate.s'])
subprocess.check_call(['/usr/local/llvm-nyuzi/bin/elf2hex', '-o', 'WORK/test.hex', 'WORK/test.elf'])
result = subprocess.check_output(['../../../bin/verilator_model', '+regtrace=1', '+memdumpfile=WORK/vmem.bin', 
	'+memdumpbase=100', '+memdumplen=4', '+autoflushl2=1', '+bin=WORK/test.hex'])

# 1. Check that the proper value was read into s2
if result.find('02 deadbeef') == -1:
	print 'incorrect value was written back'
	sys.exit(1)

# 2. Read the memory dump to ensure the proper value is flushed from the L2 cache
with open('WORK/vmem.bin', 'rb') as f:
	val = f.read(4)
	if ord(val[0]) != 0xef or ord(val[1]) != 0xbe or ord(val[2]) != 0xad or ord(val[3]) != 0xde:
		print 'memory contents were incorrect'
		sys.exit(1)

print 'PASS'
	

