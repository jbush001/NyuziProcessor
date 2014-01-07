# 
# Copyright 2013 Jeff Bush
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

# Unpack signals dumped by the debug_trace.v module
import sys, csv

FIELDS = [ 3, 1, 1, 3, 1, 1, 10, 512, 4 ]
BYTES_PER_TRACE = (sum(FIELDS) + 7) / 8

traceVals = []
hexstr = ''
for line in sys.stdin.readlines():
	hexstr = line[:2] + hexstr
	if len(hexstr) == BYTES_PER_TRACE * 2:
		intval = int(hexstr, 16)
		event = []
		for width in reversed(FIELDS):
			fieldVal = intval & ((1 << width) - 1)
			intval >>= width
			event = [ fieldVal ] + event
		
		traceVals += [ event ]
		hexstr = ''

REQUEST_TYPES = [
	'L2REQ_LOAD',	
	'L2REQ_STORE',	
	'L2REQ_FLUSH',
	'L2REQ_DINVALIDATE',	
	'L2REQ_LOAD_SYNC',	
	'L2REQ_STORE_SYNC',	
	'L2REQ_IINVALIDATE'
]

RESPONSE_TYPES = [
	'L2RSP_LOAD_ACK',
	'L2RSP_STORE_ACK',	
	'L2RSP_DINVALIDATE',	
	'L2RSP_IINVALIDATE'
]

# 3'b010,
# rd_l2req_valid,	// 1
# rd_is_l2_fill,	// 1
# rd_l2req_op,	// 3
# rd_cache_hit,	// 1
# wr_update_enable,	// 1
# wr_cache_write_index, // 10
# wr_update_data, // 512
# 4'b0010

print 'valid,is_l2_fill,l2req_op,cache_hit,update_enable,cache_write_index,data'
for values in traceVals:
	preamble, l2req_valid, is_l2_fill, l2req_op, cache_hit, update_enable, \
		cache_write_index, update_data, postamble = values

	if preamble != 2 or postamble != 2:
		print 'bad trace entry', preamble, postamble
	else:
		csvLine = str(l2req_valid) + ',' + str(is_l2_fill) + ',' + REQUEST_TYPES[l2req_op] \
			+ ',' + str(cache_hit) + ',' + str(update_enable) + ',' \
			+ str(cache_write_index) + ',' + hex(update_data)

		print csvLine
