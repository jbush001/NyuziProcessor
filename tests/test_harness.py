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
BASE_DIR=os.path.normpath(os.path.dirname(os.path.abspath(__file__)) + '/../')
LIB_DIR=BASE_DIR+'/software/libs/'
BIN_DIR=BASE_DIR+'/bin/'

HEX_FILE='obj/test.hex'

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
	subprocess.check_call([COMPILER_DIR + 'elf2hex', '-o', HEX_FILE, 'obj/test.elf'])
	return HEX_FILE
	
def assemble_test(source_file):
	subprocess.check_call(['mkdir', '-p', 'obj'])
	subprocess.check_call([COMPILER_DIR + 'clang', '-o', 'obj/test.elf', source_file])
	subprocess.check_call([COMPILER_DIR + 'elf2hex', '-o', HEX_FILE, 'obj/test.elf'])
	return HEX_FILE
	
def run_emulator(block_device=None, dump_file=None, dump_base=None, dump_length=None):
	args = [BIN_DIR + 'emulator']
	if block_device:
		args += ['-b', block_device]

	if dump_file:
		args += [ '-d', dump_file + ',' + hex(dump_base) + ',' + hex(dump_length) ]

	args += [ HEX_FILE ]
	
	return subprocess.check_output(args)
	
def run_verilator(block_device=None, dump_file=None, dump_base=None, dump_length=None, extra_args=None):
	args = [BIN_DIR + 'verilator_model']
	if block_device:
		args += [ '+block=' + block_device ]
		
	if dump_file:
		args += ['+memdumpfile=' + dump_file, '+memdumpbase=' + hex(dump_base)[2:], 
			'+memdumplen=' + hex(dump_length)[2:]]

	if extra_args:
		args += extra_args

	args += ['+bin=' + HEX_FILE]
	return subprocess.check_output(args)
	
def assert_files_equal(file1, file2):
	len1 = os.stat(file1).st_size
	len2 = os.stat(file2).st_size
	if len1 != len2:
		print 'file mismatch: different lengths', file1, len1, file2, len2
		return False

	BUFSIZE = 0x1000
	block_offset = 0
	with open(file1, 'rb') as fp1, open(file2, 'rb') as fp2:
		while True:
			block1 = fp1.read(BUFSIZE)
			block2 = fp2.read(BUFSIZE)
			if block1 != block2:
				for i in range(len(block1)):
					if block1[i] != block2[i]:
						# Show the difference
						print 'files differ:'
						rounded_offset = i & ~15
						print '%08x' % (block_offset + rounded_offset),
						for x in range(16):
							print '%02x' % ord(block1[rounded_offset + x]),

						print '\n%08x' % (block_offset + rounded_offset),
						for x in range(16):
							print '%02x' % ord(block2[rounded_offset + x]),

						print '\n        ',
						for x in range(16):
							if block1[rounded_offset + x] != block2[rounded_offset + x]:
								print '^^',
							else:
								print '  ',

						return False

			if not block1:
				return True

			block_offset += BUFSIZE

