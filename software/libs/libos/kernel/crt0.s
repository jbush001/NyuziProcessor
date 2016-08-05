//
// Copyright 2016 Jeff Bush
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

                    .globl _start
_start:
                    # Call global initializers
                    load_32 s24, init_array_start
                    load_32 s25, init_array_end
init_loop:          cmpeq_i s0, s24, s25    # End of array?
                    btrue s0, do_main       # If so, exit loop
                    load_32 s0, (s24)       # Load ctor address
                    add_i s24, s24, 4       # Next array index
                    call s0                 # Call constructor
                    goto init_loop

do_main:            call main

                    # Call atexit functions
                    call call_atexit_functions

                    call exit

init_array_start:   .long __init_array_start
init_array_end:     .long __init_array_end


                    .globl __other_thread_start
__other_thread_start:
                    call main
                    call thread_exit

                    .globl __syscall
__syscall:          syscall
                    ret