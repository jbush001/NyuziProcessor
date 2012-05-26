#!/usr/bin/python
#
# Generate random instruction sequences and verify processor execution
# matches.
#

import subprocess, tempfile, os, sys, random, struct, inspect, types, re
from types import *
from generate import *
from reference import *

try:
	os.makedirs('WORK/')
except:
	pass

vectorRegPattern = re.compile('(?P<pc>[0-9a-fA-f]+) \[st (?P<strand>\d+)\] v\s?(?P<reg>\d+)\{(?P<mask>[xzXZ0-9a-fA-f]+)\} \<\= (?P<value>[xzXZ0-9a-fA-f]+)')
scalarRegPattern = re.compile('(?P<pc>[0-9a-fA-f]+) \[st (?P<strand>\d+)\] s\s?(?P<reg>\d+) \<\= (?P<value>[xzXZ0-9a-fA-f]+)')

def parseRegisterTraces(lines):
	registerTraces = [ [] for x in range(4) ]
	halted = False
	for line in lines:
		got = vectorRegPattern.match(line)
		if got:
			registerTraces[int(got.group('strand'))] += [ (int(got.group('pc'), 16), int(got.group('reg')), int(got.group('mask'), 16), got.group('value') ) ]
		else:
			got = scalarRegPattern.match(line)
			if got:
				registerTraces[int(got.group('strand'))] += [ (int(got.group('pc'), 16), int(got.group('reg')), got.group('value') ) ]

	return registerTraces

class VerilogSimulatorWrapper:
	def __init__(self):
		self.INTERPRETER_PATH = 'vvp'
		self.VVP_PATH = '../../verilog/sim.vvp'
		self.MEMDUMP_FILE = 'WORK/memory.bin'

	def runTest(self, filename):
		args = [self.INTERPRETER_PATH, self.VVP_PATH, '+bin=' + filename, 
			'+regtrace=1', '+memdumpfile=' + self.MEMDUMP_FILE, '+memdumpbase=0', 
			'+memdumplen=' + str(0x10000), '+simcycles=20000' ]

		if 'VVPTRACE' in os.environ:
			args += ['+trace=trace.vcd']

		try:
			process = subprocess.Popen(args, stdout=subprocess.PIPE)
			output = process.communicate()[0]
		except:
			print 'killing simulator process'
			process.kill()
			raise

		print output
		halted = False
		lines = output.split('\n')
		for line in lines:
			if line.find('***HALTED***') != -1:
				halted = True

		if not halted:
			print 'Simuation did not halt normally'

		return parseRegisterTraces(lines)

class CEmulatorWrapper:
	def __init__(self):
		self.EMULATOR_PATH = '../../tools/emulator/emulator'

	def runTest(self, filename):
		args = [ self.EMULATOR_PATH, filename ]

		try:
			process = subprocess.Popen(args, stdout=subprocess.PIPE)
			output = process.communicate()[0]
		except:
			print 'killing emulator process'
			process.kill()
			raise

		print output
		return parseRegisterTraces(output.split('\n'))

if len(sys.argv) > 1:
	# Run on an existing file
	hexFilename = sys.argv[1]
else:
	# Generate a new random test file
	hexFilename = 'WORK/test.hex'
	Generator().generate(hexFilename)

print "generating reference trace"
model = CEmulatorWrapper()
modeltraces = model.runTest(hexFilename)

print "running simulation"
sim = VerilogSimulatorWrapper()
simtraces = sim.runTest(hexFilename)

print "comparing results"

try:
	for strandid, (modelstrand, simstrand) in enumerate(zip(modeltraces, simtraces)):
		for modeltransfer, simtransfer in zip(modelstrand, simstrand):
			if modeltransfer != simtransfer:
				print 'mismatch, strand', strandid
				print '  model:', modeltransfer
				print '  simulation:', simtransfer
				raise Exception('done')

	print 'PASS'
except:
	pass

# XXX Compare memory