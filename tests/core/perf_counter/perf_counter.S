#
# Copyright 2019 Jeff Bush
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

.include "../../asm_macros.inc"

#
# This is a very basic smoke test for performance counters.
# I chose the store and unconditional branch events because those
# are easy to control the execution of.
#

                    .text
                    .align 4

                    .globl _start
_start:             lea s5, write_loc
                    move s0, 2      # Store event
                    setcr s0, CR_PERF_EVENT_SELECT0
                    move s0, 11     # Unconditional branch event
                    setcr s0, CR_PERF_EVENT_SELECT1
                    getcr s6, CR_PERF_EVENT_COUNT0_L
                    getcr s7, CR_PERF_EVENT_COUNT1_L

                    # Collect events   ###############################
                    # Stores occur back-to-back, which will cause a rollback
                    # when the request has been sent and is pending. Ensure
                    # this is not counted as an extra store.
                    store_32 s0, (s5)   # store 1
                    b 1f                # branch 1
1:                  b 1f                # branch 2
1:                  store_32 s0, (s5)   # store 2
                    store_32 s0, (s5)   # store 3
                    store_32 s0, (s5)   # store 4
                    ##################################################

                    # Give stores time to finish
                    nop
                    nop
                    nop
                    nop

                    getcr s8, CR_PERF_EVENT_COUNT0_L # Store
                    sub_i s8, s8, s6
                    getcr s9, CR_PERF_EVENT_COUNT1_L # Unconditional branch
                    sub_i s9, s9, s7

                    cmpeq_i s10, s8, 4      # Check stores
                    bnz s10, 1f
                    call fail_test
1:                  cmpeq_i s10, s9, 2      # Check branches
                    bnz s10, 1f
                    call fail_test
1:                  call pass_test

write_loc:          .long 0