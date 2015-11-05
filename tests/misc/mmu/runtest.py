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

def test_tlb_miss_verilator(name):
	test_harness.compile_test(['tlb_miss.c', 'identity_tlb_miss_handler.s'])
	result = test_harness.run_verilator(dump_file=DUMP_FILE, dump_base=0x100000,
		dump_length=32)
	if result.find('read 00900000 "Test String"') == -1:
		raise test_harness.TestException('did not get correct read string:\n' + result)

	with open(DUMP_FILE, 'r') as f:
		if f.read(len(EXPECT_STRING)) != EXPECT_STRING:
			raise test_harness.TestException('memory contents did not match')

def test_tlb_miss_emulator(name):
	test_harness.compile_test(['tlb_miss.c', 'identity_tlb_miss_handler.s'])
	result = test_harness.run_emulator(dump_file=DUMP_FILE, dump_base=0x100000,
		dump_length=32)
	if result.find('read 00900000 "Test String"') == -1:
		raise test_harness.TestException('did not get correct read string:\n' + result)

	with open(DUMP_FILE, 'r') as f:
		if f.read(len(EXPECT_STRING)) != EXPECT_STRING:
			raise test_harness.TestException('memory contents did not match')

def test_tlb_invalidate_verilator(name):
	test_harness.compile_test(['invalidate.c'])
	result = test_harness.run_verilator()
	test_harness.check_result('invalidate.c', result)
	
def test_tlb_invalidate_emulator(name):
	test_harness.compile_test(['invalidate.c'])
	result = test_harness.run_emulator()
	test_harness.check_result('invalidate.c', result)

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

def test_duplicate_entry_verilator(name):
	test_harness.compile_test(['duplicate_entry.c'])
	result = test_harness.run_verilator()
	test_harness.check_result('duplicate_entry.c', result)
	
def test_duplicate_entry_emulator(name):
	test_harness.compile_test(['duplicate_entry.c'])
	result = test_harness.run_emulator()
	test_harness.check_result('duplicate_entry.c', result)

def test_write_protect_verilator(name):
	test_harness.compile_test(['write_protect.c'])
	result = test_harness.run_verilator()
	test_harness.check_result('write_protect.c', result)
	
def test_write_protect_emulator(name):
	test_harness.compile_test(['write_protect.c'])
	result = test_harness.run_emulator()
	test_harness.check_result('write_protect.c', result)

test_harness.register_tests(test_tlb_miss_verilator, ['tlb_miss_verilator'])
test_harness.register_tests(test_tlb_miss_emulator, ['tlb_miss_emulator'])
test_harness.register_tests(test_tlb_invalidate_verilator, ['tlb_invalidate_verilator'])
test_harness.register_tests(test_tlb_invalidate_emulator, ['tlb_invalidate_emulator'])
test_harness.register_tests(test_fill_verilator, ['fill_verilator'])
test_harness.register_tests(test_fill_emulator, ['fill_emulator'])
test_harness.register_tests(test_io_map_verilator, ['io_map_verilator'])
test_harness.register_tests(test_io_map_emulator, ['io_map_emulator'])
test_harness.register_tests(test_duplicate_entry_verilator, ['duplicate_entry_verilator'])
test_harness.register_tests(test_duplicate_entry_emulator, ['duplicate_entry_emulator'])
test_harness.register_tests(test_write_protect_verilator, ['write_protect_verilator'])
test_harness.register_tests(test_write_protect_emulator, ['write_protect_emulator'])

test_harness.execute_tests()
