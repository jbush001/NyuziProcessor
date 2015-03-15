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



# s0 - dest
# s1 - src
# s2 - count

					.global memcpy
					.type memcpy,@function
memcpy:				move s6, s0				# Save source pointer, which we will return
					
					# Check if the source and dest have the same alignment
					# modulo 64. If so, we can do block vector copy 
					and s3, s0, 63
					and s4, s1, 63
					cmpeq_i s5, s3, s4
					bfalse s5, copy_word_check	# Not aligned, see if we can copy words
				
					# ...Falls through, we can do vector copies
				
					# There may be leading bytes before alignment.  Copy up to that.
copy_vector_lead_in: and s4, s0, 63			# Aligned yet?
					bfalse s4, copy_vector 	# Yes, time to do big copies		
					bfalse s2, copy_done	# Bail if we are done.
					load_u8 s4, (s1)
					store_8 s4, (s0)
					add_i s0, s0, 1
					add_i s1, s1, 1
					sub_i s2, s2, 1
					goto copy_vector_lead_in

					# Copy entire vectors at a time
copy_vector:		cmplt_u s4, s2, 64			# 64 or more bytes left?
					btrue s4, copy_words		# No, attempt to copy words
					load_v v0, (s1)
					store_v v0, (s0)
					add_i s0, s0, 64
					add_i s1, s1, 64
					sub_i s2, s2, 64
					goto copy_vector

					# Check the source and dest have the same alignment
					# modulo 4.  If so, we can copy 32 bits at a time.
copy_word_check: 	and s3, s0, 3
					and s4, s1, 3
					cmpeq_i s5, s3, s4
					bfalse s5, copy_remain_bytes	# Not aligned, need to do it the slow way

copy_word_lead_in:	and s4, s0, 3			# Aligned yet?
					bfalse s4, copy_words	# If yes, start copying
					bfalse s2, copy_done	# Bail if we are done
					load_u8 s4, (s1)
					store_8 s4, (s0)
					add_i s0, s0, 1
					add_i s1, s1, 1
					sub_i s2, s2, 1
					goto copy_word_lead_in

copy_words:			cmplt_u s4, s2, 4			# 4 or more bytes left?
					btrue s4, copy_remain_bytes	# If not, copy tail
					load_32 s4, (s1)
					store_32 s4, (s0)
					add_i s0, s0, 4
					add_i s1, s1, 4
					sub_i s2, s2, 4
					goto copy_words

					# Perform byte copy of whatever is remaining
copy_remain_bytes:	bfalse s2, copy_done
					load_u8 s4, (s1)
					store_8 s4, (s0)
					add_i s0, s0, 1
					add_i s1, s1, 1
					sub_i s2, s2, 1
					goto copy_remain_bytes

copy_done:			move s0, s6		# Get source pointer to return
					ret

