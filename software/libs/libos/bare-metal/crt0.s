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
# C runtime startup code. When the processor boots, only hardware thread 0 is
# running. It begins execution at _start, which sets up the stack, calls global
# constructors, and jumps to main(). If the program starts the other hardware
# threads, they also begins execution at _start, but they skip calling global
# constructors and jump directly to main.
#
# Memory map:
#
#            +---------------+
#            |     heap      |
# 0032C000   +---------------+
#            |  framebuffer  |
# 00200000   +---------------+
#            |     stacks    |
# 001F0000   +---------------+
#            |   code/data   |
# 00000000   +---------------+

                    .text
                    .globl _start
                    .align 4
                    .type _start,@function
_start:
                    # Set up stack
                    getcr s0, 0             # get my thread ID
                    shl s0, s0, 14          # 16k bytes per stack
                    li sp, 0x200000         # Base of stacks
                    sub_i sp, sp, s0        # Compute stack address

                    # Load global pointer
                    movehi gp, hi(_GLOBAL_OFFSET_TABLE_)
                    or gp, gp, lo(_GLOBAL_OFFSET_TABLE_)

                    # Only thread 0 does initialization.  Skip for other
                    # threads, which only arrive here after thread 0 has
                    # completed initialization and started them).
                    bnz s0, do_main

                    # Call global initializers
                    lea s24, __init_array_start
                    lea s25, __init_array_end
init_loop:          cmpeq_i s0, s24, s25    # End of array?
                    bnz s0, do_main       # If so, exit loop
                    load_32 s0, (s24)       # Load ctor address
                    add_i s24, s24, 4       # Next array index
                    call s0                 # Call constructor
                    b init_loop

do_main:            move s0, 0    # Set argc to 0
                    call main

                    # Main has returned. Acquire lock so only one thread will
                    # call destructors.
                    lea s0, exit_flag
1:                  load_sync s1, (s0)
                    bnz s1, 1b
                    move s1, 1
                    store_sync s1, (s0)
                    bz s1, 1b

                    # Call atexit functions
                    call call_atexit_functions

                    # Send ^D to terminate serial console program on FPGA
                    move s0, 4
                    call write_uart

                    #  Halt all threads.
                    move s0, -1
                    li s1, 0xffff0104   # thread halt register
                    store_32 s0, (s1)
1:                  b 1b

exit_flag:          .long 0
