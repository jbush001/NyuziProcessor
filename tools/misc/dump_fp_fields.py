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

import sys, struct

def dump(value):
	print hex(value)
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
if strval[:2] == '0x':
	dump(int(strval[2:], 16))
elif strval.find('.') != -1:
	dump(struct.unpack('I', struct.pack('f', float(strval)))[0])
else:
	dump(int(strval))
