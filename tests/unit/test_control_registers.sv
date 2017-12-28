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

module test_control_registers(input clk, input reset);
    localparam SCRATCHPAD0_0 = 32'h47aef111;
    localparam SCRATCHPAD1_0 = 32'hb74b7b47;
    localparam SCRATCHPAD0_1 = 32'h44fc17df;
    localparam SCRATCHPAD1_1 = 32'h35c1e57c;
    localparam SCRATCHPAD0_2 = 32'h826109b1;
    localparam SCRATCHPAD1_2 = 32'h91f13a15;
    localparam OTHER_THREAD_SCRATCHPAD = 32'h75458549;
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
    localparam TRAP_VADDR0 = 32'h494d1bcb;
    localparam TRAP_VADDR1 = 32'hf8a8428a;
    localparam NUM_INTERRUPTS = 16;
    localparam TRAP_HANDLER_VAL = 32'h71d09fec;
    localparam TLB_MISS_HANDLER_VAL = 32'h20685cad;
    localparam ASID_VAL = 8'd15;
    localparam JTAG_DATA_VAL0 = 32'hfc982951;
    localparam JTAG_DATA_VAL1 = 32'h7fc44607;

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
    scalar_t ocd_data_from_host;
    logic ocd_data_update;
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

    task raise_trap(input trap_type_t trap_type, input int pc, input subcycle_t subcycle,
            input scalar_t access_addr);
        wb_trap <= 1;
        wb_trap_cause <= 6'(trap_type);
        wb_trap_pc <= pc;
        wb_rollback_thread_idx <= 0;
        wb_trap_subcycle <= subcycle;
        wb_trap_access_vaddr <= access_addr;
    endtask

    always_ff @(posedge clk, posedge reset)
    begin
        if (reset)
        begin
            cycle <= 0;
            dt_thread_idx <= 0;
            interrupt_req <= '0;
        end
        else
        begin
            // Default values for control signals
            dd_creg_write_en <= 0;
            dd_creg_read_en <= 0;
            wb_trap <= 0;
            wb_eret <= 0;
            ocd_data_update <= 0;

            // There are deliberately gaps in the cycle count sequences below
            // to make it easier to add new actions to the test.
            cycle <= cycle + 1;
            unique0 case (cycle)
                ////////////////////////////////////////////////////////////
                // Test taking and returning from traps, ensuring state is
                // saved and restored correctly.
                ////////////////////////////////////////////////////////////

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
                3:
                begin
                    // Set another threads scratchpad to ensure the
                    // subsequent operations don't affect it.
                    dt_thread_idx <= 1;
                    write_creg(CR_SCRATCHPAD0, OTHER_THREAD_SCRATCHPAD);
                end

                // Enable the MMU, switch to user mode.
                4:
                begin
                    dt_thread_idx <= 0;
                    write_creg(CR_FLAGS, FLAGS0);
                end
                // Wait cycle

                6:
                begin
                    assert(cr_interrupt_en[0]);
                    assert(cr_mmu_en[0]);
                    assert(!cr_supervisor_en[0]);
                end

                // Take a trap
                8: raise_trap(TRAP_CAUSE0, PC0, TRAP_SUBCYCLE0, TRAP_VADDR0);
                // wait cycle

                10:
                begin
                    // The trap will turn off interrupts and switch to
                    // supervisor mode.
                    assert(!cr_interrupt_en[0]);
                    assert(cr_mmu_en[0]);
                    assert(cr_supervisor_en[0]);
                    assert(cr_eret_subcycle[0] == TRAP_SUBCYCLE0);

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

                11: read_creg(CR_TRAP_PC);
                // wait a cycle

                13:
                begin
                    assert(cr_creg_read_val == PC0);
                    read_creg(CR_FLAGS);
                end
                // wait a cycle

                15:
                begin
                    assert(cr_creg_read_val == FLAGS1);
                    read_creg(CR_TRAP_CAUSE);
                end
                // wait a cycle

                17:
                begin
                    assert(cr_creg_read_val == 32'(TRAP_CAUSE0));
                    read_creg(CR_SAVED_FLAGS);
                end
                // wait a cycle

                19:
                begin
                    assert(cr_creg_read_val == FLAGS0);
                    read_creg(CR_SUBCYCLE);
                end
                // wait a cycle

                21:
                begin
                    // Check subcycle
                    assert(cr_creg_read_val == 32'(TRAP_SUBCYCLE0));
                    read_creg(CR_TRAP_ADDRESS);
                end
                // wait a cycle

                23: assert(cr_creg_read_val == TRAP_VADDR0);

                // set scratchpad registers again
                24: write_creg(CR_SCRATCHPAD0, SCRATCHPAD0_1);
                25: write_creg(CR_SCRATCHPAD1, SCRATCHPAD1_1);

                // read the other threads scratchpad to ensure it is
                // preserved.
                26:
                begin
                    dt_thread_idx <= 1;
                    read_creg(CR_SCRATCHPAD0);
                end
                // wait cycle

                28:
                begin
                    assert(cr_creg_read_val == OTHER_THREAD_SCRATCHPAD);
                    dt_thread_idx <= 0;
                end

                // take a TLB miss trap
                40: raise_trap(TRAP_CAUSE1, PC1, TRAP_SUBCYCLE1, TRAP_VADDR1);
                // Wait cycle

                42:
                begin
                    // A TLB miss will turn off the MMU and switch to
                    // supervisor mode.
                    assert(!cr_interrupt_en[0]);
                    assert(!cr_mmu_en[0]);
                    assert(cr_supervisor_en[0]);
                    assert(cr_eret_subcycle[0] == TRAP_SUBCYCLE1);

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

                44:
                begin
                    assert(cr_creg_read_val == PC1);
                    read_creg(CR_FLAGS);
                end
                // wait cycle

                46:
                begin
                    // flags reflect interrupt/super values from above
                    assert(cr_creg_read_val == FLAGS2);
                    read_creg(CR_TRAP_CAUSE);
                end
                // wait cycle

                48:
                begin
                    assert(cr_creg_read_val == 32'(TRAP_CAUSE1));
                    read_creg(CR_SAVED_FLAGS);
                end
                // wait cycle

                50:
                begin
                    assert(cr_creg_read_val == FLAGS1);
                    read_creg(CR_SUBCYCLE);
                end
                // wait cycle

                52:
                begin
                    assert(cr_creg_read_val == 32'(TRAP_SUBCYCLE1));
                    read_creg(CR_TRAP_ADDRESS);
                end
                // wait cycle

                54: assert(cr_creg_read_val == TRAP_VADDR1);

                // set scratchpad registers
                55: write_creg(CR_SCRATCHPAD0, SCRATCHPAD0_2);
                56: write_creg(CR_SCRATCHPAD1, SCRATCHPAD1_2);

                // read back scratchpad registers
                57: read_creg(CR_SCRATCHPAD0);
                // wait cycle

                59:
                begin
                    assert(cr_creg_read_val == SCRATCHPAD0_2);
                    read_creg(CR_SCRATCHPAD1);
                end
                // wait cycle

                61: assert(cr_creg_read_val == SCRATCHPAD1_2);

                // eret from TLB miss
                70: wb_eret <= 1;
                // wait cycle

                72:
                begin
                    // Old flags are restored, MMU is enabled again
                    assert(!cr_interrupt_en[0]);
                    assert(cr_mmu_en[0]);
                    assert(cr_supervisor_en[0]);
                    assert(cr_eret_subcycle[0] == TRAP_SUBCYCLE0);

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

                // read the other threads scratchpad to ensure it is
                // preserved.
                74:
                begin
                    dt_thread_idx <= 1;
                    read_creg(CR_SCRATCHPAD0);
                end
                // wait cycle

                76:
                begin
                    assert(cr_creg_read_val == OTHER_THREAD_SCRATCHPAD);
                    dt_thread_idx <= 0;
                end

                77: read_creg(CR_TRAP_PC);
                // wait a cycle

                79:
                begin
                    assert(cr_creg_read_val == PC0);
                    read_creg(CR_FLAGS);
                end
                // wait a cycle

                81:
                begin
                    assert(cr_creg_read_val == FLAGS1);
                    read_creg(CR_TRAP_CAUSE);
                end
                // wait a cycle

                83:
                begin
                    assert(cr_creg_read_val == 32'(TRAP_CAUSE0));
                    read_creg(CR_SAVED_FLAGS);
                end
                // wait a cycle

                85:
                begin
                    assert(cr_creg_read_val == FLAGS0);
                    read_creg(CR_SUBCYCLE);
                end
                // wait a cycle

                87:
                begin
                    // Check subcycle
                    assert(cr_creg_read_val == 32'(TRAP_SUBCYCLE0));
                    read_creg(CR_SCRATCHPAD0);
                end
                // wait cycle

                89:
                begin
                    assert(cr_creg_read_val == SCRATCHPAD0_1);
                    read_creg(CR_SCRATCHPAD1);
                end
                // wait cycle

                91:
                begin
                    assert(cr_creg_read_val == SCRATCHPAD1_1);
                    read_creg(CR_TRAP_ADDRESS);
                end
                // wait cycle

                93: assert(cr_creg_read_val == TRAP_VADDR0);

                // eret from trap
                100: wb_eret <= 1;
                // wait cycle

                102:
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

                104: read_creg(CR_FLAGS);
                // wait a cycle

                106:
                begin
                    assert(cr_creg_read_val == FLAGS0);
                    read_creg(CR_SCRATCHPAD0);
                end
                // wait cycle

                108:
                begin
                    assert(cr_creg_read_val == SCRATCHPAD0_0);
                    read_creg(CR_SCRATCHPAD1);
                end
                // wait cycle

                110: assert(cr_creg_read_val == SCRATCHPAD1_0);

                ////////////////////////////////////////////////////////////
                // Test interrupt latching
                ////////////////////////////////////////////////////////////

                // int 0: level triggered, interrupt enabled, active (result 1)
                // int 1: edge triggered, interrupt enabled, active  (result 1)
                // int 3: edge triggered, interrupt enabled, not active (result 0)
                // int 4: edge triggered, interrupt not enabled, active (result 0)
                // int 5: default config, active (result 0)
                120: write_creg(CR_INTERRUPT_MASK, 32'b0111);
                121: write_creg(CR_INTERRUPT_TRIGGER, 32'b0001);  // 0 is edge, 1 is level
                122: interrupt_req <= 16'b11011;
                123: interrupt_req <= 16'b10001;   // Keep level triggered high
                // wait cycle
                125:
                begin
                    assert(cr_interrupt_pending[0] == 1);
                    assert(cr_interrupt_pending[1] == 0);

                    read_creg(CR_INTERRUPT_PENDING);
                end
                // wait cycle

                127:
                begin
                    assert(cr_creg_read_val == 32'b0011);
                    interrupt_req <= 16'b0000;
                end
                // wait cycle

                129:
                begin
                    assert(cr_interrupt_pending[0] == 1);

                    read_creg(CR_INTERRUPT_PENDING);
                end
                // wait cycle

                131:
                begin
                    // The level triggered interrupt goes to zero, but
                    // the edge triggered is still active
                    assert(cr_creg_read_val == 32'b0010);

                    write_creg(CR_INTERRUPT_ACK, 32'b1111);
                end
                // wait cycle

                133:
                begin
                    // no interrupts pending
                    assert(cr_interrupt_pending[0] == 0);

                    read_creg(CR_INTERRUPT_PENDING);
                end
                // wait cycle

                // Edge triggered interrupt should be cleared by ack.
                135: assert(cr_creg_read_val == 32'b0000);

                ////////////////////////////////////////////////////////////
                // Other misc tests
                ////////////////////////////////////////////////////////////

                // Read thread ID registers for all threads
                150: read_creg(CR_THREAD_ID);
                // wait cycle
                152:
                begin
                    assert(cr_creg_read_val == 0);

                    dt_thread_idx <= 1;
                    read_creg(CR_THREAD_ID);
                end
                // wait cycle

                154:
                begin
                    assert(cr_creg_read_val == 1);

                    dt_thread_idx <= 2;
                    read_creg(CR_THREAD_ID);
                end
                // wait cycle

                156:
                begin
                    assert(cr_creg_read_val == 2);

                    dt_thread_idx <= 3;
                    read_creg(CR_THREAD_ID);
                end
                // wait cycle

                158:
                begin
                    assert(cr_creg_read_val == 3);
                    dt_thread_idx <= 0;
                end

                // Set trap handler
                159: write_creg(CR_TRAP_HANDLER, TRAP_HANDLER_VAL);
                160: write_creg(CR_TLB_MISS_HANDLER, TLB_MISS_HANDLER_VAL);
                // wait cycle

                162:
                begin
                    assert(cr_trap_handler == TRAP_HANDLER_VAL);
                    assert(cr_tlb_miss_handler == TLB_MISS_HANDLER_VAL);
                end

                163: write_creg(CR_CURRENT_ASID, 32'(ASID_VAL));
                // wait cycle

                165:
                begin
                    assert(cr_current_asid[0] == ASID_VAL);
                    write_creg(CR_JTAG_DATA, JTAG_DATA_VAL0);
                end
                // wait cycle

                167:
                begin
                    assert(cr_data_to_host == JTAG_DATA_VAL0);
                    ocd_data_from_host <= JTAG_DATA_VAL1;
                    ocd_data_update <= 1;
                end
                // wait cycle

                169: read_creg(CR_JTAG_DATA);
                // wait cycle

                171: assert(cr_creg_read_val == JTAG_DATA_VAL1);

                172:
                begin
                    $display("PASS");
                    $finish;
                end
            endcase
        end
    end
endmodule
