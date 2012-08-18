# 
# Copyright 2011-2012 Jeff Bush
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

import random

class TestGroup:
	def __init__(self):
		pass

#
# Return a list of registers, where there are no duplicates in the list.
# e.g. ['r1', 'r7', 'r4']
# Note, this will not use r0
#
def allocateUniqueRegisters(type, numRegisters):
	regs = []
	while len(regs) < numRegisters:
		reg = type + str(random.randint(1, 30))	
		if reg not in regs:
			regs.append(reg)
			
	return regs

#
# Allocate a list of values, where there are no duplicates in the list
#
def allocateUniqueScalarValues(numValues):
	values = []
	while len(values) < numValues:
		value = random.randint(1, 0xffffffff)
		if value not in values:
			values.append(value)
			
	return values

def allocateRandomVectorValue():
	return [ random.randint(1, 0xffffffff) for x in range(16) ]

# Where valuea and valueb are vectors.
def vectorXor(original, valuea, valueb, mask):
	result = []

	for laneo, lanea, laneb in zip(original, valuea, valueb):
		if (mask & 0x8000) != 0:
			result += [ lanea ^ laneb ]
		else:
			result += [ laneo ]

		mask <<= 1

	return result


def makeVectorFromMemory(data, startOffset, stride):
	return [ data[startOffset + x * stride] 
		| (data[startOffset + x * stride + 1] << 8) 
		| (data[startOffset + x * stride + 2] << 16) 
		| (data[startOffset + x * stride + 3] << 24) for x in range(16) ]

def emulateSingleStore(baseOffset, memoryArray, address, value):
	memoryArray[address - baseOffset] = value & 0xff
	memoryArray[address - baseOffset + 1] = (value >> 8) & 0xff
	memoryArray[address - baseOffset + 2] = (value >> 16) & 0xff
	memoryArray[address - baseOffset + 3] = (value >> 24) & 0xff

def emulateVectorStore(baseOffset, memoryArray, address, value, stride, mask,
	invertMask):
	if mask == None:
		useMask = 0xffff
	elif invertMask:
		useMask = ~mask
	else:
		useMask = mask
	
	for lane, laneValue in enumerate(value):
		if (useMask << lane) & 0x8000:
			emulateSingleStore(baseOffset, memoryArray, address + lane * stride, laneValue)

def emulateScatterStore(baseOffset, memoryArray, addressVector, value, offset, mask, invertMask):
	if mask == None:
		useMask = 0xffff
	elif invertMask:
		useMask = ~mask
	else:
		useMask = mask
	
	for lane, (addr, laneValue) in enumerate(zip(addressVector, value)):
		if (useMask << lane) & 0x8000:
			emulateSingleStore(baseOffset, memoryArray, addr +offset, laneValue)

def makeAssemblyArray(data):
	str = ''
	for x in data:
		if str != '':
			str += ', '
			
		str += '0x%x' % x

	return '.byte ' + str
	
def shuffleIndices():
	rawPointers = [ x for x in range(16) ]
	random.shuffle(rawPointers)
	return rawPointers
	