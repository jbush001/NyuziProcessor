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

# The CHECK strings in this file are outputted by illegal_instruction.c

#define REG_ARITH_INST(__type__) (0xc0000000 | ((__type__) << 26))
#define IMM_ARITH_INST(__type__) ((__type__) << 28)
#define MEM_INST(__type__) (0x80000000 | ((__type__) << 25))

        	    .text
			    .align	4
			    .globl	illegal_inst
			    .type	illegal_inst,@function
illegal_inst:	move s10, 1
				.long REG_ARITH_INST(3) ; CHECK: FAULT 1 index 1
				move s10, 2
				.long REG_ARITH_INST(6) ; CHECK: FAULT 1 index 2
				move s10, 3
				.long REG_ARITH_INST(7) ; CHECK: FAULT 1 index 3
				move s10, 4
				.long IMM_ARITH_INST(3) ; CHECK: FAULT 1 index 4
				move s10, 5
				.long IMM_ARITH_INST(6) ; CHECK: FAULT 1 index 5
				move s10, 6
				.long IMM_ARITH_INST(7) ; CHECK: FAULT 1 index 6
				move s10, 7
				.long MEM_INST(9) ; CHECK: FAULT 1 index 7
				move s10, 8
				.long MEM_INST(10) ; CHECK: FAULT 1 index 8
				move s10, 9
				.long MEM_INST(11) ; CHECK: FAULT 1 index 9
				move s10, 10
				.long MEM_INST(12) ; CHECK: FAULT 1 index 10
				move s10, 11
				.long MEM_INST(15) ; CHECK: FAULT 1 index 11
				ret
