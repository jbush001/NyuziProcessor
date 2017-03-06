//
// Copyright 2011-2015 Jeff Bush
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

#include <stdint.h>
#include <stdio.h>

veci16_t global_vec;

int main()
{
    veci16_t source_vals = {
        0xf9b831b8,
        0x9f7b4265,
        0xa70a45a2,
        0xb7b93e81,
        0x2ab5a31b,
        0x76bb98f3,
        0xe9baa272,
        0x355937be,
        0x1bcf0973,
        0xb74796c6,
        0xc2caf54f,
        0x72dac547,
        0x90d42244,
        0xba9c15b3,
        0x7ef4b6bf,
        0xdf8d2b3a
    };

    __builtin_nyuzi_block_storei_masked(&global_vec, source_vals, 0x5555);
    for (int i = 0; i < 16; i++)
        printf("%08x\n", ((unsigned int*) &global_vec)[i]);

    // CHECK: 00000000
    // CHECK: 9f7b4265
    // CHECK: 00000000
    // CHECK: b7b93e81
    // CHECK: 00000000
    // CHECK: 76bb98f3
    // CHECK: 00000000
    // CHECK: 355937be
    // CHECK: 00000000
    // CHECK: b74796c6
    // CHECK: 00000000
    // CHECK: 72dac547
    // CHECK: 00000000
    // CHECK: ba9c15b3
    // CHECK: 00000000
    // CHECK: df8d2b3a
}
