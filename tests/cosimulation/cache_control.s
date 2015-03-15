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



		.globl _start
_start: lea s0, foo
		dflush s0		; Address is not dirty, should do nothing
		membar
		store_32 s0, (s0)
		dflush s0		; Address is dirty.
		membar
		setcr s0, 29
done: 	goto done

foo: .long 0
