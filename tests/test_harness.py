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
# Utility functions for unit tests
#

import subprocess
import os
import sys
import re
import traceback

COMPILER_DIR = '/usr/local/llvm-nyuzi/bin/'
PROJECT_TOP = os.path.normpath(os.path.dirname(os.path.abspath(__file__)) + '/../')
LIB_DIR = PROJECT_TOP + '/software/libs/'
BIN_DIR = PROJECT_TOP + '/bin/'
OBJ_DIR = 'obj/'
ELF_FILE = OBJ_DIR + 'test.elf'
HEX_FILE = OBJ_DIR + 'test.hex'


class TestException:
	def __init__(self, output):
		self.output = output


def compile_test(source_file, optlevel='3'):
	"""Compile one or more files and write the executable as test.hex.
	
	source_file can be a single file or list of files. This will link in crt0.o,
	libc, and libos."""

	if not os.path.exists(OBJ_DIR):
		os.makedirs(OBJ_DIR)

	compiler_args = [COMPILER_DIR + 'clang', 
		'-o', ELF_FILE, 
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
	"""Assemble a file and write the executable as test.hex. 
	
	The file is expected to be standalone; other libraries will not be linked"""
	
	if not os.path.exists(OBJ_DIR):
		os.makedirs(OBJ_DIR)

	try:
		subprocess.check_output([COMPILER_DIR + 'clang', '-o', ELF_FILE, source_file])
		subprocess.check_output([COMPILER_DIR + 'elf2hex', '-o', HEX_FILE, ELF_FILE])
	except subprocess.CalledProcessError as exc:
		raise TestException('Assembly failed:\n' + exc.output)

	return HEX_FILE
	
def run_emulator(block_device=None, dump_file=None, dump_base=None, dump_length=None):
	"""Run test program in emulator and return output printed to virtual serial
	device. 
	
	This uses the hex file produced by assemble_test or compile_test."""
	
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


def run_verilator(block_device=None, dump_file=None, dump_base=None, 
	dump_length=None, extra_args=None):
	"""Run test program in Verilog simulator and return output printed to virtual
	serial device.

	This uses the hex file produced by assemble_test or compile_test."""

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
	"""Read two files and throw a TestException if they are not the same"""
	
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
	"""Add a list of tests to be run when execute_tests is called. 
	
	This function can be called multiple times. func is the function that will
	be called for each element in the 'params' list, which is a list of test 
	names"""
	
	global registered_tests
	registered_tests += [(func, param) for param in params]


def find_files(extensions):
	return [fname for fname in os.listdir('.') if fname.endswith(extensions)]


def execute_tests():
	"""Run all tests that have been registered with the register_tests functions
	and report results"""
	
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
			failing_tests += [(param, 'Caught exception ' + traceback.format_exc())]

	if failing_tests:
		print 'Failing tests:'
		for name, output in failing_tests:
			print name
			print output

	print str(len(failing_tests)) + '/' + str(len(registered_tests)) + ' tests failed'
	if failing_tests != []:
		sys.exit(1)

def check_result(source_file, program_output):
	"""Check output of a program based on embedded comments in source code.
	
	For each pattern in source_file that begins with 'CHECK:', search
	to see if the regular expression that follows it occurs in program_output. 
	The strings must occur in order, but this ignores any other output between
	them."""
	
	PREFIX = 'CHECK: '

	output_offset = 0
	lineNo = 1
	foundCheckLines = False
	with open(source_file, 'r') as f:
		for line in f:
			chkoffs = line.find(PREFIX)
			if chkoffs != -1:
				foundCheckLines = True
				expected = line[chkoffs + len(PREFIX):].strip()
				regexp = re.compile(expected)
				got = regexp.search(program_output, output_offset)
				if got:
					output_offset = got.end()
				else:
					error = 'FAIL: line ' + str(lineNo) + ' expected string ' + expected + ' was not found\n'
					error += 'searching here:' + program_output[output_offset:]
					raise TestException(error)

			lineNo += 1

	if not foundCheckLines:
		raise TestException('FAIL: no lines with CHECK: were found')
		
	return True
