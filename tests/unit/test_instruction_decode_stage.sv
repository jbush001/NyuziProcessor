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

`include "defines.sv"

import defines::*;

//
// This doesn't exhaustively test different instruction formats, but
// checks exception/interrupt injection, and a few sanity checks.
//
module test_instruction_decode_stage(input clk, input reset);
    logic ifd_instruction_valid;
    scalar_t ifd_instruction;
    logic ifd_inst_injected;
    scalar_t ifd_pc;
    local_thread_idx_t ifd_thread_idx;
    logic ifd_alignment_fault;
    logic ifd_supervisor_fault;
    logic ifd_page_fault;
    logic ifd_executable_fault;
    logic ifd_tlb_miss;
    local_thread_bitmap_t dd_load_sync_pending;
    local_thread_bitmap_t sq_store_sync_pending;
    decoded_instruction_t id_instruction;
    logic id_instruction_valid;
    local_thread_idx_t id_thread_idx;
    local_thread_bitmap_t ior_pending;
    local_thread_bitmap_t cr_interrupt_en;
    local_thread_bitmap_t cr_interrupt_pending;
    logic wb_rollback_en;
    local_thread_idx_t wb_rollback_thread_idx;
    logic ocd_halt;
    int cycle;

    instruction_decode_stage instruction_decode_stage(.*);

    always @(posedge clk, posedge reset)
    begin
        if (reset)
        begin
            cycle <= 0;
            ifd_thread_idx <= 0;
            ifd_pc <= 0;
        end
        else
        begin
            // default values
            ifd_instruction_valid <= 0;
            ifd_alignment_fault <= 0;
            ifd_supervisor_fault <= 0;
            ifd_page_fault <= 0;
            ifd_executable_fault <= 0;
            ifd_tlb_miss <= 0;
            dd_load_sync_pending <= 0;
            sq_store_sync_pending <= 0;
            ior_pending <= 0;
            ifd_instruction <= 0;
            cr_interrupt_en <= 0;
            cr_interrupt_pending <= 0;
            wb_rollback_en <= 0;
            ifd_inst_injected <= 0;
            ocd_halt <= 0;

            cycle <= cycle + 1;
            unique0 case (cycle)
                // Instruction alignment fault
                0: ifd_alignment_fault <= 1;
                // wait a cycle

                2:
                begin
                    assert(id_instruction_valid);
                    assert(id_thread_idx == ifd_thread_idx);
                    assert(id_instruction.pc == ifd_pc);
                    assert(id_instruction.has_trap);
                    assert(id_instruction.pipeline_sel == PIPE_INT_ARITH);
                    assert(!id_instruction.has_dest);
                    assert(!id_instruction.has_scalar1);
                    assert(!id_instruction.has_scalar2);
                    assert(!id_instruction.has_vector1);
                    assert(!id_instruction.has_vector2);
                    assert(id_instruction.trap_cause == {2'b00, TT_UNALIGNED_ACCESS});

                    // Simulate fault
                    ifd_thread_idx <= ifd_thread_idx + 1;
                    ifd_pc <= ifd_pc + 4;
                    ifd_supervisor_fault <= 1;
                end

                // wait a cycle
                3: assert(!id_instruction_valid);

                4:
                begin
                    assert(id_instruction_valid);
                    assert(id_thread_idx == ifd_thread_idx);
                    assert(id_instruction.pc == ifd_pc);
                    assert(id_instruction.has_trap);
                    assert(id_instruction.pipeline_sel == PIPE_INT_ARITH);
                    assert(!id_instruction.has_dest);
                    assert(!id_instruction.has_scalar1);
                    assert(!id_instruction.has_scalar2);
                    assert(!id_instruction.has_vector1);
                    assert(!id_instruction.has_vector2);
                    assert(id_instruction.trap_cause == {2'b00, TT_SUPERVISOR_ACCESS});

                    // Page fault
                    ifd_thread_idx <= ifd_thread_idx + 1;
                    ifd_pc <= ifd_pc + 4;
                    ifd_page_fault <= 1;
                end

                // wait a cycle
                5: assert(!id_instruction_valid);

                6:
                begin
                    assert(id_instruction_valid);
                    assert(id_thread_idx == ifd_thread_idx);
                    assert(id_instruction.has_trap);
                    assert(id_instruction.pipeline_sel == PIPE_INT_ARITH);
                    assert(!id_instruction.has_dest);
                    assert(!id_instruction.has_scalar1);
                    assert(!id_instruction.has_scalar2);
                    assert(!id_instruction.has_vector1);
                    assert(!id_instruction.has_vector2);
                    assert(id_instruction.trap_cause == {2'b00, TT_PAGE_FAULT});

                    // Executable fault
                    ifd_thread_idx <= ifd_thread_idx + 1;
                    ifd_pc <= ifd_pc + 4;
                    ifd_executable_fault <= 1;
                end

                // wait a cycle
                7: assert(!id_instruction_valid);

                8:
                begin
                    assert(id_instruction_valid);
                    assert(id_thread_idx == ifd_thread_idx);
                    assert(id_instruction.pc == ifd_pc);
                    assert(id_instruction.has_trap);
                    assert(id_instruction.pipeline_sel == PIPE_INT_ARITH);
                    assert(!id_instruction.has_dest);
                    assert(!id_instruction.has_scalar1);
                    assert(!id_instruction.has_scalar2);
                    assert(!id_instruction.has_vector1);
                    assert(!id_instruction.has_vector2);
                    assert(id_instruction.trap_cause == {2'b00, TT_NOT_EXECUTABLE});

                    // TLB miss
                    ifd_thread_idx <= ifd_thread_idx + 1;
                    ifd_pc <= ifd_pc + 4;
                    ifd_tlb_miss <= 1;
                end

                // wait a cycle
                9: assert(!id_instruction_valid);

                10:
                begin
                    assert(id_instruction_valid);
                    assert(id_thread_idx == ifd_thread_idx);
                    assert(id_instruction.pc == ifd_pc);
                    assert(id_instruction.has_trap);
                    assert(id_instruction.pipeline_sel == PIPE_INT_ARITH);
                    assert(!id_instruction.has_dest);
                    assert(!id_instruction.has_scalar1);
                    assert(!id_instruction.has_scalar2);
                    assert(!id_instruction.has_vector1);
                    assert(!id_instruction.has_vector2);
                    assert(id_instruction.trap_cause == {2'b00, TT_TLB_MISS});

                    // Syscall instruction
                    ifd_instruction_valid <= 1;
                    ifd_pc <= ifd_pc + 4;
                    ifd_instruction <= 32'hc3f00000;
                end

                // wait a cycle
                11: assert(!id_instruction_valid);

                12:
                begin
                    assert(id_instruction_valid);
                    assert(id_thread_idx == ifd_thread_idx);
                    assert(id_instruction.pc == ifd_pc);
                    assert(id_instruction.has_trap);
                    assert(id_instruction.pipeline_sel == PIPE_INT_ARITH);
                    assert(!id_instruction.has_dest);
                    assert(!id_instruction.has_scalar1);
                    assert(!id_instruction.has_scalar2);
                    assert(!id_instruction.has_vector1);
                    assert(!id_instruction.has_vector2);
                    assert(id_instruction.trap_cause == {2'b00, TT_SYSCALL});

                    // break instruction
                    ifd_instruction_valid <= 1;
                    ifd_pc <= ifd_pc + 4;
                    ifd_instruction <= 32'hc3e00000;
                end

                // wait a cycle
                13: assert(!id_instruction_valid);

                14:
                begin
                    assert(id_instruction_valid);
                    assert(id_thread_idx == ifd_thread_idx);
                    assert(id_instruction.pc == ifd_pc);
                    assert(id_instruction.has_trap);
                    assert(id_instruction.pipeline_sel == PIPE_INT_ARITH);
                    assert(!id_instruction.has_dest);
                    assert(!id_instruction.has_scalar1);
                    assert(!id_instruction.has_scalar2);
                    assert(!id_instruction.has_vector1);
                    assert(!id_instruction.has_vector2);
                    assert(id_instruction.trap_cause == {2'b00, TT_BREAKPOINT});

                    // Illegal instruction (bad format type)
                    ifd_instruction_valid <= 1;
                    ifd_pc <= ifd_pc + 4;
                    ifd_instruction <= 32'hdc000000;
                end

                // wait a cycle
                15: assert(!id_instruction_valid);

                16:
                begin
                    assert(id_instruction_valid);
                    assert(id_thread_idx == ifd_thread_idx);
                    assert(id_instruction.pc == ifd_pc);
                    assert(id_instruction.has_trap);
                    assert(id_instruction.pipeline_sel == PIPE_INT_ARITH);
                    assert(!id_instruction.has_dest);
                    assert(!id_instruction.has_scalar1);
                    assert(!id_instruction.has_scalar2);
                    assert(!id_instruction.has_vector1);
                    assert(!id_instruction.has_vector2);
                    assert(id_instruction.trap_cause == {2'b00, TT_ILLEGAL_INSTRUCTION});
                end

                ////////////////////////////////////////////////////////////
                // Test interrupts
                ////////////////////////////////////////////////////////////

                20:
                begin
                    // Can't take an interrupt, because a sync load is pending
                    ifd_instruction_valid <= 1;
                    ifd_thread_idx <= 1;
                    dd_load_sync_pending <= 4'b0010;
                    cr_interrupt_pending <= 4'b0010;
                    cr_interrupt_en <= 4'b0010;
                end

                // wait a cycle
                21: assert(!id_instruction_valid);

                22:
                begin
                    assert(id_instruction_valid);
                    assert(!id_instruction.has_trap);

                    // Can't take an interrupt, because a sync store is pending
                    ifd_instruction_valid <= 1;
                    sq_store_sync_pending <= 4'b0010;
                    cr_interrupt_pending <= 4'b0010;
                    cr_interrupt_en <= 4'b0010;
                end

                // wait a cycle
                23: assert(!id_instruction_valid);

                24:
                begin
                    assert(id_instruction_valid);
                    assert(!id_instruction.has_trap);

                    // Can't take an interrupt, because an I/O request is pending
                    ifd_instruction_valid <= 1;
                    ior_pending <= 4'b0010;
                    cr_interrupt_pending <= 4'b0010;
                    cr_interrupt_en <= 4'b0010;
                end

                // wait a cycle
                25: assert(!id_instruction_valid);

                26:
                begin
                    assert(id_instruction_valid);
                    assert(!id_instruction.has_trap);

                    // Can't take an interrupt, because the interrupt flag is disabled
                    ifd_instruction_valid <= 1;
                    cr_interrupt_pending <= 4'b0010;
                    cr_interrupt_en <= 4'b0000;
                end

                // wait a cycle
                27: assert(!id_instruction_valid);

                28:
                begin
                    assert(id_instruction_valid);
                    assert(!id_instruction.has_trap);

                    // Don't take an interrupt while halted by on-chip-debugger
                    ifd_instruction_valid <= 1;
                    ocd_halt <= 1;
                    ifd_thread_idx <= 1;
                    cr_interrupt_pending <= 4'b0010;
                    cr_interrupt_en <= 4'b0010;
                end

                // wait a cycle
                29: assert(!id_instruction_valid);

                30:
                begin
                    assert(id_instruction_valid);
                    assert(!id_instruction.has_trap);

                    // can take an interrupt
                    cr_interrupt_pending <= 4'b0010;
                    cr_interrupt_en <= 4'b0010;

                    // Set pending signals for all other threads but this to ensure this
                    // is only looking at its own bits.
                    ifd_instruction_valid <= 1;
                    ior_pending <= 4'b1101;
                    sq_store_sync_pending <= 4'b1101;
                    dd_load_sync_pending <= 4'b1101;
                end

                // wait a cycle
                31: assert(!id_instruction_valid);

                32:
                begin
                    assert(id_instruction_valid);
                    assert(id_thread_idx == 1);
                    assert(id_instruction.pc == ifd_pc);
                    assert(id_instruction.has_trap);
                    assert(id_instruction.pipeline_sel == PIPE_INT_ARITH);
                    assert(!id_instruction.has_dest);
                    assert(!id_instruction.has_scalar1);
                    assert(!id_instruction.has_scalar2);
                    assert(!id_instruction.has_vector1);
                    assert(!id_instruction.has_vector2);
                    assert(id_instruction.trap_cause == {2'b00, TT_INTERRUPT});
                end

                ////////////////////////////////////////////////////////////
                // Test normal instruction scenarios
                ////////////////////////////////////////////////////////////

                33:
                begin
                    // Integer instruction (or s1, s2, s3)
                    ifd_instruction_valid <= 1;
                    ifd_instruction <= 32'hc0018022;
                end

                // wait a cycle
                34: assert(!id_instruction_valid);

                35:
                begin
                    assert(id_instruction_valid);
                    assert(!id_instruction.has_trap);
                    assert(id_instruction.pc == ifd_pc);
                    assert(id_instruction.pipeline_sel == PIPE_INT_ARITH);
                    assert(id_instruction.last_subcycle == 0);
                    assert(!id_instruction.injected);

                    // Long latency instruction (mull_i s6, s7, s8)
                    ifd_instruction_valid <= 1;
                    ifd_instruction <= 32'hc07400c7;
                end

                // wait a cycle
                36: assert(!id_instruction_valid);

                37:
                begin
                    assert(id_instruction_valid);
                    assert(!id_instruction.has_trap);
                    assert(id_instruction.pc == ifd_pc);
                    assert(id_instruction.pipeline_sel == PIPE_FLOAT_ARITH);
                    assert(id_instruction.last_subcycle == 0);
                    assert(!id_instruction.injected);

                    // Multicycle instruction (load_gath v4, 312(v5))
                    ifd_instruction_valid <= 1;
                    ifd_instruction <= 32'hba04e085;
                end

                // wait a cycle
                38: assert(!id_instruction_valid);

                39:
                begin
                    assert(id_instruction_valid);
                    assert(!id_instruction.has_trap);
                    assert(id_instruction.pc == ifd_pc);
                    assert(id_instruction.pipeline_sel == PIPE_MEM);
                    assert(id_instruction.last_subcycle == 15);
                end

                40:
                begin
                    // nop
                    ifd_instruction_valid <= 1;
                    ifd_instruction <= 32'h00000000;
                end

                // wait a cycle
                41: assert(!id_instruction_valid);

                // Nop is special in that it doesn't have any side effects
                42:
                begin
                    assert(id_instruction_valid);
                    assert(!id_instruction.has_trap);
                    assert(!id_instruction.has_dest);
                    assert(!id_instruction.has_scalar1);
                    assert(!id_instruction.has_scalar2);
                    assert(!id_instruction.has_vector1);
                    assert(!id_instruction.has_vector2);
                end

                ////////////////////////////////////////////////////////////
                // Rollback cases
                ////////////////////////////////////////////////////////////

                50:
                begin
                    // This thread is rolled back. Ensure instruction doesn't come out.
                    ifd_instruction_valid <= 1;
                    ifd_instruction <= 32'hc0018022;    // or s1, s2, s3
                    ifd_thread_idx <= 0;
                    wb_rollback_en <= 1;
                    wb_rollback_thread_idx <= 0;
                end

                // wait a cycle
                51: assert(!id_instruction_valid);

                52:
                begin
                    assert(!id_instruction_valid);

                    // Rollback occurs concurrently with alignment fault. The fault
                    // should not occur.
                    ifd_alignment_fault <= 1;
                    wb_rollback_en <= 1;
                end

                // wait a cycle
                53: assert(!id_instruction_valid);

                54:
                begin
                    assert(!id_instruction_valid);

                    // Rollback occurs concurrently with TLB miss. The fault
                    // should not occur.
                    ifd_tlb_miss <= 1;
                    wb_rollback_en <= 1;
                end

                // wait a cycle
                55: assert(!id_instruction_valid);

                56:
                begin
                    assert(!id_instruction_valid);

                    // Rollback occurs concurrently with supervisor fault. The fault
                    // should not occur.
                    ifd_supervisor_fault <= 1;
                    wb_rollback_en <= 1;
                end

                // wait a cycle
                57: assert(!id_instruction_valid);

                58:
                begin
                    assert(!id_instruction_valid);

                    // Rollback occurs concurrently with page fault. The fault
                    // should not occur.
                    ifd_page_fault <= 1;
                    wb_rollback_en <= 1;
                end

                // wait a cycle
                59: assert(!id_instruction_valid);

                60:
                begin
                    assert(!id_instruction_valid);

                    // Rollback occurs concurrently with executable fault. The fault
                    // should not occur.
                    ifd_executable_fault <= 1;
                    wb_rollback_en <= 1;
                end

                // wait a cycle
                61: assert(!id_instruction_valid);

                62:
                begin
                    assert(!id_instruction_valid);

                    // Rollback occurs for another thread. Make sure
                    // instruction is issued.
                    ifd_instruction_valid <= 1;
                    ifd_thread_idx <= 1;
                    wb_rollback_en <= 1;
                    wb_rollback_thread_idx <= 2;
                end

                // wait a cycle
                63: assert(!id_instruction_valid);

                64: assert(id_instruction_valid);

                ////////////////////////////////////////////////////////////
                // Fault priorities. It's possible for two fault conditions
                // to occur at once (for example, unaligned access to
                // non-executable, supervisor page).  Ensure these
                // are prioritized corectly.
                ////////////////////////////////////////////////////////////
                70:
                begin
                    ifd_alignment_fault <= 1;
                    ifd_tlb_miss <= 1;
                end

                // wait a cycle
                71: assert(!id_instruction_valid);

                72:
                begin
                    assert(id_instruction_valid);
                    assert(id_instruction.trap_cause == {2'b00, TT_TLB_MISS});

                    ifd_page_fault <= 1;
                    ifd_alignment_fault <= 1;
                    ifd_supervisor_fault <= 1;
                    ifd_executable_fault <= 1;
                end

                // wait a cycle
                73: assert(!id_instruction_valid);

                74:
                begin
                    assert(id_instruction_valid);
                    assert(id_instruction.trap_cause == {2'b00, TT_PAGE_FAULT});

                    ifd_alignment_fault <= 1;
                    ifd_supervisor_fault <= 1;
                    ifd_executable_fault <= 1;
                end

                // wait a cycle
                75: assert(!id_instruction_valid);

                76:
                begin
                    assert(id_instruction_valid);
                    assert(id_instruction.trap_cause == {2'b00, TT_SUPERVISOR_ACCESS});

                    ifd_alignment_fault <= 1;
                    ifd_executable_fault <= 1;
                end

                // wait a cycle
                77: assert(!id_instruction_valid);

                78:
                begin
                    assert(id_instruction_valid);
                    assert(id_instruction.trap_cause == {2'b00, TT_UNALIGNED_ACCESS});
                end

                ////////////////////////////////////////////////////////////
                // On-chip debugger injected instruction
                ////////////////////////////////////////////////////////////
                80:
                begin
                    ifd_instruction_valid <= 1;
                    ifd_instruction <= 32'hc0018022;
                    ifd_inst_injected <= 1;
                end

                // wait a cycle
                81: assert(!id_instruction_valid);

                82:
                begin
                    assert(id_instruction_valid);
                    assert(!id_instruction.has_trap);
                    assert(id_instruction.pc == ifd_pc);
                    assert(id_instruction.pipeline_sel == PIPE_INT_ARITH);
                    assert(id_instruction.last_subcycle == 0);
                    assert(id_instruction.injected);

                    // Long latency instruction (mull_i s6, s7, s8)
                    ifd_instruction_valid <= 1;
                    ifd_instruction <= 32'hc07400c7;
                end

                83:
                begin
                    $display("PASS");
                    $finish;
                end
            endcase
        end
    end
endmodule
