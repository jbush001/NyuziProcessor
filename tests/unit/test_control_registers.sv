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
// Test trap handling, ensure exception state is saved and restored correctly.
//

module test_control_registers(input clk, input reset);
    localparam SCRATCHPAD0_0 = 32'h47aef111;
    localparam SCRATCHPAD1_0 = 32'hb74b7b47;
    localparam SCRATCHPAD0_1 = 32'h44fc17df;
    localparam SCRATCHPAD1_1 = 32'h35c1e57c;
    localparam SCRATCHPAD0_2 = 32'h826109b1;
    localparam SCRATCHPAD1_2 = 32'h91f13a15;
    localparam PC0 = 32'h2ad98;
    localparam PC1 = 32'h167c8;
    localparam PC2 = 32'h6340;
    localparam TRAP_CAUSE0 = TT_ILLEGAL_INSTRUCTION;
    localparam TRAP_CAUSE1 = TT_TLB_MISS;
    localparam TRAP_SUBCYCLE0 = 4'd6;
    localparam TRAP_SUBCYCLE1 = 4'd9;
    localparam FLAGS0 = 32'b011;    // user mode, mmu enable, interrupt enable
    localparam FLAGS1 = 32'b110;    // supervisor, mmu enable, disable interrupt
    localparam FLAGS2 = 32'b100;    // supervisor, no mmu, disable interrupt

    localparam NUM_INTERRUPTS = 16;

    logic [NUM_INTERRUPTS - 1:0] interrupt_req;
    scalar_t cr_eret_address[`THREADS_PER_CORE];
    logic cr_mmu_en[`THREADS_PER_CORE];
    logic cr_supervisor_en[`THREADS_PER_CORE];
    logic[ASID_WIDTH - 1:0] cr_current_asid[`THREADS_PER_CORE];
    logic[`THREADS_PER_CORE - 1:0] cr_interrupt_pending;
    local_thread_idx_t dt_thread_idx;
    logic dd_creg_write_en;
    logic dd_creg_read_en;
    control_register_t dd_creg_index;
    scalar_t dd_creg_write_val;
    logic wb_trap;
    logic wb_eret;
    trap_cause_t wb_trap_cause;
    scalar_t wb_trap_pc;
    scalar_t wb_trap_access_vaddr;
    local_thread_idx_t wb_rollback_thread_idx;
    subcycle_t wb_trap_subcycle;
    scalar_t cr_creg_read_val;
    local_thread_bitmap_t cr_interrupt_en;
    subcycle_t cr_eret_subcycle[`THREADS_PER_CORE];
    scalar_t cr_trap_handler;
    scalar_t cr_tlb_miss_handler;
    scalar_t dbg_data_from_host;
    logic dbg_data_update;
    scalar_t cr_data_to_host;
    int cycle;

    control_registers #(
        .CORE_ID(4'd0),
        .NUM_INTERRUPTS(NUM_INTERRUPTS)
    ) control_registers(.*);

    task write_creg(input control_register_t index, input int value);
        dd_creg_write_en <= 1;
        dd_creg_index <= index;
        dd_creg_write_val <= value;
    endtask

    task read_creg(input control_register_t index);
        dd_creg_read_en <= 1;
        dd_creg_index <= index;
    endtask

    task raise_trap(input trap_type_t trap_type, input int pc, input subcycle_t subcycle);
        wb_trap <= 1;
        wb_trap_cause <= 6'(trap_type);
        wb_trap_pc <= pc;
        wb_rollback_thread_idx <= 0;
        wb_trap_subcycle <= subcycle;
    endtask

    always_ff @(posedge clk, posedge reset)
    begin
        if (reset)
        begin
            cycle <= 0;
            dt_thread_idx <= 0;
        end
        else
        begin
            // Default values for control signals
            dd_creg_write_en <= 0;
            dd_creg_read_en <= 0;
            wb_trap <= 0;
            wb_eret <= 0;
            dbg_data_update <= 0;
            interrupt_req <= '0;

            cycle <= cycle + 1;
            unique0 case (cycle)
                0:
                begin
                    // Check that everything comes up in the correct state
                    assert(!cr_mmu_en[0]);
                    assert(!cr_mmu_en[1]);
                    assert(!cr_mmu_en[2]);
                    assert(!cr_mmu_en[3]);
                    assert(cr_supervisor_en[0]);
                    assert(cr_supervisor_en[1]);
                    assert(cr_supervisor_en[2]);
                    assert(cr_supervisor_en[3]);
                    assert(!cr_interrupt_en[0]);
                    assert(!cr_interrupt_en[1]);
                    assert(!cr_interrupt_en[2]);
                    assert(!cr_interrupt_en[3]);
                end

                // Set scratchpad registers
                1: write_creg(CR_SCRATCHPAD0, SCRATCHPAD0_0);
                2: write_creg(CR_SCRATCHPAD1, SCRATCHPAD1_0);

                // Enable the MMU, switch to user mode.
                3: write_creg(CR_FLAGS, FLAGS0);
                // Wait cycle

                5:
                begin
                    assert(cr_interrupt_en[0]);
                    assert(cr_mmu_en[0]);
                    assert(!cr_supervisor_en[0]);
                end

                // Now take a trap
                6: raise_trap(TRAP_CAUSE0, PC0, TRAP_SUBCYCLE0);

                // wait cycle 7

                8:
                begin
                    // The trap will turn off interrupts and switch to
                    // supervisor mode.
                    assert(!cr_interrupt_en[0]);
                    assert(cr_mmu_en[0]);
                    assert(cr_supervisor_en[0]);

                    // Ensure other flags are unaffected
                    assert(!cr_mmu_en[1]);
                    assert(!cr_mmu_en[2]);
                    assert(!cr_mmu_en[3]);
                    assert(cr_supervisor_en[1]);
                    assert(cr_supervisor_en[2]);
                    assert(cr_supervisor_en[3]);
                    assert(!cr_interrupt_en[1]);
                    assert(!cr_interrupt_en[2]);
                    assert(!cr_interrupt_en[3]);
                end

                9: read_creg(CR_TRAP_PC);
                // wait a cycle

                11:
                begin
                    assert(cr_creg_read_val == PC0);
                    read_creg(CR_FLAGS);
                end
                // wait a cycle

                13:
                begin
                    assert(cr_creg_read_val == FLAGS1);
                    read_creg(CR_TRAP_CAUSE);
                end
                // wait a cycle

                15:
                begin
                    assert(cr_creg_read_val == 32'(TRAP_CAUSE0));
                    read_creg(CR_SAVED_FLAGS);
                end
                // wait a cycle

                17:
                begin
                    assert(cr_creg_read_val == FLAGS0);
                    read_creg(CR_SUBCYCLE);
                end
                // wait a cycle

                19:
                begin
                    // Check subcycle
                    assert(cr_creg_read_val == 32'(TRAP_SUBCYCLE0));
                end

                // set scratchpad registers again
                20: write_creg(CR_SCRATCHPAD0, SCRATCHPAD0_1);
                21: write_creg(CR_SCRATCHPAD1, SCRATCHPAD1_1);

                // take a TLB miss trap
                22: raise_trap(TRAP_CAUSE1, PC1, TRAP_SUBCYCLE1);
                // Wait cycle

                24:
                begin
                    // A TLB miss will turn off the MMU and switch to
                    // supervisor mode.
                    assert(!cr_interrupt_en[0]);
                    assert(!cr_mmu_en[0]);
                    assert(cr_supervisor_en[0]);

                    // Ensure other flags are unaffected
                    assert(!cr_mmu_en[1]);
                    assert(!cr_mmu_en[2]);
                    assert(!cr_mmu_en[3]);
                    assert(cr_supervisor_en[1]);
                    assert(cr_supervisor_en[2]);
                    assert(cr_supervisor_en[3]);
                    assert(!cr_interrupt_en[1]);
                    assert(!cr_interrupt_en[2]);
                    assert(!cr_interrupt_en[3]);

                    // read back registers
                    read_creg(CR_TRAP_PC);
                end
                // wait cycle

                26:
                begin
                    assert(cr_creg_read_val == PC1);
                    read_creg(CR_FLAGS);
                end
                // wait cycle

                28:
                begin
                    // flags reflect interrupt/super values from above
                    assert(cr_creg_read_val == FLAGS2);
                    read_creg(CR_TRAP_CAUSE);
                end
                // wait cycle

                30:
                begin
                    assert(cr_creg_read_val == 32'(TRAP_CAUSE1));
                    read_creg(CR_SAVED_FLAGS);
                end
                // wait cycle

                32:
                begin
                    assert(cr_creg_read_val == FLAGS1);
                    read_creg(CR_SUBCYCLE);
                end
                // wait cycle

                34:
                begin
                    assert(cr_creg_read_val == 32'(TRAP_SUBCYCLE1));
                end

                // set scratchpad registers
                35: write_creg(CR_SCRATCHPAD0, SCRATCHPAD0_2);
                36: write_creg(CR_SCRATCHPAD1, SCRATCHPAD1_2);

                // read back scratchpad registers
                37: read_creg(CR_SCRATCHPAD0);
                // wait cycle

                39:
                begin
                    assert(cr_creg_read_val == SCRATCHPAD0_2);
                    read_creg(CR_SCRATCHPAD1);
                end
                // wait cycle

                41: assert(cr_creg_read_val == SCRATCHPAD1_2);

                // eret from TLB miss
                42: wb_eret <= 1;
                // wait cycle

                44:
                begin
                    // Old flags are restored, MMU is enabled again
                    assert(!cr_interrupt_en[0]);
                    assert(cr_mmu_en[0]);
                    assert(cr_supervisor_en[0]);

                    // Ensure other flags are unaffected
                    assert(!cr_mmu_en[1]);
                    assert(!cr_mmu_en[2]);
                    assert(!cr_mmu_en[3]);
                    assert(cr_supervisor_en[1]);
                    assert(cr_supervisor_en[2]);
                    assert(cr_supervisor_en[3]);
                    assert(!cr_interrupt_en[1]);
                    assert(!cr_interrupt_en[2]);
                    assert(!cr_interrupt_en[3]);
                end


                45: read_creg(CR_TRAP_PC);
                // wait a cycle

                47:
                begin
                    assert(cr_creg_read_val == PC0);
                    read_creg(CR_FLAGS);
                end
                // wait a cycle

                49:
                begin
                    assert(cr_creg_read_val == FLAGS1);
                    read_creg(CR_TRAP_CAUSE);
                end
                // wait a cycle

                51:
                begin
                    assert(cr_creg_read_val == 32'(TRAP_CAUSE0));
                    read_creg(CR_SAVED_FLAGS);
                end
                // wait a cycle

                53:
                begin
                    assert(cr_creg_read_val == FLAGS0);
                    read_creg(CR_SUBCYCLE);
                end
                // wait a cycle

                55:
                begin
                    // Check subcycle
                    assert(cr_creg_read_val == 32'(TRAP_SUBCYCLE0));
                    read_creg(CR_SCRATCHPAD0);
                end
                // wait cycle

                57:
                begin
                    assert(cr_creg_read_val == SCRATCHPAD0_1);
                    read_creg(CR_SCRATCHPAD1);
                end
                // wait cycle

                59: assert(cr_creg_read_val == SCRATCHPAD1_1);

                // eret from trap
                60: wb_eret <= 1;
                // wait cycle

                62:
                begin
                    // Old flags are restored
                    assert(cr_interrupt_en[0]);
                    assert(cr_mmu_en[0]);
                    assert(!cr_supervisor_en[0]);

                    // Ensure other flags are unaffected
                    assert(!cr_mmu_en[1]);
                    assert(!cr_mmu_en[2]);
                    assert(!cr_mmu_en[3]);
                    assert(cr_supervisor_en[1]);
                    assert(cr_supervisor_en[2]);
                    assert(cr_supervisor_en[3]);
                    assert(!cr_interrupt_en[1]);
                    assert(!cr_interrupt_en[2]);
                    assert(!cr_interrupt_en[3]);
                end

                64: read_creg(CR_FLAGS);
                // wait a cycle

                66:
                begin
                    assert(cr_creg_read_val == FLAGS0);
                    read_creg(CR_SCRATCHPAD0);
                end
                // wait cycle

                68:
                begin
                    assert(cr_creg_read_val == SCRATCHPAD0_0);
                    read_creg(CR_SCRATCHPAD1);
                end
                // wait cycle

                70: assert(cr_creg_read_val == SCRATCHPAD1_0);

                71:
                begin
                    $display("PASS");
                    $finish;
                end

            endcase
        end
    end
endmodule
