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



				.global setjmp
				.type setjmp,@function
setjmp:			# Align s0 to a 64 byte boundary to do vector stores
				add_i s0, s0, 63		
				move s1, 63
				xor s1, s1, -1
				and s0, s0, s1

				# Copy callee-saved registers into structure
				store_v v26, 0(s0)
				store_v v27, 64(s0)
				store_v v28, 128(s0)
				store_v v29, 192(s0)
				store_v v30, 256(s0)
				store_v v31, 320(s0)
				store_32 s27, 384(s0)
				store_32 fp, 388(s0)
				store_32 sp, 392(s0)
				store_32 ra, 396(s0)	# Will return to this address
				move s0, 0
				move pc, ra


				.global longjmp
				.type longjmp,@function
longjmp:		# Align s0 to a 64 byte boundary to do vector loads
				add_i s0, s0, 63		
				move s2, 63
				xor s2, s2, -1
				and s0, s0, s2

				# Copy callee-saved registers out of structure
				load_v v26, 0(s0)
				load_v v27, 64(s0)
				load_v v28, 128(s0)
				load_v v29, 192(s0)
				load_v v30, 256(s0)
				load_v v31, 320(s0)
				load_32 s27, 384(s0)
				load_32 fp, 388(s0)
				load_32 sp, 392(s0)
				load_32 s2, 396(s0)	# Get return address
				move s0, s1		    # Set return value
				move pc, s2			# Jump back

