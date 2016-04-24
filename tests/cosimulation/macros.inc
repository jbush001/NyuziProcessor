#
# Copyright 2015 Jeff Bush
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

.set CR_CURRENT_THREAD, 0
.set CR_FAULT_HANDLER, 1
.set CR_FAULT_PC, 2
.set CR_FAULT_REASON, 3
.set CR_FLAGS, 4
.set CR_FAULT_ADDRESS, 5
.set CR_SAVED_FLAGS, 8

.macro HALT_CURRENT_THREAD
	getcr s0, CR_CURRENT_THREAD
	move s1, 1
	shl s1, s1, s0
	move s0, 0xffffffff
	shl s0, s0, 16
	or s0, s0, 0x104
	store_32 s1, (s0)
1:	goto 1b
.endm

.macro START_ALL_THREADS
	move s0, 0xffffffff
	shl s0, s0, 16
	or s0, s0, 0x100
	move s1, 0xffffffff
	store_32 s1, (s0)
.endm
