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

module test_ifetch_data_stage(input clk, input reset);
    localparam VADDR0 = 32'h80000000;
    localparam PADDR0 = 32'h1000;
    localparam PADDR1 = 32'h2000;
    localparam VADDR1 = 32'h1004;

    logic ift_instruction_requested;
    l1i_addr_t ift_pc_paddr;
    scalar_t ift_pc_vaddr;
    local_thread_idx_t ift_thread_idx;
    logic ift_tlb_hit;
    logic ift_tlb_present;
    logic ift_tlb_executable;
    logic ift_tlb_supervisor;
    l1i_tag_t ift_tag[`L1D_WAYS];
    logic ift_valid[`L1D_WAYS];
    logic ifd_update_lru_en;
    l1i_way_idx_t ifd_update_lru_way;
    logic ifd_near_miss;
    logic l2i_idata_update_en;
    l1i_way_idx_t l2i_idata_update_way;
    l1i_set_idx_t l2i_idata_update_set;
    cache_line_data_t l2i_idata_update_data;
    logic[`L1I_WAYS - 1:0] l2i_itag_update_en;
    l1i_set_idx_t l2i_itag_update_set;
    l1i_tag_t l2i_itag_update_tag;
    logic ifd_cache_miss;
    cache_line_index_t ifd_cache_miss_paddr;
    local_thread_idx_t ifd_cache_miss_thread_idx;
    logic cr_supervisor_en[`THREADS_PER_CORE];
    scalar_t ifd_instruction;
    logic ifd_instruction_valid;
    scalar_t ifd_pc;
    local_thread_idx_t ifd_thread_idx;
    logic ifd_alignment_fault;
    logic ifd_tlb_miss;
    logic ifd_supervisor_fault;
    logic ifd_page_fault;
    logic ifd_executable_fault;
    logic wb_rollback_en;
    local_thread_idx_t wb_rollback_thread_idx;
    logic ifd_perf_icache_hit;
    logic ifd_perf_icache_miss;
    logic ifd_perf_itlb_miss;
    logic core_selected_debug;
    logic dbg_halt;
    scalar_t dbg_instruction_inject;
    logic dbg_instruction_inject_en;
    local_thread_idx_t dbg_thread;
    int cycle;

    ifetch_data_stage ifetch_data_stage(.*);

    task cache_hit(input int vaddr, input int paddr);
        ift_instruction_requested <= 1;
        ift_pc_vaddr <= vaddr;
        ift_pc_paddr <= paddr;
        ift_tlb_hit <= 1;
        ift_valid[0] <= 1;
        ift_valid[1] <= 0;
        ift_valid[2] <= 0;
        ift_valid[3] <= 0;
        ift_tlb_present <= 1;
        ift_tlb_executable <= 1;
        ift_tlb_supervisor <= 0;
        ift_tag[0] <= l1i_tag_t'(paddr >> (32 - ICACHE_TAG_BITS));
    endtask


    always @(posedge clk, posedge reset)
    begin
        if (reset)
        begin
            cycle <= 0;
            cr_supervisor_en[0] <= 0;
            cr_supervisor_en[1] <= 0;
            cr_supervisor_en[2] <= 0;
            cr_supervisor_en[3] <= 0;
        end
        else
        begin
            // Default values
            ift_instruction_requested <= 0;
            l2i_idata_update_en <= 0;
            l2i_itag_update_en <= 0;
            wb_rollback_en <= 0;
            core_selected_debug <= 0;
            dbg_halt <= 0;
            dbg_instruction_inject_en <= 0;
            ift_tlb_hit <= 0;
            ift_tlb_present <= 0;
            ift_tlb_executable <= 0;
            ift_tlb_supervisor <= 0;

            cycle <= cycle + 1;
            unique0 case (cycle)
                // Cache hit, user thread accessing a user page
                0:
                begin
                    ift_instruction_requested <= 1;
                    ift_pc_vaddr <= VADDR0;
                    ift_pc_paddr <= PADDR0;
                    ift_tlb_hit <= 1;
                    ift_tlb_present <= 1;
                    ift_tlb_executable <= 1;
                    ift_tlb_supervisor <= 0;
                    ift_valid[0] <= 1;
                    ift_valid[1] <= 0;
                    ift_valid[2] <= 0;
                    ift_valid[3] <= 0;
                    ift_tag[0] <= l1i_tag_t'(PADDR0 >> (32 - ICACHE_TAG_BITS));
                end

                // Cache miss is asserted combinationally the same cycle it
                // receives a request.
                1: assert (!ifd_cache_miss);

                2:
                begin
                    assert (!ifd_cache_miss);
                    assert(ifd_instruction_valid);
                    assert(ifd_pc == VADDR0);
                    assert(!ifd_alignment_fault);
                    assert(!ifd_tlb_miss);
                    assert(!ifd_supervisor_fault);
                    assert(!ifd_page_fault);
                    assert(!ifd_executable_fault);

                    // Cache miss
                    // Modify tag to make this a miss
                    cache_hit(VADDR0, PADDR0);
                    ift_tag[0] <= l1i_tag_t'(PADDR1 >> (32 - ICACHE_TAG_BITS));
                end

                3: assert (ifd_cache_miss);

                4:
                begin
                    assert(!ifd_cache_miss);
                    assert(!ifd_instruction_valid);
                    assert(!ifd_alignment_fault);
                    assert(!ifd_tlb_miss);
                    assert(!ifd_supervisor_fault);
                    assert(!ifd_page_fault);
                    assert(!ifd_executable_fault);

                    // TLB miss
                    ift_instruction_requested <= 1;
                    ift_pc_vaddr <= VADDR0;
                    ift_pc_paddr <= PADDR0;
                    ift_tlb_hit <= 0;
                end

                // Ensure this doesn't spuriously trigger a cache miss (we can't
                // know if it is a cache miss because there was a TLB miss).
                5: assert (!ifd_cache_miss);

                6:
                begin
                    assert(!ifd_cache_miss);
                    assert(!ifd_instruction_valid);
                    assert(!ifd_alignment_fault);
                    assert(ifd_tlb_miss);
                    assert(!ifd_supervisor_fault);
                    assert(!ifd_page_fault);
                    assert(!ifd_executable_fault);

                    // Page fault
                    cache_hit(VADDR0, PADDR0);
                    ift_tlb_present <= 0;
                end

                7: assert (!ifd_cache_miss);

                8:
                begin
                    assert (!ifd_cache_miss);
                    // Ignore ifd_instructon_valid when a fault is set.
                    assert(!ifd_alignment_fault);
                    assert(!ifd_tlb_miss);
                    assert(!ifd_supervisor_fault);
                    assert(ifd_page_fault);
                    assert(!ifd_executable_fault);

                    // Supervisor fault
                    cache_hit(VADDR0, PADDR0);
                    cr_supervisor_en[0] = 0;
                    ift_tlb_supervisor <= 1;
                end

                9: assert (!ifd_cache_miss);

                10:
                begin
                    assert (!ifd_cache_miss);
                    // Ignore ifd_instructon_valid when a fault is set.
                    assert(!ifd_alignment_fault);
                    assert(!ifd_tlb_miss);
                    assert(ifd_supervisor_fault);
                    assert(!ifd_page_fault);
                    assert(!ifd_executable_fault);

                    // Page not executable (valid, tag, and paddr flags are retained
                    // from above).
                    cache_hit(VADDR0, PADDR0);
                    ift_tlb_executable <= 0;
                end

                11: assert (!ifd_cache_miss);

                12:
                begin
                    assert (!ifd_cache_miss);
                    // Ignore ifd_instructon_valid when a fault is set.
                    assert(!ifd_alignment_fault);
                    assert(!ifd_tlb_miss);
                    assert(!ifd_supervisor_fault);
                    assert(!ifd_page_fault);
                    assert(ifd_executable_fault);

                    // Page is supervisor, but we are also in supervisor mode. This
                    // shoudn't raise a fault.
                    cache_hit(VADDR0, PADDR0);
                    cr_supervisor_en[0] = 1;
                    ift_tlb_present <= 1;
                    ift_tlb_executable <= 0;
                    ift_tlb_supervisor <= 0;
                end


                13: assert (!ifd_cache_miss);

                14:
                begin
                    assert (!ifd_cache_miss);
                    assert(ifd_instruction_valid);
                    assert(!ifd_alignment_fault);
                    assert(!ifd_tlb_miss);
                    assert(!ifd_supervisor_fault);
                    assert(!ifd_page_fault);
                    assert(ifd_executable_fault);

                    // Cache near miss. The response for the missed line
                    // comes the same cycle the miss occurs.
                    cache_hit(VADDR0, PADDR0);
                    ift_valid[0] <= 0;  // force miss
                    l2i_itag_update_en <= 1;
                    l2i_itag_update_set <= l1i_set_idx_t'(VADDR0 >> CACHE_LINE_OFFSET_WIDTH);
                    l2i_itag_update_tag <= l1i_tag_t'(PADDR0 >> (32 - ICACHE_TAG_BITS));
                end

                15:
                begin
                    assert (!ifd_cache_miss);
                    assert(ifd_near_miss);  // This restarts the instruction
                end

                16:
                begin
                    // Ensure no valid instruction comes out in this case
                    assert(!ifd_cache_miss);
                    assert(!ifd_instruction_valid);
                end

                ////////////////////////////////////////////////////////////
                // Test rollbacks
                // When a rollback occurs, this should not raise any traps.
                ////////////////////////////////////////////////////////////
                17:
                begin
                    // Cache miss
                    // Modify tag to make this a miss
                    cache_hit(VADDR0, PADDR0);
                    ift_tag[0] <= l1i_tag_t'(PADDR1 >> (32 - ICACHE_TAG_BITS));
                    wb_rollback_en <= 1;
                end

                18: assert(!ifd_cache_miss);

                19:
                begin
                    assert(!ifd_instruction_valid);

                    // TLB miss
                    ift_instruction_requested <= 1;
                    ift_pc_vaddr <= VADDR0;
                    ift_pc_paddr <= PADDR0;
                    ift_tlb_hit <= 0;
                    wb_rollback_en <= 1;
                end

                20: assert(!ifd_cache_miss);

                21:
                begin
                    assert(!ifd_instruction_valid);
                    assert(!ifd_tlb_miss);

                    // Page fault
                    cache_hit(VADDR0, PADDR0);
                    ift_tlb_present <= 0;
                    wb_rollback_en <= 1;
                end

                22: assert(!ifd_cache_miss);

                23:
                begin
                    assert(!ifd_instruction_valid);
                    assert(!ifd_page_fault);

                    // Supervisor fault
                    cr_supervisor_en[0] = 0;
                    ift_tlb_supervisor <= 1;
                end

                24: assert(!ifd_cache_miss);

                25:
                begin
                    assert(!ifd_instruction_valid);
                    assert(!ifd_supervisor_fault);

                    // Page not executable
                    ift_tlb_executable <= 0;
                end

                26: assert(!ifd_cache_miss);

                27:
                begin
                    assert(!ifd_instruction_valid);
                    assert(!ifd_executable_fault);
                end

                28:
                begin
                    $display("PASS");
                    $finish;
                end
            endcase
        end
    end
endmodule
