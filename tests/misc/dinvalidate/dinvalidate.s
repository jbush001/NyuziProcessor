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



# This test writes something to the cache, then uses dinvalidate to remove it.

			.globl _start

_start:		lea s0, dataloc
			load_32 s1, storedat
			store_32 s1, (s0)
			dinvalidate s0		# This should blow away the word we just stored
			membar
			load_32 s2, (s0)	# Reload it to ensure the old value is still present
			setcr s0, 29
done: 		goto done
storedat:	.long	0x12345678

			.align 128
dataloc:	.long	0xdeadbeef			; will be at address 256
