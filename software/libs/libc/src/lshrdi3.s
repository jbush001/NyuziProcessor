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


#
# Logical shift right a 64 bit integer. The param to be shifted is in [s1, s0]
# and the shift amount is in s2
#

					.global __lshrdi3
					.type __lshrdi3,@function
__lshrdi3:			bfalse s2, do_nothing   # if shift amount is 0, skip

                    cmpge_i s3, s2, 32  # Is the shift amount >= 32?
                    btrue s3, greater

                    move s3, 32
					sub_i s3, s3, s2
					shl s3, s1, s3	# Align bits that will be shifted in
					shr s0, s0, s2	# Shift upper word 
					shr s1, s1, s2	# Shift lower word
					or s0, s0, s3	# Fill in top bits in lower word
					move pc, ra		

greater:            sub_i s2, s2, 32    # Figure out how much to shift lower word 
                    shr s0, s1, s2      # shift upper word and move into lower
                    move s1, 0          # upper word is now 0
do_nothing:         move pc, ra