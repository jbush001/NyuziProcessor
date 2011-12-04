#!/usr/bin/python

# Translate to intel hex format
import sys, getopt

MAX_LINE_LENGTH = 16

def generateHexLine(address, data, width):
	line = ':%02x%04x00' % (len(data) * width, address)
	checksum = len(data) * width
	checksum += ((address >> 8) & 0xff) + (address & 0xff)
	for x in range(len(data)):
		for byteIndex in range(width):
			byte = (data[x] >> (8 * (width - 1 - byteIndex))) & 0xff			
			line += '%02x' % byte
			checksum += byte
		
	line += '%02x' % ((~(checksum & 0xff) + 1) & 0xff)
	line += '\r\n'
	return line

# It is expected that each element in data is <width> bytes wide.  Each
# data element increments the address by 1.
def writeHexFile(data, width, file):
	address = 0;
	while address < len(data):
		sliceLength = min(len(data) - address, MAX_LINE_LENGTH)
		line = generateHexLine(address, data[address:address + sliceLength], width)
		file.write(line)
		address += sliceLength

	file.write(':00000001FF\r\n')

def readRawHexFile(file):
	data = []
	for line in file.readlines():
		data += [ int(line, 16) ]
		
	return data

def usage():
	print sys.argv[0], '[options] <input file>'
	print ' -o          output file name'
	print ' -w/--width  width (in bits 8/16/32)'

def main():
	try:
		opts, args = getopt.getopt(sys.argv[1:], 'o:w:', ['width='])
	except getopt.GetoptError, err:
		print str(err)
		usage()
		sys.exit(2)
	
	outputFileName = ''
	width = 1	# bytes
	
	for o, a in opts:
		if o == '-w' or o == '--width':
			if a == '32':
				width = 4
			elif a == '16':
				width = 2
			elif a != '8':
				print 'unsupported width (8/16/32 bits supported)'
				usage()
				sys.exit(2)
		elif o == '-o':
			outputFileName = a

	if len(args) != 1:
		print 'no input file specified'
		usage()
		sys.exit(2)

	if outputFileName == '':
		print 'no output file specified'
		usage()
		sys.exit(2)

	try:		
		outputFile = open(outputFileName, 'w')
		inputFile = open(args[0], 'r')
		fileData = readRawHexFile(inputFile)	
		writeHexFile(fileData, width, outputFile)
	except err:
		print err
		sys.exit(2)
	
main()
