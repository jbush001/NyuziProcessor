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
import test_harness

DUMP_FILE='obj/memdump.bin'
EXPECT_STRING='Test String'

def test_alias_verilator(name):
	test_harness.compile_test(['alias.c', 'identity_tlb_miss_handler.s'])
	result = test_harness.run_verilator(dump_file=DUMP_FILE, dump_base=0x100000,
		dump_length=32)
	if result.find('read 00900000 "Test String"') == -1:
		raise test_harness.TestException('did not get correct read string:\n' + result)

	with open(DUMP_FILE, 'r') as f:
		if f.read(len(EXPECT_STRING)) != EXPECT_STRING:
			raise test_harness.TestException('memory contents did not match')

def test_alias_emulator(name):
	test_harness.compile_test(['alias.c', 'identity_tlb_miss_handler.s'])
	result = test_harness.run_emulator(dump_file=DUMP_FILE, dump_base=0x100000,
		dump_length=32)
	if result.find('read 00900000 "Test String"') == -1:
		raise test_harness.TestException('did not get correct read string:\n' + result)

	with open(DUMP_FILE, 'r') as f:
		if f.read(len(EXPECT_STRING)) != EXPECT_STRING:
			raise test_harness.TestException('memory contents did not match')

def test_fill_verilator(name):
	test_harness.compile_test(['fill_test.c', 'wrap_tlb_miss_handler.s'])
	result = test_harness.run_verilator()
	if result.find('FAIL') != -1 or result.find('PASS') == -1:
		raise test_harness.TestException(result + '\ntest did not signal pass')
	
	# XXX check number of DTLB misses to ensure it is above/below thresholds
	
def test_fill_emulator(name):
	test_harness.compile_test(['fill_test.c', 'wrap_tlb_miss_handler.s'])
	result = test_harness.run_emulator()
	if result.find('FAIL') != -1 or result.find('PASS') == -1:
		raise test_harness.TestException(result + '\ntest did not signal pass')

def test_io_map_verilator(name):
	test_harness.compile_test(['io_map.c'])
	result = test_harness.run_verilator(dump_file=DUMP_FILE, dump_base=0x100000,
		dump_length=32)
	
	# Check value printed via virtual serial port
	if result.find('jabberwocky') == -1:
		raise test_harness.TestException('did not get correct read string:\n' + result)

	# Check value written to memory
	with open(DUMP_FILE, 'r') as f:
		if f.read(len('galumphing')) != 'galumphing':
			raise test_harness.TestException('memory contents did not match')
	
def test_io_map_emulator(name):
	test_harness.compile_test(['io_map.c'])
	result = test_harness.run_emulator(dump_file=DUMP_FILE, dump_base=0x100000,
		dump_length=32)
	
	# Check value printed via virtual serial port
	if result.find('jabberwocky') == -1:
		raise test_harness.TestException('did not get correct read string:\n' + result)

	# Check value written to memory
	with open(DUMP_FILE, 'r') as f:
		if f.read(len('galumphing')) != 'galumphing':
			raise test_harness.TestException('memory contents did not match')

def run_generic_test(name):
	if name.endswith('_emulator'):
		basename = name[0:-len('_emulator')]
		isverilator = False
	elif name.endswith('_verilator'):
		basename = name[0:-len('_verilator')]
		isverilator = True
	
	test_harness.compile_test([basename + '.c'])
	if isverilator:
		result = test_harness.run_verilator()
	else:
		result = test_harness.run_emulator()
		
	test_harness.check_result(basename + '.c', result)

def register_generic_test(name):
	test_harness.register_tests(run_generic_test, [name + '_verilator'])
	test_harness.register_tests(run_generic_test, [name + '_emulator'])

test_harness.register_tests(test_alias_verilator, ['alias_verilator'])
test_harness.register_tests(test_alias_emulator, ['alias_emulator'])
test_harness.register_tests(test_fill_verilator, ['fill_verilator'])
test_harness.register_tests(test_fill_emulator, ['fill_emulator'])
test_harness.register_tests(test_io_map_verilator, ['io_map_verilator'])
test_harness.register_tests(test_io_map_emulator, ['io_map_emulator'])
register_generic_test('flush_tlb_miss')
register_generic_test('invalidate_tlb_miss')
register_generic_test('duplicate_entry')
register_generic_test('write_protect')
register_generic_test('data_supervisor')
register_generic_test('instruction_supervisor')
register_generic_test('tlb_invalidate')
test_harness.execute_tests()
