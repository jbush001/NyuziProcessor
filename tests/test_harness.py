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
import os
import sys

COMPILER_DIR = '/usr/local/llvm-nyuzi/bin/'
BASE_DIR = os.path.normpath(os.path.dirname(os.path.abspath(__file__)) + '/../')
LIB_DIR = BASE_DIR + '/software/libs/'
BIN_DIR = BASE_DIR + '/bin/'
OBJ_DIR = 'obj/'
ELF_FILE = OBJ_DIR + 'test.elf'
HEX_FILE = OBJ_DIR + 'test.hex'


class TestException:
	def __init__(self, output):
		self.output = output


def compile_test(source_file, optlevel='3'):
	if not os.path.exists(OBJ_DIR):
		os.makedirs(OBJ_DIR)

	compiler_args = [COMPILER_DIR + 'clang', '-o', ELF_FILE, 
		'-w',
		'-O' + optlevel,
		'-I' + LIB_DIR + 'libc/include',
		'-I' + LIB_DIR + 'libos']
	
	if isinstance(source_file, list):
		compiler_args += source_file		# List of files
	else:
		compiler_args += [source_file]	# Single file

	compiler_args += [LIB_DIR + 'libc/crt0.o',
		LIB_DIR + 'libc/libc.a',
		LIB_DIR + 'libos/libos.a']

	try:
		subprocess.check_output(compiler_args, stderr=subprocess.STDOUT)
		subprocess.check_output([COMPILER_DIR + 'elf2hex', '-o', HEX_FILE, ELF_FILE],
			stderr=subprocess.STDOUT)
	except subprocess.CalledProcessError as exc:
		raise TestException('Compilation failed:\n' + exc.output)
	
	return HEX_FILE
	
def assemble_test(source_file):
	if not os.path.exists(OBJ_DIR):
		os.makedirs(OBJ_DIR)

	try:
		subprocess.check_output([COMPILER_DIR + 'clang', '-o', ELF_FILE, source_file])
		subprocess.check_output([COMPILER_DIR + 'elf2hex', '-o', HEX_FILE, ELF_FILE])
	except subprocess.CalledProcessError as exc:
		raise TestException('Assembly failed:\n' + exc.output)

	return HEX_FILE
	
def run_emulator(block_device=None, dump_file=None, dump_base=None, dump_length=None):
	args = [BIN_DIR + 'emulator']
	if block_device:
		args += ['-b', block_device]

	if dump_file:
		args += ['-d', dump_file + ',' + hex(dump_base) + ',' + hex(dump_length)]

	args += [HEX_FILE]

	try:
		output = subprocess.check_output(args)
	except subprocess.CalledProcessError as exc:
		raise TestException('Emulator returned error: ' + exc.output)
	
	return output


def run_verilator(block_device=None, dump_file=None, dump_base=None, dump_length=None, extra_args=None):
	args = [BIN_DIR + 'verilator_model']
	if block_device:
		args += ['+block=' + block_device]
		
	if dump_file:
		args += ['+memdumpfile=' + dump_file, '+memdumpbase=' + hex(dump_base)[2:], 
			'+memdumplen=' + hex(dump_length)[2:]]

	if extra_args:
		args += extra_args

	args += ['+bin=' + HEX_FILE]
	try:
		output = subprocess.check_output(args)
	except subprocess.CalledProcessError as exc:
		raise TestException('Verilator returned error: ' + exc.output)

	if output.find('***HALTED***') == -1:
		raise TestException(output + '\nProgram did not halt normally')
	
	return output


def assert_files_equal(file1, file2, error_msg=''):
	len1 = os.stat(file1).st_size
	len2 = os.stat(file2).st_size
	if len1 != len2:
		raise TestException('file mismatch: different lengths')

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
						exception_text = error_msg + ':\n'
						rounded_offset = i & ~15
						exception_text += '%08x' % (block_offset + rounded_offset),
						for x in range(16):
							exception_text += '%02x' % ord(block1[rounded_offset + x]),

						exception_text += '\n%08x' % (block_offset + rounded_offset),
						for x in range(16):
							exception_text += '%02x' % ord(block2[rounded_offset + x]),

						exception_text += '\n        ',
						for x in range(16):
							if block1[rounded_offset + x] != block2[rounded_offset + x]:
								exception_text += '^^',
							else:
								exception_text += '  ',

						raise TestException(exception_text)

			if not block1:
				return

			block_offset += BUFSIZE


registered_tests = []


def register_tests(func, params):
	global registered_tests
	registered_tests += [(func, param) for param in params]


def find_files(extensions):
	return [fname for fname in os.listdir('.') if fname.endswith(extensions)]


def execute_tests():
	global registered_tests

	if len(sys.argv) > 1:
		# Filter test list based on command line requests
		new_test_list = []
		for requested in sys.argv[1:]:
			for func, param in registered_tests:
				if param == requested:
					new_test_list += [(func, param)]
					break
			else:
				print 'Unknown test', requested
				sys.exit(1)
				
		registered_tests = new_test_list

	ALIGN = 30
	failing_tests = []
	for func, param in registered_tests:
		print param + (' ' * (ALIGN - len(param))),
		try:
			func(param)
			print '[\x1b[32mPASS\x1b[0m]'
		except KeyboardInterrupt:
			sys.exit(1)
		except TestException as exc:
			print '[\x1b[31mFAIL\x1b[0m]'
			failing_tests += [(param, exc.output)]
		except Exception as exc:
			print '[\x1b[31mFAIL\x1b[0m]'
			failing_tests += [(param, 'Caught exception ' + str(exc))]

	if failing_tests:
		print 'Failing tests:'
		for name, output in failing_tests:
			print name
			print output

	print str(len(failing_tests)) + '/' + str(len(registered_tests)) + ' tests failed'
	if failing_tests != []:
		sys.exit(1)
