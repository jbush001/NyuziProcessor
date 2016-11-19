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
_start:     move s0, -1             // Load reg addr s0 = 0xffffffff
            shl s0, s0, 16          // s0 = 0xffff0000
            or s0, s0, 0x100        // s0 = 0xffff0100
            move s1, -1
            store_32 s1, (s0)

            move s0, 1
            move s0, 2
            move s0, 3
            move s0, 4
            move s0, 5
            move s0, 6
            move s0, 7
            move s0, 8
            move s0, 9
            move s0, 10

