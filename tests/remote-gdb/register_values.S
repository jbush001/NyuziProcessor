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
_start:         load_v v0, vectorval
                load_32 s1, scalarval
                move s0, 1
                load_32 s0, (s0)    # Force crash to break into debugger
                                    # XXX need break instruction

                .align 64
vectorval:      .long 0xef0334f1, 0x9930089d, 0x9981f793, 0x3f4bae54
                .long 0x8fa2ea7a, 0xbdec8f53, 0x9cf53695, 0x2651726d
                .long 0x70ee2595, 0x348d6ed2, 0x631289f4, 0x5dae869c
                .long 0x836c42ba, 0xe15584aa, 0x4bbadbe2, 0x21f3a441
scalarval:      .long 0x853e7f7d

