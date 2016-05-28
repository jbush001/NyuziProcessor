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

#include "../../asm_macros.inc"

//
// Test mechanism for delivering interrupts from the emulator to an
// external program.
//

                .globl _start
_start:         move s0, 5
                load_const s1, REG_HOST_INTERRUPT
1:              store_32 s0, (s1)
                add_i s0, s0, 1
                cmpge_i s2, s0, 10
                bfalse s2, 1b
                halt_all_threads

