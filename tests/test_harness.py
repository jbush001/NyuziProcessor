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

#
# Common utilities for tests
#

import subprocess
import os

COMPILER_DIR='/usr/local/llvm-nyuzi/bin/'
OUTPUT_FILE='obj/test.hex'
LIB_DIR=os.path.dirname(os.path.abspath(__file__)) + '/../software/libs/'

def compile_test(source_file, optlevel='3'):
	subprocess.check_call(['mkdir', '-p', 'obj'])
	subprocess.check_call([COMPILER_DIR + 'clang', '-o', 'obj/test.elf', 
		'-w',
		'-O' + optlevel,
		source_file, 
		LIB_DIR + 'libc/crt0.o',
		LIB_DIR + 'libc/libc.a',
		LIB_DIR + 'libos/libos.a',
		'-I' + LIB_DIR + 'libc/include',
		'-I' + LIB_DIR + 'libos'])
	subprocess.check_call([COMPILER_DIR + 'elf2hex', '-o', OUTPUT_FILE, 'obj/test.elf'])
	return OUTPUT_FILE
	
def assemble_test(source_file):
	subprocess.check_call(['mkdir', '-p', 'obj'])
	subprocess.check_call([COMPILER_DIR + 'clang', '-o', 'obj/test.elf', source_file])
	subprocess.check_call([COMPILER_DIR + 'elf2hex', '-o', OUTPUT_FILE, 'obj/test.elf'])
	return OUTPUT_FILE
	
