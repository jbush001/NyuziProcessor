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


`include "defines.svh"

import defines::*;

//
// Storage for control registers.
// Also contains interrupt handling logic.
//

module control_registers
    #(parameter CORE_ID = 0,
    parameter NUM_INTERRUPTS = 16,
    parameter NUM_PERF_EVENTS = 8,
    parameter EVENT_IDX_WIDTH = $clog2(NUM_PERF_EVENTS))
    (input                                  clk,
    input                                   reset,

    input [NUM_INTERRUPTS - 1:0]            interrupt_req,

    // To multiple stages
    output scalar_t                         cr_eret_address[`THREADS_PER_CORE],
    output logic                            cr_mmu_en[`THREADS_PER_CORE],
    output logic                            cr_supervisor_en[`THREADS_PER_CORE],
    output logic[ASID_WIDTH - 1:0]          cr_current_asid[`THREADS_PER_CORE],

    // To nyuzi
    output logic[TOTAL_THREADS - 1:0]       cr_suspend_thread,
    output logic[TOTAL_THREADS - 1:0]       cr_resume_thread,

    // To instruction_decode_stage
    output logic[`THREADS_PER_CORE - 1:0]   cr_interrupt_pending,
    output local_thread_bitmap_t            cr_interrupt_en,

    // From dcache_data_stage
    // dd_xxx signals are unregistered. dt_thread_idx represents thread going into
    // dcache_data_stage)
    input local_thread_idx_t                dt_thread_idx,
    input                                   dd_creg_write_en,
    input                                   dd_creg_read_en,
    input control_register_t                dd_creg_index,
    input scalar_t                          dd_creg_write_val,

    // From writeback_stage
    input                                   wb_trap,
    input                                   wb_eret,
    input trap_cause_t                      wb_trap_cause,
    input scalar_t                          wb_trap_pc,
    input scalar_t                          wb_trap_access_vaddr,
    input local_thread_idx_t                wb_rollback_thread_idx,
    input subcycle_t                        wb_trap_subcycle,
    input syscall_index_t                   wb_syscall_index,

    // To writeback_stage
    output scalar_t                         cr_creg_read_val,
    output subcycle_t                       cr_eret_subcycle[`THREADS_PER_CORE],
    output scalar_t                         cr_trap_handler,
    output scalar_t                         cr_tlb_miss_handler,

    // To/from performance_counters
    output logic[EVENT_IDX_WIDTH - 1:0]     cr_perf_event_select0,
    output logic[EVENT_IDX_WIDTH - 1:0]     cr_perf_event_select1,
    input[63:0]                             perf_event_count0,
    input[63:0]                             perf_event_count1,

    // To/from on_chip_debugger
    input scalar_t                          ocd_data_from_host,
    input                                   ocd_data_update,
    output scalar_t                         cr_data_to_host);

    // One is for current state. Maximum nested traps is TRAP_LEVELS - 1.
    localparam TRAP_LEVELS = 3;

    typedef struct packed {
        logic supervisor_en;
        logic mmu_en;
        logic interrupt_en;
    } flags_t;

    typedef struct packed {
        flags_t flags;
        scalar_t scratchpad0;
        scalar_t scratchpad1;

        // Information about last trap
        trap_cause_t trap_cause;
        scalar_t trap_pc;
        scalar_t trap_access_addr;
        subcycle_t trap_subcycle;
        syscall_index_t syscall_index;
    } trap_state_t;

    trap_state_t trap_state[`THREADS_PER_CORE][TRAP_LEVELS];
    scalar_t page_dir_base[`THREADS_PER_CORE];
    scalar_t cycle_count;
    logic[NUM_INTERRUPTS - 1:0] interrupt_mask[`THREADS_PER_CORE];
    logic[NUM_INTERRUPTS - 1:0] interrupt_pending[`THREADS_PER_CORE];
    logic[NUM_INTERRUPTS - 1:0] interrupt_edge_latched[`THREADS_PER_CORE];
    logic[NUM_INTERRUPTS - 1:0] int_trigger_type;
    logic[NUM_INTERRUPTS - 1:0] interrupt_req_prev;
    logic[NUM_INTERRUPTS - 1:0] interrupt_edge;
    scalar_t jtag_data;

    assign cr_data_to_host = jtag_data;

    always_ff @(posedge clk, posedge reset)
    begin
        if (reset)
        begin
            for (int thread_idx = 0; thread_idx < `THREADS_PER_CORE; thread_idx++)
            begin
                trap_state[thread_idx][0] <= '0;
                trap_state[thread_idx][0].flags.supervisor_en <= 1'b1;
                cr_current_asid[thread_idx] <= '0;
                page_dir_base[thread_idx] <= '0;
                interrupt_mask[thread_idx] <= '0;
            end

            // AUTORESET gets confused by all of the structure accesses
            // below, so the resets are all manual here. Be sure to add all registers
            // accessed below here.
            jtag_data <= '0;
            cr_tlb_miss_handler <= '0;
            cr_trap_handler <= '0;
            cycle_count <= '0;
            int_trigger_type <= '0;
            cr_suspend_thread <= '0;
            cr_resume_thread <= '0;
            cr_perf_event_select0 <= '0;
            cr_perf_event_select1 <= '0;
        end
        else
        begin
            // Ensure a read and write don't occur in the same cycle
            assert(!(dd_creg_write_en && dd_creg_read_en));

            // A fault and eret are triggered from the same stage, so they
            // must not occur simultaneously (an eret can raise a fault if it
            // is not in supervisor mode, but wb_eret should not be asserted
            // in that case)
            assert(!(wb_trap && wb_eret));

            cycle_count <= cycle_count + 1;

            if (wb_trap)
            begin
                // Copy trap state
                for (int level = 0; level < TRAP_LEVELS - 1; level++)
                    trap_state[wb_rollback_thread_idx][level + 1] <= trap_state[wb_rollback_thread_idx][level];

                // Dispatch fault
                trap_state[wb_rollback_thread_idx][0].trap_cause <= wb_trap_cause;
                trap_state[wb_rollback_thread_idx][0].trap_pc <= wb_trap_pc;
                trap_state[wb_rollback_thread_idx][0].trap_access_addr <= wb_trap_access_vaddr;
                trap_state[wb_rollback_thread_idx][0].syscall_index <= wb_syscall_index;
                trap_state[wb_rollback_thread_idx][0].trap_subcycle <= wb_trap_subcycle;
                trap_state[wb_rollback_thread_idx][0].flags.interrupt_en <= 0;    // Disable interrupts for this thread
                trap_state[wb_rollback_thread_idx][0].flags.supervisor_en <= 1;
                if (wb_trap_cause.trap_type == TT_TLB_MISS)
                    trap_state[wb_rollback_thread_idx][0].flags.mmu_en <= 0;
            end

            if (wb_eret)
            begin
                // Restore nested interrupt state
                for (int level = 0; level < TRAP_LEVELS - 1; level++)
                    trap_state[wb_rollback_thread_idx][level] <= trap_state[wb_rollback_thread_idx][level + 1];
            end

            //
            // Write logic
            //
            cr_suspend_thread <= '0;
            cr_resume_thread <= '0;

            if (dd_creg_write_en)
            begin
                unique case (dd_creg_index)
                    CR_FLAGS:             trap_state[dt_thread_idx][0].flags <= flags_t'(dd_creg_write_val);
                    CR_SAVED_FLAGS:       trap_state[dt_thread_idx][1].flags <= flags_t'(dd_creg_write_val);
                    CR_TRAP_PC:           trap_state[dt_thread_idx][0].trap_pc <= dd_creg_write_val;
                    CR_TRAP_HANDLER:      cr_trap_handler <= dd_creg_write_val;
                    CR_TLB_MISS_HANDLER:  cr_tlb_miss_handler <= dd_creg_write_val;
                    CR_SCRATCHPAD0:       trap_state[dt_thread_idx][0].scratchpad0 <= dd_creg_write_val;
                    CR_SCRATCHPAD1:       trap_state[dt_thread_idx][0].scratchpad1 <= dd_creg_write_val;
                    CR_SUBCYCLE:          trap_state[dt_thread_idx][0].trap_subcycle <= subcycle_t'(dd_creg_write_val);
                    CR_CURRENT_ASID:      cr_current_asid[dt_thread_idx] <= dd_creg_write_val[ASID_WIDTH - 1:0];
                    CR_PAGE_DIR:          page_dir_base[dt_thread_idx] <= dd_creg_write_val;
                    CR_INTERRUPT_ENABLE:  interrupt_mask[dt_thread_idx] <= dd_creg_write_val[NUM_INTERRUPTS - 1:0];
                    CR_INTERRUPT_TRIGGER: int_trigger_type <= dd_creg_write_val[NUM_INTERRUPTS - 1:0];
                    CR_JTAG_DATA:         jtag_data <= dd_creg_write_val;
                    CR_SUSPEND_THREAD:    cr_suspend_thread <= dd_creg_write_val[TOTAL_THREADS - 1:0];
                    CR_RESUME_THREAD:     cr_resume_thread <= dd_creg_write_val[TOTAL_THREADS - 1:0];
                    CR_PERF_EVENT_SELECT0: cr_perf_event_select0 <= dd_creg_write_val[EVENT_IDX_WIDTH - 1:0];
                    CR_PERF_EVENT_SELECT1: cr_perf_event_select1 <= dd_creg_write_val[EVENT_IDX_WIDTH - 1:0];
                    default:
                        ;
                endcase
            end
            else if (ocd_data_update)
                jtag_data <= ocd_data_from_host;
        end
    end

    always @(posedge clk, posedge reset)
    begin
        if (reset)
            interrupt_req_prev <= '0;
        else
            interrupt_req_prev <= interrupt_req;
    end

    assign interrupt_edge = interrupt_req & ~interrupt_req_prev;

    genvar thread_idx;
    generate
        for (thread_idx = 0; thread_idx < `THREADS_PER_CORE; thread_idx++)
        begin : interrupt_gen
            logic[NUM_INTERRUPTS - 1:0] interrupt_ack;
            logic do_interrupt_ack;

            assign do_interrupt_ack = dt_thread_idx == thread_idx
                && dd_creg_write_en
                && dd_creg_index == CR_INTERRUPT_ACK;
            assign interrupt_ack = {NUM_INTERRUPTS{do_interrupt_ack}}
                & dd_creg_write_val[NUM_INTERRUPTS - 1:0];
            assign cr_interrupt_en[thread_idx] = trap_state[thread_idx][0].flags.interrupt_en;
            assign cr_supervisor_en[thread_idx] = trap_state[thread_idx][0].flags.supervisor_en;
            assign cr_mmu_en[thread_idx] = trap_state[thread_idx][0].flags.mmu_en;
            assign cr_eret_subcycle[thread_idx] = trap_state[thread_idx][0].trap_subcycle;
            assign cr_eret_address[thread_idx] = trap_state[thread_idx][0].trap_pc;

            // interrupt_edge_latched is set when a [positive] edge triggered
            // interrupt occurs.
            always_ff @(posedge clk, posedge reset)
            begin
                if (reset)
                    interrupt_edge_latched[thread_idx] <= '0;
                else
                begin
                    interrupt_edge_latched[thread_idx] <=
                        (interrupt_edge_latched[thread_idx] & ~interrupt_ack)
                        | interrupt_edge;
                end
            end

            // If the trigger type is 1 (level triggered), interrupt pending is
            // determined by level. Otherwise check interrupt_latch, which stores
            // if an edge has been detected.
            assign interrupt_pending[thread_idx] = (int_trigger_type & interrupt_req)
                | (~int_trigger_type & interrupt_edge_latched[thread_idx]);

            // Output to pipeline indicates if any interrupts are pending for each
            // thread.
            assign cr_interrupt_pending[thread_idx] = |(interrupt_pending[thread_idx]
                & interrupt_mask[thread_idx]);
        end
    endgenerate

    always_ff @(posedge clk)
    begin
        //
        // Read logic
        //
        if (dd_creg_read_en)
        begin
            unique case (dd_creg_index)
                CR_FLAGS:             cr_creg_read_val <= scalar_t'(trap_state[dt_thread_idx][0].flags);
                CR_SAVED_FLAGS:       cr_creg_read_val <= scalar_t'(trap_state[dt_thread_idx][1].flags);
                CR_THREAD_ID:         cr_creg_read_val <= scalar_t'({CORE_ID, dt_thread_idx});
                CR_TRAP_PC:           cr_creg_read_val <= trap_state[dt_thread_idx][0].trap_pc;
                CR_TRAP_CAUSE:        cr_creg_read_val <= scalar_t'(trap_state[dt_thread_idx][0].trap_cause);
                CR_TRAP_HANDLER:      cr_creg_read_val <= cr_trap_handler;
                CR_TRAP_ADDRESS:      cr_creg_read_val <= trap_state[dt_thread_idx][0].trap_access_addr;
                CR_TLB_MISS_HANDLER:  cr_creg_read_val <= cr_tlb_miss_handler;
                CR_CYCLE_COUNT:       cr_creg_read_val <= cycle_count;
                CR_SCRATCHPAD0:       cr_creg_read_val <= trap_state[dt_thread_idx][0].scratchpad0;
                CR_SCRATCHPAD1:       cr_creg_read_val <= trap_state[dt_thread_idx][0].scratchpad1;
                CR_SUBCYCLE:          cr_creg_read_val <= scalar_t'(trap_state[dt_thread_idx][0].trap_subcycle);
                CR_CURRENT_ASID:      cr_creg_read_val <= scalar_t'(cr_current_asid[dt_thread_idx]);
                CR_PAGE_DIR:          cr_creg_read_val <= page_dir_base[dt_thread_idx];
                CR_INTERRUPT_PENDING: cr_creg_read_val <= scalar_t'(interrupt_pending[dt_thread_idx]
                                                          & interrupt_mask[dt_thread_idx]);
                CR_INTERRUPT_ENABLE:  cr_creg_read_val <= scalar_t'(interrupt_mask[dt_thread_idx]);
                CR_INTERRUPT_TRIGGER: cr_creg_read_val <= scalar_t'(int_trigger_type);
                CR_JTAG_DATA:         cr_creg_read_val <= jtag_data;
                CR_SYSCALL_INDEX:     cr_creg_read_val <= scalar_t'(trap_state[dt_thread_idx][0].syscall_index);
                CR_PERF_EVENT_COUNT0_L: cr_creg_read_val <= perf_event_count0[31:0];
                CR_PERF_EVENT_COUNT0_H: cr_creg_read_val <= perf_event_count0[63:32];
                CR_PERF_EVENT_COUNT1_L: cr_creg_read_val <= perf_event_count1[31:0];
                CR_PERF_EVENT_COUNT1_H: cr_creg_read_val <= perf_event_count1[63:32];
                default:              cr_creg_read_val <= 32'hffffffff;
            endcase
        end
    end
endmodule
