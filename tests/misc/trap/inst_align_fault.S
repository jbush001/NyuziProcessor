;
; Copyright 2016 Jeff Bush
;
; Licensed under the Apache License, Version 2.0 (the "License");
; you may not use this file except in compliance with the License.
; You may obtain a copy of the License at
;
;     http://www.apache.org/licenses/LICENSE-2.0
;
; Unless required by applicable law or agreed to in writing, software
; distributed under the License is distributed on an "AS IS" BASIS,
; WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
; See the License for the specific language governing permissions and
; limitations under the License.
;

#include "trap_test_common.inc"

;
; Ensure jumping to an unaligned address faults
;

                .globl _start
_start:
                ; Set up fault handler
                lea s0, handle_fault
                setcr s0, CR_FAULT_HANDLER

                ; jump to bad address
                move pc, 0x357

handle_fault:   getcr s0, CR_FAULT_REASON
                assert_reg s0, TR_IFETCH_ALIGNNMENT
                getcr s0, CR_FAULT_PC
                assert_reg s0, 0x357
                call pass_test
