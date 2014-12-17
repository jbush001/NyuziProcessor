# 
# Copyright (C) 2011-2014 Jeff Bush
# 
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Library General Public
# License as published by the Free Software Foundation; either
# version 2 of the License, or (at your option) any later version.
# 
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Library General Public License for more details.
# 
# You should have received a copy of the GNU Library General Public
# License along with this library; if not, write to the
# Free Software Foundation, Inc., 51 Franklin St, Fifth Floor,
# Boston, MA  02110-1301, USA.
# 


import sys, struct

def dump(value):
	print hex(value)
	print 'exponent', ((value >> 23) & 0xff)
	sig = value & ((1 << 23) - 1)
	print 'significand', hex(sig), bin(sig)[2:].zfill(23)
	print struct.unpack('f', struct.pack('I', value))[0]

strval = sys.argv[1]
if strval[:2] == '0x':
	dump(int(strval[2:], 16))
elif strval.find('.') != -1:
	dump(struct.unpack('I', struct.pack('f', float(strval)))[0])
else:
	dump(int(strval))
