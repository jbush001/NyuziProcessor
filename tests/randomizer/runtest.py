#!/usr/bin/python
#
# Generate random instruction sequences and verify processor execution
# matches.
#

import subprocess, tempfile, os, sys, random, struct, inspect, types, re
from types import *
from generate import *

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
			elif line.find('ASSERTION FAILED') != -1:
				raise Exception(line)

	return registerTraces

class VerilogSimulatorWrapper:
	def __init__(self):
		self.INTERPRETER_PATH = 'vvp'
		self.VVP_PATH = '../../verilog/sim.vvp'

	def runTest(self, filename, dumpfile):
		args = [self.INTERPRETER_PATH, self.VVP_PATH, '+bin=' + filename, 
			'+regtrace=1', '+memdumpfile=' + dumpfile, '+memdumpbase=0', 
			'+memdumplen=A0000', '+simcycles=80000', '+autoflushl2=1' ]

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

	def runTest(self, filename, dumpfile):
		args = [ self.EMULATOR_PATH, '-d', dumpfile + ',0,A0000', filename ]

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

# A, B, C, D, (e is remainder)
profiles = [
	[ 0, 0, 100, 0 ],		# Only memory accesses
	[ 30, 30, 30, 5 ],		# More general purpose (5% branches)
	[ 35, 35, 30, 0 ],	# No branches
	[ 50, 0, 0, 0 ]		# Branches and register operations
]

if len(sys.argv) > 1:
	# Run on an existing file
	hexFilename = sys.argv[1]
else:
	# Generate a new random test file
	hexFilename = 'WORK/test.hex'
	profileIndex = random.randint(0, 3)
	print 'using profile', profileIndex
	Generator(profiles[profileIndex]).generate(hexFilename)

if 'SHOWREGS' in os.environ:
	showRegs = True

SIMULATOR_MEM_DUMP = 'WORK/sim-memory.bin'
REFERENCE_MEM_DUMP = 'WORK/reference-memory.bin'

print "generating reference trace"
reference = CEmulatorWrapper()
referencetraces = reference.runTest(hexFilename, REFERENCE_MEM_DUMP)

print "running simulation"
sim = VerilogSimulatorWrapper()
simtraces = sim.runTest(hexFilename, SIMULATOR_MEM_DUMP)

print "comparing results"

try:
	for strandid, (referencestrand, simstrand) in enumerate(zip(referencetraces, simtraces)):
		for referencetransfer, simtransfer in zip(referencestrand, simstrand):
			try:
				if len(simtransfer) != len(referencetransfer):
					raise Exception()
	
				if len(referencetransfer) == 4:
					# Vector transfer
					mpc, mreg, mmask, mvalue = referencetransfer
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
					if referencetransfer != simtransfer:
						raise Exception()
			except:
				print 'mismatch, strand', strandid
				print '  reference @', hex(referencetransfer[0]), referencetransfer[1:]
				print '  simulation @', hex(simtransfer[0]), simtransfer[1:]
				raise

		# If there are left over events, bail now
		if len(referencestrand) != len(simstrand):
			print 'number of events does not match, strand ', strandid, len(referencestrand), len(simstrand)
			raise Exception()


	f1 = open(REFERENCE_MEM_DUMP)
	f2 = open(SIMULATOR_MEM_DUMP)
	
	offset = 0
	while True:
		b1 = f1.read(1)
		b2 = f2.read(1)
		if b1 == '':
			if b2 != '':
				print 'length mismatch'
				raise Exception()
	
			break
			
		if b1 != b2:
			print 'mismatch @', hex(offset), 'reference', ord(b1), 'sim', ord(b2)
			raise Exception()
			
		offset += 1
	
	f1.close()
	f2.close()

	print 'PASS'
except:
	pass


