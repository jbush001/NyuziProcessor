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

.set IFRAME_SIZE, 192

						.globl trap_handler
						.type trap_handler,@function
trap_handler:			sub_i sp, sp, IFRAME_SIZE
						store_32 s0, 0(sp)
						store_32 s1, 4(sp)
						store_32 s2, 8(sp)
						store_32 s3, 12(sp)
						store_32 s4, 16(sp)
						store_32 s5, 20(sp)
						store_32 s6, 24(sp)
						store_32 s7, 28(sp)
						store_32 s8, 32(sp)
						store_32 s9, 36(sp)
						store_32 s10, 40(sp)
						store_32 s11, 44(sp)
						store_32 s12, 48(sp)
						store_32 s13, 52(sp)
						store_32 s14, 56(sp)
						store_32 s15, 60(sp)
						store_32 s16, 64(sp)
						store_32 s17, 68(sp)
						store_32 s18, 72(sp)
						store_32 s19, 76(sp)
						store_32 s20, 80(sp)
						store_32 s21, 84(sp)
						store_32 s22, 88(sp)
						store_32 s23, 92(sp)
						store_32 s24, 96(sp)
						store_32 s25, 100(sp)
						store_32 s26, 104(sp)
						store_32 s27, 108(sp)
						store_32 fp, 112(sp)
						# Stack pointer slot is unused
						store_32 ra, 120(sp)

						getcr s0, 2
						store_32 s0, 124(sp)   # Saved PC
						getcr s0, 8
						store_32 s0, 128(sp)   # Saved flags
						getcr s0, 13
						store_32 s0, 132(sp)   # Subcycle

						move s0, sp

						call do_trap

						load_32 s1, 4(sp)
						load_32 s2, 8(sp)
						load_32 s3, 12(sp)
						load_32 s4, 16(sp)
						load_32 s5, 20(sp)
						load_32 s6, 24(sp)
						load_32 s7, 28(sp)
						load_32 s8, 32(sp)
						load_32 s9, 36(sp)
						load_32 s10, 40(sp)
						load_32 s11, 44(sp)
						load_32 s12, 48(sp)
						load_32 s13, 52(sp)
						load_32 s14, 56(sp)
						load_32 s15, 60(sp)
						load_32 s16, 64(sp)
						load_32 s17, 68(sp)
						load_32 s18, 72(sp)
						load_32 s19, 76(sp)
						load_32 s20, 80(sp)
						load_32 s21, 84(sp)
						load_32 s22, 88(sp)
						load_32 s23, 92(sp)
						load_32 s24, 96(sp)
						load_32 s25, 100(sp)
						load_32 s26, 104(sp)
						load_32 s27, 108(sp)
						load_32 fp, 112(sp)
						load_32 ra, 120(sp)

						load_32 s0, 124(sp)   # Saved PC
						setcr s0, 2
						load_32 s0, 128(sp)   # Saved flags
						setcr s0, 8
						load_32 s0, 132(sp)   # Subcycle
						setcr s0, 13
						load_32 s0, 0(sp)
						add_i sp, sp, IFRAME_SIZE
						eret
