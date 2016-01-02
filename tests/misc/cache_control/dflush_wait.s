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
# Test various conditions that should (and should not) cause rollbacks
# and thread suspends. Ensure processor does not hang.
#

                    .globl _start
_start:             lea s0, foo
                    membar           ; No outstanding writes, shouldn't wait
                    dflush s0        ; Address is not dirty, should do nothing
                    membar
                    store_32 s0, (s0)
                    dflush s0        ; Address is dirty.
                    membar

                    # Halt
                    move s1, -1
                    load_32 s0, thread_halt_mask
                    store_32 s1, (s0)
1:                  goto 1b
thread_halt_mask:   .long 0xffff0064

foo:                .long 0
