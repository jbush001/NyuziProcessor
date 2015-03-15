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

# Given a set of hex encoded packed data records with the format given in the fields array
# (msb first), decode and print in CSV format.

fields = [
	(None, 12),
	('retire_sync_store', 1),
	('retire_sync_success', 1),
	('retire_thread', 2),
	(None, 3),
	('is_sync_store', 1),
	('is_sync_load', 1),
	('sync_store_success', 1),
	('sync_id', 2),
	(None, 4),
	('storebuf_l2_response_valid', 1),
	('storebuf_l2_sync_success', 1),
	('storebuf_l2_response_idx', 2)
]

hexstr = ''
totalBits = (sum([width for name, width in fields]))
BYTES_PER_TRACE=(totalBits + 7) / 8

for name, size in fields:
	if name:
		print name + ',',
		
print ''

for line in sys.stdin.readlines():
	hexstr = line[:2] + hexstr
	if len(hexstr) == BYTES_PER_TRACE * 2:
		if hexstr[0:2] != '55':
			print 'bad trace record'
			break

		bigval = int(hexstr, 16)
		lowoffset = BYTES_PER_TRACE * 8
		for name, width in fields:
			lowoffset -= width
			if name:
				fieldval = (bigval >> lowoffset) & ((1 << width) - 1)
				print hex(fieldval)[2:],

			
		hexstr = ''
		print ''
