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
