import sys, struct

def dump(value):
	print 'exponent', ((value >> 23) & 0xff)
	binary = ''
	sig = value & ((1 << 24) - 1)
	for x in range(23):
		if sig & (1 << (22 - x)):
			binary += '1'
		else:
			binary += '0'

	print 'significand', hex(sig), binary
	
	print struct.unpack('f', struct.pack('I', value))[0]

strval = sys.argv[1]
if strval.find('.') != -1:
	dump(struct.unpack('I', struct.pack('f', float(strval)))[0])
else:
	dump(int(strval))
