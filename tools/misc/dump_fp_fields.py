import sys, struct

def dump(x):
	print 'exponent', ((x >> 23) & 0xff)
	binary = ''
	sig = x & ((1 << 24) - 1)
	for x in range(23):
		if sig & (1 << (23 - x)):
			binary += '1'
		else:
			binary += '0'

	print 'significand', hex(sig), binary

dump(int(sys.argv[1]))
