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

showRegs = False

def getLaneFromHexStr(string, lane):
	offset = (15 - lane) * 8
	return string[offset:offset + 8]

def parseRegisterTraces(lines):
	registerTraces = [ [] for x in range(4) ]
	halted = False
	for line in lines:
		got = vectorRegPattern.match(line)
		if got:
			# Make into an array of scalar values
			value = got.group('value')
			vec = [ getLaneFromHexStr(value, lane) for lane in range(16) ]
			registerTraces[int(got.group('strand'))] += [ (int(got.group('pc'), 16), int(got.group('reg')), int(got.group('mask'), 16), vec ) ]
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
			'+memdumplen=' + str(0x10000), '+simcycles=6000' ]

		if 'VVPTRACE' in os.environ:
			args += ['+trace=trace.vcd']

		try:
			process = subprocess.Popen(args, stdout=subprocess.PIPE)
			output = process.communicate()[0]
		except:
			print 'killing simulator process'
			process.kill()
			raise

		if showRegs:
			print output

		return parseRegisterTraces(output.split('\n'))

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

		if showRegs:
			print output

		return parseRegisterTraces(output.split('\n'))

if len(sys.argv) > 1:
	# Run on an existing file
	hexFilename = sys.argv[1]
else:
	# Generate a new random test file
	hexFilename = 'WORK/test.hex'
	Generator().generate(hexFilename)

if 'SHOWREGS' in os.environ:
	showRegs = True


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
			try:
				if len(simtransfer) != len(modeltransfer):
					raise Exception()
	
				if len(modeltransfer) == 4:
					# Vector transfer
					mpc, mreg, mmask, mvalue = modeltransfer
					spc, sreg, smask, svalue = simtransfer
					if mpc != spc or mreg != sreg or mmask != smask:
						raise Exception()
					
					for lane in range(16):
						# Check each lane individually
						if (mmask & (1 << (15 - lane))) != 0:
							if mvalue[lane] != svalue[lane]:
								print 'mismatch lane', lane
								raise Exception()
				else:
					# Scalar transfer
					if modeltransfer != simtransfer:
						raise Exception()
			except:
				print 'mismatch, strand', strandid
				print '  model @', hex(modeltransfer[0]), modeltransfer[1:]
				print '  simulation @', hex(simtransfer[0]), simtransfer[1:]
				raise

		# If there are left over events, bail now
		if len(modelstrand) != len(simstrand):
			print 'number of events does not match, strand ', strandid, len(modelstrand), len(simstrand)
			raise Exception()

	print 'PASS'
except:
	pass

# XXX Compare memory