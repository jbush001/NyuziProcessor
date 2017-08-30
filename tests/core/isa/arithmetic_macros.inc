//
// Copyright 2017 Jeff Bush
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

// Scalar/scalar operation
.macro test_sss operation, result, operand1, operand2
                li s0, \operand1
                li s1, \operand2
                \operation s2, s0, s1
                li s3, \result
                cmpeq_i s4, s2, s3
                bnz s4, 1f
                call fail_test
1:
.endmacro

// Unary scalar operation
.macro test_ss operation, result, operand1
                li s0, \operand1
                \operation s2, s0
                li s3, \result
                cmpeq_i s4, s2, s3
                bnz s4, 1f
                call fail_test
1:
.endmacro

// Vector/scalar operation
.macro test_vvs operation, result, operand1, operand2
                lea s0, \operand1
                load_v v0, (s0)
                li s1, \operand2
                \operation v1, v0, s1
                lea s0, \result
                load_v v2, (s0)
                cmpne_i s4, v1, v2
                bz s4, 1f
                call fail_test
1:
.endmacro

// Unary vector/scalar operation
.macro test_vs operation, result, operand1
                li s1, \operand1
                \operation v1, s1
                lea s0, \result
                load_v v2, (s0)
                cmpne_i s4, v1, v2
                bz s4, 1f
                call fail_test
1:
.endmacro

// Vector/scalar masked operation
.macro test_vvsm operation, result, mask, operand1, operand2
                lea s0, \operand1
                load_v v0, (s0)
                li s1, \operand2
                li s2, \mask
                move v1, 0  // Clear dest register so unmasked lanes are known
                \operation v1, s2, v0, s1
                lea s0, \result
                load_v v2, (s0)
                cmpne_i s4, v1, v2
                bz s4, 1f
                call fail_test
1:
.endmacro

// Unary vector/scalar masked operation
.macro test_vsm operation, result, mask, operand1
                li s1, \operand1
                li s2, \mask
                move v1, 0  // Clear dest register so unmasked lanes are known
                \operation v1, s2, s1
                lea s0, \result
                load_v v2, (s0)
                cmpne_i s4, v1, v2
                bz s4, 1f
                call fail_test
1:
.endmacro

// Vector/vector operation
.macro test_vvv operation, result, operand1, operand2
                lea s0, \operand1
                load_v v0, (s0)
                lea s0, \operand2
                load_v v1, (s0)
                \operation v2, v0, v1
                lea s0, \result
                load_v v3, (s0)
                cmpne_i s1, v2, v3
                bz s1, 1f
                call fail_test
1:
.endmacro

// Unary vector/vector operation
.macro test_vv operation, result, operand1
                lea s0, \operand1
                load_v v0, (s0)
                \operation v2, v0
                lea s0, \result
                load_v v3, (s0)
                cmpne_i s1, v2, v3
                bz s1, 1f
                call fail_test
1:
.endmacro

// Vector/vector masked operation
.macro test_vvvm operation, result, mask, operand1, operand2
                lea s0, \operand1
                load_v v0, (s0)
                lea s0, \operand2
                load_v v1, (s0)
                move v2, 0  // Clear dest register so unmasked lanes are known
                li s1, \mask
                \operation v2, s1, v0, v1
                lea s0, \result
                load_v v3, (s0)
                cmpne_i s1, v2, v3
                bz s1, 1f
                call fail_test
1:
.endmacro

// Unary vector/vector masked operation
.macro test_vvm operation, result, mask, operand1
                lea s0, \operand1
                load_v v0, (s0)
                move v2, 0  // Clear dest register so unmasked lanes are known
                li s1, \mask
                \operation v2, s1, v0
                lea s0, \result
                load_v v3, (s0)
                cmpne_i s1, v2, v3
                bz s1, 1f
                call fail_test
1:
.endmacro

// Scalar immediate operation
.macro test_ssi operation, result, operand1, operand2
                li s0, \operand1
                \operation s2, s0, \operand2
                li s3, \result
                cmpeq_i s4, s2, s3
                bnz s4, 1f
                call fail_test
1:
.endmacro

// Vector immediate operation
.macro test_vvi operation, result, operand1, operand2
                lea s0, \operand1
                load_v v0, (s0)
                \operation v2, v0, \operand2
                lea s0, \result
                load_v v3, (s0)
                cmpne_i s1, v2, v3
                bz s1, 1f
                call fail_test
1:
.endmacro

// Vector immediate masked operation
.macro test_vvim operation, result, mask, operand1, operand2
                lea s0, \operand1
                load_v v0, (s0)
                move v2, 0  // Clear dest register so unmasked lanes are known
                li s1, \mask
                \operation v2, s1, v0, \operand2
                lea s0, \result
                load_v v3, (s0)
                cmpne_i s1, v2, v3
                bz s1, 1f
                call fail_test
1:
.endmacro

