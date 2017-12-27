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

module test_dcache_data_stage(input clk, input reset);
    localparam NORMAL_ADDR = 'h80000020;
    localparam IO_ADDR = 'hffff0010;

    local_thread_bitmap_t dd_load_sync_pending;
    logic dt_instruction_valid;
    decoded_instruction_t dt_instruction;
    vector_mask_t dt_mask_value;
    local_thread_idx_t dt_thread_idx;
    l1d_addr_t dt_request_vaddr;
    l1d_addr_t dt_request_paddr;
    logic dt_tlb_hit;
    logic dt_tlb_present;
    logic dt_tlb_supervisor;
    logic dt_tlb_writable;
    vector_t dt_store_value;
    subcycle_t dt_subcycle;
    logic dt_valid[`L1D_WAYS];
    l1d_tag_t dt_tag[`L1D_WAYS];
    logic dd_update_lru_en;
    l1d_way_idx_t dd_update_lru_way;
    logic dd_io_write_en;
    logic dd_io_read_en;
    local_thread_idx_t dd_io_thread_idx;
    scalar_t dd_io_addr;
    scalar_t dd_io_write_value;
    logic dd_instruction_valid;
    decoded_instruction_t dd_instruction;
    vector_mask_t dd_lane_mask;
    local_thread_idx_t dd_thread_idx;
    l1d_addr_t dd_request_vaddr;
    subcycle_t dd_subcycle;
    logic dd_rollback_en;
    scalar_t dd_rollback_pc;
    cache_line_data_t dd_load_data;
    logic dd_suspend_thread;
    logic dd_io_access;
    logic dd_trap;
    trap_cause_t dd_trap_cause;
    logic cr_supervisor_en[`THREADS_PER_CORE];
    logic dd_creg_write_en;
    logic dd_creg_read_en;
    control_register_t dd_creg_index;
    scalar_t dd_creg_write_val;
    logic l2i_ddata_update_en;
    l1d_way_idx_t l2i_ddata_update_way;
    l1d_set_idx_t l2i_ddata_update_set;
    cache_line_data_t l2i_ddata_update_data;
    logic[`L1D_WAYS - 1:0] l2i_dtag_update_en_oh;
    l1d_set_idx_t l2i_dtag_update_set;
    l1d_tag_t l2i_dtag_update_tag;
    logic dd_cache_miss;
    cache_line_index_t dd_cache_miss_addr;
    local_thread_idx_t dd_cache_miss_thread_idx;
    logic dd_cache_miss_sync;
    logic dd_store_en;
    logic dd_flush_en;
    logic dd_membar_en;
    logic dd_iinvalidate_en;
    logic dd_dinvalidate_en;
    logic[CACHE_LINE_BYTES - 1:0] dd_store_mask;
    cache_line_index_t dd_store_addr;
    cache_line_data_t dd_store_data;
    local_thread_idx_t dd_store_thread_idx;
    logic dd_store_sync;
    cache_line_index_t dd_store_bypass_addr;
    local_thread_idx_t dd_store_bypass_thread_idx;
    logic wb_rollback_en;
    local_thread_idx_t wb_rollback_thread_idx;
    pipeline_sel_t wb_rollback_pipeline;
    logic dd_perf_dcache_hit;
    logic dd_perf_dcache_miss;
    logic dd_perf_store;
    logic dd_perf_dtlb_miss;
    int cycle;

    dcache_data_stage dcache_data_stage(.*);

    task cache_hit(input scalar_t address, input logic load);
        int hit_way = $random();

        dt_mask_value <= 16'hffff;
        dt_tlb_hit <= 1;
        dt_request_vaddr <= address;
        dt_request_paddr <= address;
        dt_tlb_present <= 1;
        dt_tlb_writable <= 1;
        dt_instruction_valid <= 1;
        dt_instruction.memory_access <= 1;
        dt_instruction.memory_access_type <= MEM_L;
        dt_instruction.load <= load;
        dt_valid[hit_way] <= 1;
        dt_tag[hit_way] <= DCACHE_TAG_BITS'(address >> (32 - DCACHE_TAG_BITS));
    endtask

    task cache_miss(input scalar_t address, input logic load);
        int request_tag = address >> (32 - DCACHE_TAG_BITS);

        dt_mask_value <= 16'hffff;
        dt_tlb_hit <= 1;
        dt_request_vaddr <= address;
        dt_request_paddr <= address;
        dt_tlb_present <= 1;
        dt_instruction_valid <= 1;
        dt_instruction.memory_access <= 1;
        dt_instruction.memory_access_type <= MEM_L;
        dt_instruction.load <= load;

        // tag matches, but valid bit is not set
        dt_tag[0] <= DCACHE_TAG_BITS'(request_tag);

        // Valid bit is set, but tag doesn't match
        dt_valid[1] <= 1;
        dt_tag[1] <= DCACHE_TAG_BITS'(request_tag ^ 32'hffffffff);
    endtask

    always_ff @(posedge clk, posedge reset)
    begin
        if (reset)
        begin
            cycle <= 0;
            dt_mask_value <= '0;
            dt_thread_idx <= '0;
            dt_store_value <= '0;
            dt_subcycle <= '0;

            for (int i = 0; i < `THREADS_PER_CORE; i++)
                cr_supervisor_en[i] <= '0;

            l2i_ddata_update_way <= '0;
            l2i_ddata_update_set <= '0;
            l2i_ddata_update_data <= '0;
            l2i_dtag_update_set <= '0;
            l2i_dtag_update_tag <= '0;
            wb_rollback_thread_idx <= '0;
            wb_rollback_pipeline <= '0;
        end
        else
        begin
            dt_instruction <= '0;
            l2i_ddata_update_en <= '0;
            l2i_dtag_update_en_oh <= '0;
            dt_instruction_valid <= '0;
            wb_rollback_en <= '0;
            dt_tlb_hit <= '0;
            dt_tlb_present <= '0;
            dt_tlb_supervisor <= '0;
            dt_tlb_writable <= '0;
            dt_request_vaddr <= '0;
            dt_request_paddr <= '0;
            for (int i = 0; i < `L1D_WAYS; i++)
            begin
                dt_valid[i] <= '0;
                dt_tag[i] <= '0;
            end

            cycle <= cycle + 1;
            unique0 case (cycle)
                ////////////////////////////////////////////////////////////
                // Cache hit, normal (non I/O) address, load
                ////////////////////////////////////////////////////////////

                0:  cache_hit(NORMAL_ADDR, 1);

                1:
                begin
                    assert(dd_update_lru_en);
                    assert(!dd_instruction_valid);

                    // These are registered, so they wouldn't be asserted even if
                    // this was valid, but check them anyway for sanity.
                    assert(!dd_io_write_en);
                    assert(!dd_io_read_en);
                    assert(!dd_creg_write_en);
                    assert(!dd_creg_read_en);
                    assert(!dd_store_en);
                    assert(!dd_flush_en);
                    assert(!dd_membar_en);
                    assert(!dd_iinvalidate_en);
                    assert(!dd_dinvalidate_en);
                    assert(!dd_cache_miss);
                    assert(!dd_trap);
                    assert(!dd_perf_dcache_hit);
                    assert(!dd_perf_dcache_miss);
                    assert(!dd_perf_store);
                    assert(!dd_perf_dtlb_miss);
                end

                2:
                begin
                    assert(!dd_trap);
                    assert(!dd_cache_miss);
                    assert(dd_instruction_valid);
                    assert(!dd_suspend_thread);
                    assert(!dd_rollback_en);
                    assert(dd_perf_dcache_hit);
                    assert(!dd_perf_dcache_miss);
                    assert(!dd_perf_store);
                    assert(!dd_perf_dtlb_miss);
                end

                ////////////////////////////////////////////////////////////
                // Normal store (there's no cache miss or hit, since
                // this is write through)
                ////////////////////////////////////////////////////////////

                3:  cache_hit(NORMAL_ADDR, 0);

                4:
                begin
                    assert(dd_update_lru_en);
                    assert(!dd_instruction_valid);
                    assert(!dd_io_write_en);
                    assert(!dd_io_read_en);
                    assert(!dd_creg_write_en);
                    assert(!dd_creg_read_en);
                    assert(dd_store_en);
                    assert(!dd_flush_en);
                    assert(!dd_membar_en);
                    assert(!dd_iinvalidate_en);
                    assert(!dd_dinvalidate_en);
                    assert(!dd_cache_miss);
                    assert(!dd_trap);
                    assert(!dd_perf_dcache_hit);
                    assert(!dd_perf_dcache_miss);
                    assert(!dd_perf_store);
                    assert(!dd_perf_dtlb_miss);
                end

                5:
                begin
                    assert(!dd_trap);
                    assert(!dd_cache_miss);
                    assert(dd_instruction_valid);
                    assert(!dd_suspend_thread);
                    assert(!dd_rollback_en);
                    assert(!dd_perf_dcache_hit);
                    assert(!dd_perf_dcache_miss);
                    assert(dd_perf_store);
                    assert(!dd_perf_dtlb_miss);
                end

                ////////////////////////////////////////////////////////////
                // I/O address load
                ////////////////////////////////////////////////////////////

                // We call cache_hit() for convenience, but the I/O transaction
                // ignores tags
                6:  cache_hit(IO_ADDR, 1);

                7:
                begin
                    assert(!dd_update_lru_en);
                    assert(!dd_instruction_valid);
                    assert(dd_io_read_en);
                    assert(!dd_io_write_en);
                    assert(!dd_creg_write_en);
                    assert(!dd_creg_read_en);
                    assert(!dd_store_en);
                    assert(!dd_flush_en);
                    assert(!dd_membar_en);
                    assert(!dd_iinvalidate_en);
                    assert(!dd_dinvalidate_en);
                    assert(!dd_cache_miss);
                    assert(!dd_trap);
                    assert(!dd_perf_dcache_hit);
                    assert(!dd_perf_dcache_miss);
                    assert(!dd_perf_store);
                    assert(!dd_perf_dtlb_miss);
                end

                8:
                begin
                    assert(!dd_trap);
                    assert(!dd_cache_miss);
                    assert(dd_instruction_valid);
                    assert(!dd_suspend_thread);
                    assert(!dd_rollback_en);
                    assert(!dd_perf_dcache_hit);
                    assert(!dd_perf_dcache_miss);
                    assert(!dd_perf_store);
                    assert(!dd_perf_dtlb_miss);
                end

                ////////////////////////////////////////////////////////////
                // I/O address store
                ////////////////////////////////////////////////////////////

                9:  cache_hit(IO_ADDR, 0);

                10:
                begin
                    assert(!dd_cache_miss);
                    assert(!dd_update_lru_en);
                    assert(!dd_instruction_valid);
                    assert(!dd_io_read_en);
                    assert(dd_io_write_en);
                    assert(!dd_creg_write_en);
                    assert(!dd_creg_read_en);
                    assert(!dd_store_en);
                    assert(!dd_flush_en);
                    assert(!dd_membar_en);
                    assert(!dd_iinvalidate_en);
                    assert(!dd_dinvalidate_en);
                    assert(!dd_cache_miss);
                    assert(!dd_trap);
                    assert(!dd_perf_dcache_hit);
                    assert(!dd_perf_dcache_miss);
                    assert(!dd_perf_store);
                    assert(!dd_perf_dtlb_miss);
                end

                11:
                begin
                    assert(!dd_trap);
                    assert(!dd_cache_miss);
                    assert(dd_instruction_valid);
                    assert(!dd_suspend_thread);
                    assert(!dd_rollback_en);
                    assert(!dd_perf_dcache_hit);
                    assert(!dd_perf_dcache_miss);
                    assert(!dd_perf_store);
                    assert(!dd_perf_dtlb_miss);
                end

                ////////////////////////////////////////////////////////////
                // Load cache miss
                ////////////////////////////////////////////////////////////

                12:  cache_miss(NORMAL_ADDR, 1);

                13:
                begin
                    assert(!dd_update_lru_en);
                    assert(!dd_instruction_valid);
                    assert(dd_cache_miss);

                    // These are registered, so they wouldn't be asserted even if
                    // this was valid, but check them anyway for sanity.
                    assert(!dd_io_write_en);
                    assert(!dd_io_read_en);
                    assert(!dd_creg_write_en);
                    assert(!dd_creg_read_en);
                    assert(!dd_store_en);
                    assert(!dd_flush_en);
                    assert(!dd_membar_en);
                    assert(!dd_iinvalidate_en);
                    assert(!dd_dinvalidate_en);
                    assert(!dd_trap);
                    assert(!dd_perf_dcache_hit);
                    assert(!dd_perf_dcache_miss);
                    assert(!dd_perf_store);
                    assert(!dd_perf_dtlb_miss);
                end

                14:
                begin
                    assert(!dd_trap);
                    assert(dd_instruction_valid);
                    assert(dd_suspend_thread);
                    assert(dd_rollback_en);
                    assert(!dd_perf_dcache_hit);
                    assert(dd_perf_dcache_miss);
                    assert(!dd_perf_store);
                    assert(!dd_perf_dtlb_miss);
                end

                // Since this is write through, there is no such thing
                // as a store cache miss.

                ////////////////////////////////////////////////////////////
                // TLB miss.
                ////////////////////////////////////////////////////////////

                // load, cached address
                // Set TLB bits so this would generate other faults, but
                // ensure those are ignored, since the TLB isn't valid.
                20:
                begin
                    cache_miss(NORMAL_ADDR, 1);
                    dt_tlb_hit <= 0;
                    dt_tlb_present <= 0;    // page fault
                    dt_tlb_supervisor <= 1; // supervisor fault
                    cr_supervisor_en[0] <= 1;
                    dt_tlb_writable <= 0;   // write fault
                end

                // Ensure no update side effects
                21:
                begin
                    assert(!dd_update_lru_en);
                    assert(!dd_instruction_valid);

                    // These are registered, so they wouldn't be asserted even if
                    // this was valid, but check them anyway for sanity.
                    assert(!dd_io_write_en);
                    assert(!dd_io_read_en);
                    assert(!dd_creg_write_en);
                    assert(!dd_creg_read_en);
                    assert(!dd_store_en);
                    assert(!dd_flush_en);
                    assert(!dd_membar_en);
                    assert(!dd_iinvalidate_en);
                    assert(!dd_dinvalidate_en);
                    assert(!dd_cache_miss);
                    assert(!dd_trap);
                    assert(!dd_perf_dcache_hit);
                    assert(!dd_perf_dcache_miss);
                    assert(!dd_perf_store);
                    assert(!dd_perf_dtlb_miss);
                end

                // Check that the TLB miss fault is raised
                22:
                begin
                    assert(dd_trap);
                    assert(dd_trap_cause == {1'b1, 1'b0, TT_TLB_MISS});
                    assert(!dd_cache_miss);
                    assert(dd_instruction_valid);
                    assert(!dd_suspend_thread);
                    assert(!dd_rollback_en); // This is only for cache misses
                    assert(!dd_perf_dcache_hit);
                    assert(!dd_perf_dcache_miss);
                    assert(!dd_perf_store);
                    assert(dd_perf_dtlb_miss);
                end

                // Same thing, except with a store, cached address
                23:
                begin
                    cache_miss(NORMAL_ADDR, 0);
                    dt_tlb_hit <= 0;
                    dt_tlb_present <= 0;    // page fault
                    dt_tlb_supervisor <= 1; // supervisor fault
                    cr_supervisor_en[0] <= 1;
                end

                // Ensure no update side effects
                24:
                begin
                    assert(!dd_update_lru_en);
                    assert(!dd_instruction_valid);

                    // These are registered, so they wouldn't be asserted even if
                    // this was valid, but check them anyway for sanity.
                    assert(!dd_io_write_en);
                    assert(!dd_io_read_en);
                    assert(!dd_creg_write_en);
                    assert(!dd_creg_read_en);
                    assert(!dd_store_en);
                    assert(!dd_flush_en);
                    assert(!dd_membar_en);
                    assert(!dd_iinvalidate_en);
                    assert(!dd_dinvalidate_en);
                    assert(!dd_cache_miss);
                    assert(!dd_trap);
                    assert(!dd_perf_dcache_hit);
                    assert(!dd_perf_dcache_miss);
                    assert(!dd_perf_store);
                    assert(!dd_perf_dtlb_miss);
                end

                // Check that the TLB miss fault is raised
                25:
                begin
                    assert(dd_trap);
                    assert(dd_trap_cause == {1'b1, 1'b1, TT_TLB_MISS});
                    assert(!dd_cache_miss);
                    assert(dd_instruction_valid);
                    assert(!dd_suspend_thread);
                    assert(!dd_rollback_en); // This is only for cache misses
                    assert(!dd_perf_dcache_hit);
                    assert(!dd_perf_dcache_miss);
                    assert(!dd_perf_store);
                    assert(dd_perf_dtlb_miss);
                end

                // Load, to I/O address. Ensure it raises a trap the same way
                26:
                begin
                    cache_hit(IO_ADDR, 1);
                    dt_tlb_hit <= 0;
                    dt_tlb_present <= 0;    // page fault
                    dt_tlb_supervisor <= 1; // supervisor fault
                    cr_supervisor_en[0] <= 1;
                    dt_tlb_writable <= 0;   // write fault
                end

                27:
                begin
                    assert(!dd_update_lru_en);
                    assert(!dd_instruction_valid);
                    assert(!dd_io_write_en);
                    assert(!dd_io_read_en);
                    assert(!dd_creg_write_en);
                    assert(!dd_creg_read_en);
                    assert(!dd_store_en);
                    assert(!dd_flush_en);
                    assert(!dd_membar_en);
                    assert(!dd_iinvalidate_en);
                    assert(!dd_dinvalidate_en);
                    assert(!dd_cache_miss);
                    assert(!dd_trap);
                    assert(!dd_perf_dcache_hit);
                    assert(!dd_perf_dcache_miss);
                    assert(!dd_perf_store);
                    assert(!dd_perf_dtlb_miss);
                end

                // Check that the TLB miss fault is raised
                28:
                begin
                    assert(dd_trap);
                    assert(dd_trap_cause == {1'b1, 1'b0, TT_TLB_MISS});
                    assert(!dd_cache_miss);
                    assert(dd_instruction_valid);
                    assert(!dd_suspend_thread);
                    assert(!dd_rollback_en); // This is only for cache misses
                    assert(!dd_perf_dcache_hit);
                    assert(!dd_perf_dcache_miss);
                    assert(!dd_perf_store);
                    assert(dd_perf_dtlb_miss);
                end

                // Same thing, except with a store, uncached (I/O) address
                29:
                begin
                    cache_hit(IO_ADDR, 0);
                    dt_tlb_hit <= 0;
                    dt_tlb_present <= 0;    // page fault
                    dt_tlb_supervisor <= 1; // supervisor fault
                    cr_supervisor_en[0] <= 1;
                end

                30:
                begin
                    assert(!dd_update_lru_en);
                    assert(!dd_instruction_valid);
                    assert(!dd_io_write_en);
                    assert(!dd_io_read_en);
                    assert(!dd_creg_write_en);
                    assert(!dd_creg_read_en);
                    assert(!dd_store_en);
                    assert(!dd_flush_en);
                    assert(!dd_membar_en);
                    assert(!dd_iinvalidate_en);
                    assert(!dd_dinvalidate_en);
                    assert(!dd_cache_miss);
                    assert(!dd_trap);
                    assert(!dd_perf_dcache_hit);
                    assert(!dd_perf_dcache_miss);
                    assert(!dd_perf_store);
                    assert(!dd_perf_dtlb_miss);
                end

                // Check that the TLB miss fault is raised
                31:
                begin
                    assert(dd_trap);
                    assert(dd_trap_cause == {1'b1, 1'b1, TT_TLB_MISS});
                    assert(!dd_cache_miss);
                    assert(dd_instruction_valid);
                    assert(!dd_suspend_thread);
                    assert(!dd_rollback_en); // This is only for cache misses
                    assert(!dd_perf_dcache_hit);
                    assert(!dd_perf_dcache_miss);
                    assert(!dd_perf_store);
                    assert(dd_perf_dtlb_miss);
                end

                // Load, but unmasked vector lane. Ignore TLB access (gather store)
                32:
                begin
                    cache_miss(NORMAL_ADDR, 1);
                    dt_tlb_hit <= 0;
                    dt_tlb_present <= 0;    // page fault
                    dt_tlb_supervisor <= 1; // supervisor fault
                    cr_supervisor_en[0] <= 1;
                    dt_mask_value <= 0;
                    dt_instruction.memory_access_type <= MEM_SCGATH_M;
                    assert(!dd_perf_dcache_hit);
                    assert(!dd_perf_dcache_miss);
                    assert(!dd_perf_store);
                    assert(!dd_perf_dtlb_miss);
                end

                33:
                begin
                    assert(!dd_trap);
                    assert(!dd_instruction_valid);
                    assert(!dd_update_lru_en);
                    assert(!dd_io_write_en);
                    assert(!dd_io_read_en);
                    assert(!dd_creg_write_en);
                    assert(!dd_creg_read_en);
                    assert(!dd_store_en);
                    assert(!dd_flush_en);
                    assert(!dd_membar_en);
                    assert(!dd_iinvalidate_en);
                    assert(!dd_dinvalidate_en);
                    assert(!dd_cache_miss);
                    assert(!dd_perf_dcache_hit);
                    assert(!dd_perf_dcache_miss);
                    assert(!dd_perf_store);
                    assert(!dd_perf_dtlb_miss);
                end

                // Check that the TLB miss fault is not raised
                34:
                begin
                    assert(!dd_trap);
                    assert(!dd_cache_miss);
                    assert(dd_instruction_valid);
                    assert(!dd_suspend_thread);
                    assert(!dd_rollback_en); // This is only for cache misses
                    assert(!dd_perf_dcache_hit);
                    assert(!dd_perf_dcache_miss);
                    assert(!dd_perf_store);
                    assert(!dd_perf_dtlb_miss);
                end

                // Store, but unmasked vector lane. Ignore TLB access (scatter store)
                35:
                begin
                    cache_miss(NORMAL_ADDR, 0);
                    dt_tlb_hit <= 0;
                    dt_tlb_present <= 0;    // page fault
                    dt_tlb_supervisor <= 1; // supervisor fault
                    cr_supervisor_en[0] <= 1;
                    dt_mask_value <= 0;
                    dt_instruction.memory_access_type <= MEM_SCGATH_M;
                end

                36:
                begin
                    assert(!dd_update_lru_en);
                    assert(!dd_instruction_valid);
                    assert(!dd_io_write_en);
                    assert(!dd_io_read_en);
                    assert(!dd_creg_write_en);
                    assert(!dd_creg_read_en);
                    assert(!dd_store_en);
                    assert(!dd_flush_en);
                    assert(!dd_membar_en);
                    assert(!dd_iinvalidate_en);
                    assert(!dd_dinvalidate_en);
                    assert(!dd_cache_miss);
                    assert(!dd_trap);
                    assert(!dd_perf_dcache_hit);
                    assert(!dd_perf_dcache_miss);
                    assert(!dd_perf_store);
                    assert(!dd_perf_dtlb_miss);
                end

                // Check that the TLB miss fault is not raised
                37:
                begin
                    assert(!dd_trap);
                    assert(!dd_cache_miss);
                    assert(dd_instruction_valid);
                    assert(!dd_suspend_thread);
                    assert(!dd_rollback_en);
                    assert(!dd_perf_dcache_hit);
                    assert(!dd_perf_dcache_miss);
                    assert(!dd_perf_store);
                    assert(!dd_perf_dtlb_miss);
                end

                ////////////////////////////////////////////////////////////
                // Page Fault. All other faults are active here as well,
                // (although the TLB is present) but this takes precedence.
                ////////////////////////////////////////////////////////////
                // Load cached
                40:
                begin
                    cache_miss(NORMAL_ADDR, 1);
                    dt_tlb_present <= 0;    // page fault
                    dt_tlb_supervisor <= 1; // supervisor fault
                    cr_supervisor_en[0] <= 0;
                end

                41:
                begin
                    assert(!dd_update_lru_en);
                    assert(!dd_instruction_valid);
                    assert(!dd_cache_miss);
                    assert(!dd_trap);
                    assert(!dd_perf_dcache_hit);
                    assert(!dd_perf_dcache_miss);
                    assert(!dd_perf_store);
                    assert(!dd_perf_dtlb_miss);
                end

                42:
                begin
                    assert(dd_trap);
                    assert(dd_trap_cause == {1'b1, 1'b0, TT_PAGE_FAULT});
                    assert(!dd_cache_miss);
                    assert(dd_instruction_valid);
                    assert(!dd_suspend_thread);
                    assert(!dd_rollback_en);
                    assert(!dd_perf_dcache_hit);
                    assert(!dd_perf_dcache_miss);
                    assert(!dd_perf_store);
                    assert(!dd_perf_dtlb_miss);
                end

                // Store cached
                43:
                begin
                    cache_miss(NORMAL_ADDR, 0);
                    dt_tlb_present <= 0;    // page fault
                    dt_tlb_supervisor <= 1; // supervisor fault
                    cr_supervisor_en[0] <= 1;
                    dt_tlb_writable <= 0;   // write fault
                end

                44:
                begin
                    assert(!dd_update_lru_en);
                    assert(!dd_instruction_valid);
                    assert(!dd_cache_miss);
                    assert(!dd_trap);
                    assert(!dd_perf_dcache_hit);
                    assert(!dd_perf_dcache_miss);
                    assert(!dd_perf_store);
                    assert(!dd_perf_dtlb_miss);
                end

                45:
                begin
                    assert(dd_trap);
                    assert(dd_trap_cause == {1'b1, 1'b1, TT_PAGE_FAULT});
                    assert(!dd_cache_miss);
                    assert(dd_instruction_valid);
                    assert(!dd_suspend_thread);
                    assert(!dd_rollback_en);
                    assert(!dd_perf_dcache_hit);
                    assert(!dd_perf_dcache_miss);
                    assert(!dd_perf_store);
                    assert(!dd_perf_dtlb_miss);
                end

                // Load uncached (I/O)
                46:
                begin
                    cache_miss(IO_ADDR, 1);
                    dt_tlb_present <= 0;    // page fault
                    dt_tlb_supervisor <= 1; // supervisor fault
                    cr_supervisor_en[0] <= 0;
                end

                47:
                begin
                    assert(!dd_update_lru_en);
                    assert(!dd_instruction_valid);
                    assert(!dd_cache_miss);
                    assert(!dd_trap);
                    assert(!dd_perf_dcache_hit);
                    assert(!dd_perf_dcache_miss);
                    assert(!dd_perf_store);
                    assert(!dd_perf_dtlb_miss);
                end

                48:
                begin
                    assert(dd_trap);
                    assert(dd_trap_cause == {1'b1, 1'b0, TT_PAGE_FAULT});
                    assert(!dd_cache_miss);
                    assert(dd_instruction_valid);
                    assert(!dd_suspend_thread);
                    assert(!dd_rollback_en);
                    assert(!dd_perf_dcache_hit);
                    assert(!dd_perf_dcache_miss);
                    assert(!dd_perf_store);
                    assert(!dd_perf_dtlb_miss);
                end

                // Store uncached (I/O)
                49:
                begin
                    cache_miss(IO_ADDR, 0);
                    dt_tlb_present <= 0;    // page fault
                    dt_tlb_supervisor <= 1; // supervisor fault
                    cr_supervisor_en[0] <= 1;
                    dt_tlb_writable <= 0;   // write fault
                end

                50:
                begin
                    assert(!dd_update_lru_en);
                    assert(!dd_instruction_valid);
                    assert(!dd_cache_miss);
                    assert(!dd_trap);
                    assert(!dd_perf_dcache_hit);
                    assert(!dd_perf_dcache_miss);
                    assert(!dd_perf_store);
                    assert(!dd_perf_dtlb_miss);
                end

                51:
                begin
                    assert(dd_trap);
                    assert(dd_trap_cause == {1'b1, 1'b1, TT_PAGE_FAULT});
                    assert(!dd_cache_miss);
                    assert(dd_instruction_valid);
                    assert(!dd_suspend_thread);
                    assert(!dd_rollback_en);
                    assert(!dd_perf_dcache_hit);
                    assert(!dd_perf_dcache_miss);
                    assert(!dd_perf_store);
                    assert(!dd_perf_dtlb_miss);
                end

                // Load cached, except with lane not enabled in vector mask
                52:
                begin
                    cache_miss(NORMAL_ADDR, 1);
                    dt_tlb_present <= 0;    // page fault
                    dt_tlb_supervisor <= 1; // supervisor fault
                    cr_supervisor_en[0] <= 1;
                    dt_tlb_writable <= 0;   // write fault
                    dt_mask_value <= 0;
                    dt_instruction.memory_access_type <= MEM_SCGATH_M;
                end

                53:
                begin
                    assert(!dd_update_lru_en);
                    assert(!dd_instruction_valid);
                    assert(!dd_cache_miss);
                    assert(!dd_trap);
                    assert(!dd_perf_dcache_hit);
                    assert(!dd_perf_dcache_miss);
                    assert(!dd_perf_store);
                    assert(!dd_perf_dtlb_miss);
                end

                54:
                begin
                    assert(!dd_trap);
                    assert(!dd_cache_miss);
                    assert(dd_instruction_valid);
                    assert(!dd_suspend_thread);
                    assert(!dd_rollback_en);
                    assert(!dd_perf_dcache_hit);
                    assert(!dd_perf_dcache_miss);
                    assert(!dd_perf_store);
                    assert(!dd_perf_dtlb_miss);
                end

                // Store cached, with lane not enabled
                55:
                begin
                    cache_miss(NORMAL_ADDR, 0);
                    dt_tlb_present <= 0;    // page fault
                    dt_tlb_supervisor <= 1; // supervisor fault
                    cr_supervisor_en[0] <= 1;
                    dt_tlb_writable <= 0;   // write fault
                    dt_mask_value <= 0;
                    dt_instruction.memory_access_type <= MEM_SCGATH_M;
                end

                56:
                begin
                    assert(!dd_update_lru_en);
                    assert(!dd_instruction_valid);
                    assert(!dd_cache_miss);
                    assert(!dd_trap);
                    assert(!dd_perf_dcache_hit);
                    assert(!dd_perf_dcache_miss);
                    assert(!dd_perf_store);
                    assert(!dd_perf_dtlb_miss);
                end

                57:
                begin
                    assert(!dd_trap);
                    assert(!dd_cache_miss);
                    assert(dd_instruction_valid);
                    assert(!dd_suspend_thread);
                    assert(!dd_rollback_en);
                    assert(!dd_perf_dcache_hit);
                    assert(!dd_perf_dcache_miss);
                    assert(!dd_perf_store);
                    assert(!dd_perf_dtlb_miss);
                end

                ////////////////////////////////////////////////////////////
                // Supervisor access fault
                ////////////////////////////////////////////////////////////
                // load
                60:
                begin
                    cache_miss(NORMAL_ADDR, 1);
                    dt_tlb_supervisor <= 1; // supervisor fault
                    cr_supervisor_en[0] <= 0;
                end

                61:
                begin
                    assert(!dd_update_lru_en);
                    assert(!dd_instruction_valid);
                    assert(!dd_cache_miss);
                    assert(!dd_trap);
                    assert(!dd_perf_dcache_hit);
                    assert(!dd_perf_dcache_miss);
                    assert(!dd_perf_store);
                    assert(!dd_perf_dtlb_miss);
                end

                62:
                begin
                    assert(dd_trap);
                    assert(dd_trap_cause == {1'b1, 1'b0, TT_SUPERVISOR_ACCESS});
                    assert(!dd_cache_miss);
                    assert(dd_instruction_valid);
                    assert(!dd_suspend_thread);
                    assert(!dd_rollback_en);
                    assert(!dd_perf_dcache_hit);
                    assert(!dd_perf_dcache_miss);
                    assert(!dd_perf_store);
                    assert(!dd_perf_dtlb_miss);
                end

                // store
                63:
                begin
                    cache_miss(NORMAL_ADDR, 0);
                    dt_tlb_supervisor <= 1; // supervisor fault
                    cr_supervisor_en[0] <= 0;
                    dt_tlb_writable <= 0;   // write fault
                end

                64:
                begin
                    assert(!dd_update_lru_en);
                    assert(!dd_instruction_valid);
                    assert(!dd_cache_miss);
                    assert(!dd_trap);
                    assert(!dd_perf_dcache_hit);
                    assert(!dd_perf_dcache_miss);
                    assert(!dd_perf_store);
                    assert(!dd_perf_dtlb_miss);
                end

                65:
                begin
                    assert(dd_trap);
                    assert(dd_trap_cause == {2'b11, TT_SUPERVISOR_ACCESS});
                    assert(!dd_cache_miss);
                    assert(dd_instruction_valid);
                    assert(!dd_suspend_thread);
                    assert(!dd_rollback_en);
                    assert(!dd_perf_dcache_hit);
                    assert(!dd_perf_dcache_miss);
                    assert(!dd_perf_store);
                    assert(!dd_perf_dtlb_miss);
                end

                // I/O address load
                66:
                begin
                    cache_miss(IO_ADDR, 1);
                    dt_tlb_supervisor <= 1; // supervisor fault
                    cr_supervisor_en[0] <= 0;
                end

                67:
                begin
                    assert(!dd_update_lru_en);
                    assert(!dd_instruction_valid);
                    assert(!dd_cache_miss);
                    assert(!dd_trap);
                    assert(!dd_perf_dcache_hit);
                    assert(!dd_perf_dcache_miss);
                    assert(!dd_perf_store);
                    assert(!dd_perf_dtlb_miss);
                end

                68:
                begin
                    assert(dd_trap);
                    assert(dd_trap_cause == {1'b1, 1'b0, TT_SUPERVISOR_ACCESS});
                    assert(!dd_cache_miss);
                    assert(dd_instruction_valid);
                    assert(!dd_suspend_thread);
                    assert(!dd_rollback_en);
                end

                // I/O address store
                69:
                begin
                    cache_miss(IO_ADDR, 0);
                    dt_tlb_supervisor <= 1; // supervisor fault
                    cr_supervisor_en[0] <= 0;
                    dt_tlb_writable <= 0;   // write fault
                end

                70:
                begin
                    assert(!dd_update_lru_en);
                    assert(!dd_instruction_valid);
                    assert(!dd_cache_miss);
                    assert(!dd_trap);
                    assert(!dd_perf_dcache_hit);
                    assert(!dd_perf_dcache_miss);
                    assert(!dd_perf_store);
                    assert(!dd_perf_dtlb_miss);
                end

                71:
                begin
                    assert(dd_trap);
                    assert(dd_trap_cause == {2'b11, TT_SUPERVISOR_ACCESS});
                    assert(!dd_cache_miss);
                    assert(dd_instruction_valid);
                    assert(!dd_suspend_thread);
                    assert(!dd_rollback_en);
                    assert(!dd_perf_dcache_hit);
                    assert(!dd_perf_dcache_miss);
                    assert(!dd_perf_store);
                    assert(!dd_perf_dtlb_miss);
                end

                // Load with mask disabled
                72:
                begin
                    cache_miss(NORMAL_ADDR, 1);
                    dt_tlb_supervisor <= 1; // supervisor fault
                    cr_supervisor_en[0] <= 0;
                    dt_tlb_writable <= 0;   // write fault
                    dt_mask_value <= 0;
                    dt_instruction.memory_access_type <= MEM_SCGATH_M;
                end

                73:
                begin
                    assert(!dd_update_lru_en);
                    assert(!dd_instruction_valid);
                    assert(!dd_cache_miss);
                    assert(!dd_trap);
                    assert(!dd_perf_dcache_hit);
                    assert(!dd_perf_dcache_miss);
                    assert(!dd_perf_store);
                    assert(!dd_perf_dtlb_miss);
                end

                74:
                begin
                    assert(!dd_trap);
                    assert(!dd_cache_miss);
                    assert(dd_instruction_valid);
                    assert(!dd_suspend_thread);
                    assert(!dd_rollback_en);
                    assert(!dd_perf_dcache_hit);
                    assert(!dd_perf_dcache_miss);
                    assert(!dd_perf_store);
                    assert(!dd_perf_dtlb_miss);
                end

                // Store with mask disabled
                75:
                begin
                    cache_miss(NORMAL_ADDR, 0);
                    dt_tlb_supervisor <= 1; // supervisor fault
                    cr_supervisor_en[0] <= 0;
                    dt_tlb_writable <= 0;   // write fault
                    dt_mask_value <= 0;
                    dt_instruction.memory_access_type <= MEM_SCGATH_M;
                end

                76:
                begin
                    assert(!dd_update_lru_en);
                    assert(!dd_instruction_valid);
                    assert(!dd_cache_miss);
                    assert(!dd_trap);
                    assert(!dd_perf_dcache_hit);
                    assert(!dd_perf_dcache_miss);
                    assert(!dd_perf_store);
                    assert(!dd_perf_dtlb_miss);
                end

                77:
                begin
                    assert(!dd_trap);
                    assert(!dd_cache_miss);
                    assert(dd_instruction_valid);
                    assert(!dd_suspend_thread);
                    assert(!dd_rollback_en);
                    assert(!dd_perf_dcache_hit);
                    assert(!dd_perf_dcache_miss);
                    assert(!dd_perf_store);
                    assert(!dd_perf_dtlb_miss);
                end

                ////////////////////////////////////////////////////////////
                // Unaligned memory access
                ////////////////////////////////////////////////////////////
                // Load
                80: cache_miss(NORMAL_ADDR + 1, 1);

                81:
                begin
                    assert(!dd_update_lru_en);
                    assert(!dd_instruction_valid);
                    assert(!dd_cache_miss);
                    assert(!dd_trap);
                    assert(!dd_perf_dcache_hit);
                    assert(!dd_perf_dcache_miss);
                    assert(!dd_perf_store);
                    assert(!dd_perf_dtlb_miss);
                end

                82:
                begin
                    assert(dd_trap);
                    assert(dd_trap_cause == {1'b1, 1'b0, TT_UNALIGNED_ACCESS});
                    assert(!dd_cache_miss);
                    assert(dd_instruction_valid);
                    assert(!dd_suspend_thread);
                    assert(!dd_rollback_en);
                    assert(!dd_perf_dcache_hit);
                    assert(!dd_perf_dcache_miss);
                    assert(!dd_perf_store);
                    assert(!dd_perf_dtlb_miss);
                end

                // Store
                83:
                begin
                    cache_miss(NORMAL_ADDR + 1, 0);
                    dt_tlb_writable <= 0;   // write fault
                end

                84:
                begin
                    assert(!dd_update_lru_en);
                    assert(!dd_instruction_valid);
                    assert(!dd_cache_miss);
                    assert(!dd_trap);
                    assert(!dd_perf_dcache_hit);
                    assert(!dd_perf_dcache_miss);
                    assert(!dd_perf_store);
                    assert(!dd_perf_dtlb_miss);
                end

                85:
                begin
                    assert(dd_trap);
                    assert(dd_trap_cause == {1'b1, 1'b1, TT_UNALIGNED_ACCESS});
                    assert(!dd_cache_miss);
                    assert(dd_instruction_valid);
                    assert(!dd_suspend_thread);
                    assert(!dd_rollback_en);
                    assert(!dd_perf_dcache_hit);
                    assert(!dd_perf_dcache_miss);
                    assert(!dd_perf_store);
                    assert(!dd_perf_dtlb_miss);
                end

                // Load cached, but mask is zero.
                86:
                begin
                    cache_miss(NORMAL_ADDR + 1, 1);
                    dt_mask_value <= 0;
                    dt_instruction.memory_access_type <= MEM_SCGATH_M;
                end

                87:
                begin
                    assert(!dd_update_lru_en);
                    assert(!dd_instruction_valid);
                    assert(!dd_cache_miss);
                    assert(!dd_trap);
                    assert(!dd_perf_dcache_hit);
                    assert(!dd_perf_dcache_miss);
                    assert(!dd_perf_store);
                    assert(!dd_perf_dtlb_miss);
                end

                88:
                begin
                    assert(!dd_trap);
                    assert(!dd_cache_miss);
                    assert(dd_instruction_valid);
                    assert(!dd_suspend_thread);
                    assert(!dd_rollback_en);
                end

                // Store cached, but mask is zero.
                89:
                begin
                    cache_miss(NORMAL_ADDR + 1, 0);
                    dt_mask_value <= 0;
                    dt_instruction.memory_access_type <= MEM_SCGATH_M;
                end

                90:
                begin
                    assert(!dd_update_lru_en);
                    assert(!dd_instruction_valid);
                    assert(!dd_cache_miss);
                    assert(!dd_trap);
                    assert(!dd_perf_dcache_hit);
                    assert(!dd_perf_dcache_miss);
                    assert(!dd_perf_store);
                    assert(!dd_perf_dtlb_miss);
                end

                91:
                begin
                    assert(!dd_trap);
                    assert(!dd_cache_miss);
                    assert(dd_instruction_valid);
                    assert(!dd_suspend_thread);
                    assert(!dd_rollback_en);
                end

                ////////////////////////////////////////////////////////////
                // Privileged op fault.
                ////////////////////////////////////////////////////////////

                // Control register read from user mode.
                100:
                begin
                    dt_instruction_valid <= 1;
                    dt_instruction.memory_access <= 1;
                    dt_instruction.memory_access_type <= MEM_CONTROL_REG;
                    dt_instruction.load <= 1;
                    cr_supervisor_en[0] <= 0;
                end

                101:
                begin
                    assert(!dd_creg_read_en);
                    assert(!dd_cache_miss);
                    assert(!dd_update_lru_en);
                    assert(!dd_instruction_valid);
                    assert(!dd_io_read_en);
                    assert(!dd_io_write_en);
                    assert(!dd_creg_write_en);
                    assert(!dd_store_en);
                    assert(!dd_flush_en);
                    assert(!dd_membar_en);
                    assert(!dd_iinvalidate_en);
                    assert(!dd_dinvalidate_en);
                    assert(!dd_cache_miss);
                    assert(!dd_trap);
                    assert(!dd_perf_dcache_hit);
                    assert(!dd_perf_dcache_miss);
                    assert(!dd_perf_store);
                    assert(!dd_perf_dtlb_miss);
                end

                102:
                begin
                    assert(dd_trap);
                    assert(dd_trap_cause == {2'b00, TT_PRIVILEGED_OP});
                    assert(!dd_cache_miss);
                    assert(dd_instruction_valid);
                    assert(!dd_suspend_thread);
                    assert(!dd_rollback_en);
                    assert(!dd_perf_dcache_hit);
                    assert(!dd_perf_dcache_miss);
                    assert(!dd_perf_store);
                    assert(!dd_perf_dtlb_miss);
                end

                // Control register write from user mode.
                103:
                begin
                    dt_instruction_valid <= 1;
                    dt_instruction.memory_access <= 1;
                    dt_instruction.memory_access_type <= MEM_CONTROL_REG;
                    dt_instruction.load <= 0;
                    cr_supervisor_en[0] <= 0;
                end

                104:
                begin
                    assert(!dd_creg_read_en);
                    assert(!dd_cache_miss);
                    assert(!dd_update_lru_en);
                    assert(!dd_instruction_valid);
                    assert(!dd_io_read_en);
                    assert(!dd_io_write_en);
                    assert(!dd_creg_write_en);
                    assert(!dd_store_en);
                    assert(!dd_flush_en);
                    assert(!dd_membar_en);
                    assert(!dd_iinvalidate_en);
                    assert(!dd_dinvalidate_en);
                    assert(!dd_cache_miss);
                    assert(!dd_trap);
                    assert(!dd_perf_dcache_hit);
                    assert(!dd_perf_dcache_miss);
                    assert(!dd_perf_store);
                    assert(!dd_perf_dtlb_miss);
                end

                105:
                begin
                    assert(dd_trap);
                    assert(dd_trap_cause == {2'b00, TT_PRIVILEGED_OP});
                    assert(!dd_cache_miss);
                    assert(dd_instruction_valid);
                    assert(!dd_suspend_thread);
                    assert(!dd_rollback_en);
                    assert(!dd_perf_dcache_hit);
                    assert(!dd_perf_dcache_miss);
                    assert(!dd_perf_store);
                    assert(!dd_perf_dtlb_miss);
                end

                // DTLB update from user mode
                106:
                begin
                    dt_instruction_valid <= 1;
                    dt_instruction.cache_control <= 1;
                    dt_instruction.cache_control_op <= CACHE_DTLB_INSERT;
                    cr_supervisor_en[0] <= 0;
                end

                107:
                begin
                    assert(!dd_creg_read_en);
                    assert(!dd_cache_miss);
                    assert(!dd_update_lru_en);
                    assert(!dd_instruction_valid);
                    assert(!dd_io_read_en);
                    assert(!dd_io_write_en);
                    assert(!dd_creg_write_en);
                    assert(!dd_store_en);
                    assert(!dd_flush_en);
                    assert(!dd_membar_en);
                    assert(!dd_iinvalidate_en);
                    assert(!dd_dinvalidate_en);
                    assert(!dd_cache_miss);
                    assert(!dd_trap);
                    assert(!dd_perf_dcache_hit);
                    assert(!dd_perf_dcache_miss);
                    assert(!dd_perf_store);
                    assert(!dd_perf_dtlb_miss);
                end

                108:
                begin
                    assert(dd_trap);
                    assert(dd_trap_cause == {2'b00, TT_PRIVILEGED_OP});
                    assert(!dd_cache_miss);
                    assert(dd_instruction_valid);
                    assert(!dd_suspend_thread);
                    assert(!dd_rollback_en);
                    assert(!dd_perf_dcache_hit);
                    assert(!dd_perf_dcache_miss);
                    assert(!dd_perf_store);
                    assert(!dd_perf_dtlb_miss);
                end

                // ITLB update from user mode
                109:
                begin
                    dt_instruction_valid <= 1;
                    dt_instruction.cache_control <= 1;
                    dt_instruction.cache_control_op <= CACHE_ITLB_INSERT;
                    cr_supervisor_en[0] <= 0;
                end

                110:
                begin
                    assert(!dd_creg_read_en);
                    assert(!dd_cache_miss);
                    assert(!dd_update_lru_en);
                    assert(!dd_instruction_valid);
                    assert(!dd_io_read_en);
                    assert(!dd_io_write_en);
                    assert(!dd_creg_write_en);
                    assert(!dd_store_en);
                    assert(!dd_flush_en);
                    assert(!dd_membar_en);
                    assert(!dd_iinvalidate_en);
                    assert(!dd_dinvalidate_en);
                    assert(!dd_cache_miss);
                    assert(!dd_trap);
                    assert(!dd_perf_dcache_hit);
                    assert(!dd_perf_dcache_miss);
                    assert(!dd_perf_store);
                    assert(!dd_perf_dtlb_miss);
                end

                111:
                begin
                    assert(dd_trap);
                    assert(dd_trap_cause == {2'b00, TT_PRIVILEGED_OP});
                    assert(!dd_cache_miss);
                    assert(dd_instruction_valid);
                    assert(!dd_suspend_thread);
                    assert(!dd_rollback_en);
                    assert(!dd_perf_dcache_hit);
                    assert(!dd_perf_dcache_miss);
                    assert(!dd_perf_store);
                    assert(!dd_perf_dtlb_miss);
                end

                // TLB Invalidate
                112:
                begin
                    dt_instruction_valid <= 1;
                    dt_instruction.cache_control <= 1;
                    dt_instruction.cache_control_op <= CACHE_TLB_INVAL;
                    cr_supervisor_en[0] <= 0;
                end

                113:
                begin
                    assert(!dd_creg_read_en);
                    assert(!dd_cache_miss);
                    assert(!dd_update_lru_en);
                    assert(!dd_instruction_valid);
                    assert(!dd_io_read_en);
                    assert(!dd_io_write_en);
                    assert(!dd_creg_write_en);
                    assert(!dd_store_en);
                    assert(!dd_flush_en);
                    assert(!dd_membar_en);
                    assert(!dd_iinvalidate_en);
                    assert(!dd_dinvalidate_en);
                    assert(!dd_cache_miss);
                    assert(!dd_trap);
                    assert(!dd_perf_dcache_hit);
                    assert(!dd_perf_dcache_miss);
                    assert(!dd_perf_store);
                    assert(!dd_perf_dtlb_miss);
                end

                114:
                begin
                    assert(dd_trap);
                    assert(dd_trap_cause == {2'b00, TT_PRIVILEGED_OP});
                    assert(!dd_cache_miss);
                    assert(dd_instruction_valid);
                    assert(!dd_suspend_thread);
                    assert(!dd_rollback_en);
                    assert(!dd_perf_dcache_hit);
                    assert(!dd_perf_dcache_miss);
                    assert(!dd_perf_store);
                    assert(!dd_perf_dtlb_miss);
                end

                // TLB Invalidate All
                115:
                begin
                    dt_instruction_valid <= 1;
                    dt_instruction.cache_control <= 1;
                    dt_instruction.cache_control_op <= CACHE_TLB_INVAL_ALL;
                    cr_supervisor_en[0] <= 0;
                end

                116:
                begin
                    assert(!dd_creg_read_en);
                    assert(!dd_cache_miss);
                    assert(!dd_update_lru_en);
                    assert(!dd_instruction_valid);
                    assert(!dd_io_read_en);
                    assert(!dd_io_write_en);
                    assert(!dd_creg_write_en);
                    assert(!dd_store_en);
                    assert(!dd_flush_en);
                    assert(!dd_membar_en);
                    assert(!dd_iinvalidate_en);
                    assert(!dd_dinvalidate_en);
                    assert(!dd_cache_miss);
                    assert(!dd_trap);
                    assert(!dd_perf_dcache_hit);
                    assert(!dd_perf_dcache_miss);
                    assert(!dd_perf_store);
                    assert(!dd_perf_dtlb_miss);
                end

                117:
                begin
                    assert(dd_trap);
                    assert(dd_trap_cause == {2'b00, TT_PRIVILEGED_OP});
                    assert(!dd_cache_miss);
                    assert(dd_instruction_valid);
                    assert(!dd_suspend_thread);
                    assert(!dd_rollback_en);
                    assert(!dd_perf_dcache_hit);
                    assert(!dd_perf_dcache_miss);
                    assert(!dd_perf_store);
                    assert(!dd_perf_dtlb_miss);
                end

                ////////////////////////////////////////////////////////////
                // Illegal store
                ////////////////////////////////////////////////////////////
                130:
                begin
                    cache_miss(NORMAL_ADDR, 0);
                    dt_tlb_writable <= 0;
                end

                131:
                begin
                    assert(!dd_update_lru_en);
                    assert(!dd_instruction_valid);
                    assert(!dd_cache_miss);
                    assert(!dd_trap);
                    assert(!dd_perf_dcache_hit);
                    assert(!dd_perf_dcache_miss);
                    assert(!dd_perf_store);
                    assert(!dd_perf_dtlb_miss);
                end

                132:
                begin
                    assert(dd_trap);
                    assert(dd_trap_cause == {1'b1, 1'b1, TT_ILLEGAL_STORE});
                    assert(!dd_cache_miss);
                    assert(dd_instruction_valid);
                    assert(!dd_suspend_thread);
                    assert(!dd_rollback_en);
                    assert(!dd_perf_dcache_hit);
                    assert(!dd_perf_dcache_miss);
                    assert(!dd_perf_store);
                    assert(!dd_perf_dtlb_miss);
                end

                // I/O address
                133:
                begin
                    cache_miss(IO_ADDR, 0);
                    dt_tlb_writable <= 0;
                end

                134:
                begin
                    assert(!dd_update_lru_en);
                    assert(!dd_instruction_valid);
                    assert(!dd_cache_miss);
                    assert(!dd_trap);
                    assert(!dd_perf_dcache_hit);
                    assert(!dd_perf_dcache_miss);
                    assert(!dd_perf_store);
                    assert(!dd_perf_dtlb_miss);
                end

                135:
                begin
                    assert(dd_trap);
                    assert(dd_trap_cause == {1'b1, 1'b1, TT_ILLEGAL_STORE});
                    assert(!dd_cache_miss);
                    assert(dd_instruction_valid);
                    assert(!dd_suspend_thread);
                    assert(!dd_rollback_en);
                    assert(!dd_perf_dcache_hit);
                    assert(!dd_perf_dcache_miss);
                    assert(!dd_perf_store);
                    assert(!dd_perf_dtlb_miss);
                end

                // Lane is masked off
                136:
                begin
                    cache_miss(NORMAL_ADDR, 0);
                    dt_tlb_writable <= 0;
                    dt_mask_value <= 0;
                    dt_instruction.memory_access_type <= MEM_SCGATH_M;
                end

                137:
                begin
                    assert(!dd_update_lru_en);
                    assert(!dd_instruction_valid);
                    assert(!dd_cache_miss);
                    assert(!dd_trap);
                    assert(!dd_perf_dcache_hit);
                    assert(!dd_perf_dcache_miss);
                    assert(!dd_perf_store);
                    assert(!dd_perf_dtlb_miss);
                end

                138:
                begin
                    assert(!dd_trap);
                    assert(!dd_cache_miss);
                    assert(dd_instruction_valid);
                    assert(!dd_suspend_thread);
                    assert(!dd_rollback_en);
                    assert(!dd_perf_dcache_hit);
                    assert(!dd_perf_dcache_miss);
                    assert(!dd_perf_store);
                    assert(!dd_perf_dtlb_miss);
                end

                ////////////////////////////////////////////////////////////
                // Successful control register read/write
                ////////////////////////////////////////////////////////////
                // Control register read
                150:
                begin
                    dt_instruction_valid <= 1;
                    dt_instruction.memory_access <= 1;
                    dt_instruction.memory_access_type <= MEM_CONTROL_REG;
                    dt_instruction.load <= 1;
                    cr_supervisor_en[0] <= 1;
                end

                151:
                begin
                    assert(dd_creg_read_en);
                    assert(!dd_cache_miss);
                    assert(!dd_update_lru_en);
                    assert(!dd_instruction_valid);
                    assert(!dd_io_read_en);
                    assert(!dd_io_write_en);
                    assert(!dd_creg_write_en);
                    assert(!dd_store_en);
                    assert(!dd_flush_en);
                    assert(!dd_membar_en);
                    assert(!dd_iinvalidate_en);
                    assert(!dd_dinvalidate_en);
                    assert(!dd_cache_miss);
                    assert(!dd_trap);
                    assert(!dd_perf_dcache_hit);
                    assert(!dd_perf_dcache_miss);
                    assert(!dd_perf_store);
                    assert(!dd_perf_dtlb_miss);
                end

                152:
                begin
                    assert(!dd_trap);
                    assert(!dd_cache_miss);
                    assert(dd_instruction_valid);
                    assert(!dd_suspend_thread);
                    assert(!dd_rollback_en);
                    assert(!dd_perf_dcache_hit);
                    assert(!dd_perf_dcache_miss);
                    assert(!dd_perf_store);
                    assert(!dd_perf_dtlb_miss);
                end

                // Control register write
                153:
                begin
                    dt_instruction_valid <= 1;
                    dt_instruction.memory_access <= 1;
                    dt_instruction.memory_access_type <= MEM_CONTROL_REG;
                    dt_instruction.load <= 0;
                    cr_supervisor_en[0] <= 1;
                end

                154:
                begin
                    assert(dd_creg_write_en);
                    assert(!dd_creg_read_en);
                    assert(!dd_cache_miss);
                    assert(!dd_update_lru_en);
                    assert(!dd_instruction_valid);
                    assert(!dd_io_read_en);
                    assert(!dd_io_write_en);
                    assert(!dd_store_en);
                    assert(!dd_flush_en);
                    assert(!dd_membar_en);
                    assert(!dd_iinvalidate_en);
                    assert(!dd_dinvalidate_en);
                    assert(!dd_cache_miss);
                    assert(!dd_trap);
                    assert(!dd_perf_dcache_hit);
                    assert(!dd_perf_dcache_miss);
                    assert(!dd_perf_store);
                    assert(!dd_perf_dtlb_miss);
                end

                155:
                begin
                    assert(!dd_trap);
                    assert(!dd_cache_miss);
                    assert(dd_instruction_valid);
                    assert(!dd_suspend_thread);
                    assert(!dd_rollback_en);
                    assert(!dd_perf_dcache_hit);
                    assert(!dd_perf_dcache_miss);
                    assert(!dd_perf_store);
                    assert(!dd_perf_dtlb_miss);
                end

                ////////////////////////////////////////////////////////////
                // Rollback during cache hit
                ////////////////////////////////////////////////////////////
                170:
                begin
                    cache_hit(NORMAL_ADDR, 1);
                    wb_rollback_en <= 1;
                    wb_rollback_thread_idx <= 0;
                    dt_thread_idx <= 0;
                    wb_rollback_pipeline <= PIPE_MEM;
                end

                171:
                begin
                    assert(!dd_update_lru_en);
                    assert(!dd_instruction_valid);
                    assert(!dd_io_write_en);
                    assert(!dd_io_read_en);
                    assert(!dd_creg_write_en);
                    assert(!dd_creg_read_en);
                    assert(!dd_store_en);
                    assert(!dd_flush_en);
                    assert(!dd_membar_en);
                    assert(!dd_iinvalidate_en);
                    assert(!dd_dinvalidate_en);
                    assert(!dd_cache_miss);
                    assert(!dd_trap);
                    assert(!dd_perf_dcache_hit);
                    assert(!dd_perf_dcache_miss);
                    assert(!dd_perf_store);
                    assert(!dd_perf_dtlb_miss);
                end

                172:
                begin
                    assert(!dd_trap);
                    assert(!dd_cache_miss);
                    assert(!dd_instruction_valid);
                    assert(!dd_suspend_thread);
                    assert(!dd_rollback_en);
                    assert(!dd_perf_dcache_hit);
                    assert(!dd_perf_dcache_miss);
                    assert(!dd_perf_store);
                    assert(!dd_perf_dtlb_miss);
                end

                ////////////////////////////////////////////////////////////
                // Rollback during cache miss
                ////////////////////////////////////////////////////////////
                180:
                begin
                    cache_miss(NORMAL_ADDR, 1);
                    wb_rollback_en <= 1;
                    wb_rollback_thread_idx <= 0;
                    dt_thread_idx <= 0;
                    wb_rollback_pipeline <= PIPE_MEM;
                end

                181:
                begin
                    assert(!dd_update_lru_en);
                    assert(!dd_instruction_valid);
                    assert(!dd_io_write_en);
                    assert(!dd_io_read_en);
                    assert(!dd_creg_write_en);
                    assert(!dd_creg_read_en);
                    assert(!dd_store_en);
                    assert(!dd_flush_en);
                    assert(!dd_membar_en);
                    assert(!dd_iinvalidate_en);
                    assert(!dd_dinvalidate_en);
                    assert(!dd_cache_miss);
                    assert(!dd_trap);
                    assert(!dd_perf_dcache_hit);
                    assert(!dd_perf_dcache_miss);
                    assert(!dd_perf_store);
                    assert(!dd_perf_dtlb_miss);
                end

                182:
                begin
                    assert(!dd_trap);
                    assert(!dd_cache_miss);
                    assert(!dd_instruction_valid);
                    assert(!dd_suspend_thread);
                    assert(!dd_rollback_en);
                    assert(!dd_perf_dcache_hit);
                    assert(!dd_perf_dcache_miss);
                    assert(!dd_perf_store);
                    assert(!dd_perf_dtlb_miss);
                end

                ////////////////////////////////////////////////////////////
                // Rollback during TLB miss
                ////////////////////////////////////////////////////////////
                190:
                begin
                    cache_miss(NORMAL_ADDR, 1);
                    dt_tlb_hit <= 0;
                    dt_tlb_present <= 1;
                    wb_rollback_en <= 1;
                    wb_rollback_thread_idx <= 0;
                    dt_thread_idx <= 0;
                    wb_rollback_pipeline <= PIPE_MEM;
                end

                191:
                begin
                    assert(!dd_update_lru_en);
                    assert(!dd_perf_dcache_hit);
                    assert(!dd_instruction_valid);
                    assert(!dd_io_write_en);
                    assert(!dd_io_read_en);
                    assert(!dd_creg_write_en);
                    assert(!dd_creg_read_en);
                    assert(!dd_store_en);
                    assert(!dd_flush_en);
                    assert(!dd_membar_en);
                    assert(!dd_iinvalidate_en);
                    assert(!dd_dinvalidate_en);
                    assert(!dd_cache_miss);
                    assert(!dd_trap);
                    assert(!dd_perf_dcache_hit);
                    assert(!dd_perf_dcache_miss);
                    assert(!dd_perf_store);
                    assert(!dd_perf_dtlb_miss);
                end

                192:
                begin
                    assert(!dd_trap);
                    assert(!dd_cache_miss);
                    assert(!dd_instruction_valid);
                    assert(!dd_suspend_thread);
                    assert(!dd_rollback_en); // This is only for cache misses
                    assert(!dd_perf_dcache_hit);
                    assert(!dd_perf_dcache_miss);
                    assert(!dd_perf_store);
                    assert(!dd_perf_dtlb_miss);
                end

                ////////////////////////////////////////////////////////////
                // Rollback during [alignment] fault
                ////////////////////////////////////////////////////////////
                200:
                begin
                    cache_miss(NORMAL_ADDR + 1, 1);
                    wb_rollback_en <= 1;
                    wb_rollback_thread_idx <= 0;
                    dt_thread_idx <= 0;
                    wb_rollback_pipeline <= PIPE_MEM;
                end

                201:
                begin
                    assert(!dd_update_lru_en);
                    assert(!dd_perf_dcache_hit);
                    assert(!dd_instruction_valid);
                    assert(!dd_cache_miss);
                    assert(!dd_trap);
                    assert(!dd_perf_dcache_hit);
                    assert(!dd_perf_dcache_miss);
                    assert(!dd_perf_store);
                    assert(!dd_perf_dtlb_miss);
                end

                202:
                begin
                    assert(!dd_trap);
                    assert(!dd_cache_miss);
                    assert(!dd_instruction_valid);
                    assert(!dd_suspend_thread);
                    assert(!dd_rollback_en);
                    assert(!dd_perf_dcache_hit);
                    assert(!dd_perf_dcache_miss);
                    assert(!dd_perf_store);
                    assert(!dd_perf_dtlb_miss);
                end

                ////////////////////////////////////////////////////////////
                // Rollback during I/O load
                ////////////////////////////////////////////////////////////
                210:
                begin
                    cache_hit(IO_ADDR, 1);
                    wb_rollback_en <= 1;
                    wb_rollback_thread_idx <= 0;
                    dt_thread_idx <= 0;
                    wb_rollback_pipeline <= PIPE_MEM;
                end

                211:
                begin
                    assert(!dd_update_lru_en);
                    assert(!dd_instruction_valid);
                    assert(!dd_io_write_en);
                    assert(!dd_io_read_en);
                    assert(!dd_creg_write_en);
                    assert(!dd_creg_read_en);
                    assert(!dd_store_en);
                    assert(!dd_flush_en);
                    assert(!dd_membar_en);
                    assert(!dd_iinvalidate_en);
                    assert(!dd_dinvalidate_en);
                    assert(!dd_cache_miss);
                    assert(!dd_trap);
                    assert(!dd_perf_dcache_hit);
                    assert(!dd_perf_dcache_miss);
                    assert(!dd_perf_store);
                    assert(!dd_perf_dtlb_miss);
                end

                212:
                begin
                    assert(!dd_trap);
                    assert(!dd_cache_miss);
                    assert(!dd_instruction_valid);
                    assert(!dd_suspend_thread);
                    assert(!dd_rollback_en);
                    assert(!dd_perf_dcache_hit);
                    assert(!dd_perf_dcache_miss);
                    assert(!dd_perf_store);
                    assert(!dd_perf_dtlb_miss);
                end

                ////////////////////////////////////////////////////////////
                // Rollback during I/O store
                ////////////////////////////////////////////////////////////
                220:
                begin
                    cache_hit(IO_ADDR, 0);
                    wb_rollback_en <= 1;
                    wb_rollback_thread_idx <= 0;
                    dt_thread_idx <= 0;
                    wb_rollback_pipeline <= PIPE_MEM;
                end

                221:
                begin
                    assert(!dd_update_lru_en);
                    assert(!dd_instruction_valid);
                    assert(!dd_io_write_en);
                    assert(!dd_io_read_en);
                    assert(!dd_creg_write_en);
                    assert(!dd_creg_read_en);
                    assert(!dd_store_en);
                    assert(!dd_flush_en);
                    assert(!dd_membar_en);
                    assert(!dd_iinvalidate_en);
                    assert(!dd_dinvalidate_en);
                    assert(!dd_cache_miss);
                    assert(!dd_trap);
                    assert(!dd_perf_dcache_hit);
                    assert(!dd_perf_dcache_miss);
                    assert(!dd_perf_store);
                    assert(!dd_perf_dtlb_miss);
                end

                222:
                begin
                    assert(!dd_trap);
                    assert(!dd_cache_miss);
                    assert(!dd_instruction_valid);
                    assert(!dd_suspend_thread);
                    assert(!dd_rollback_en);
                    assert(!dd_perf_dcache_hit);
                    assert(!dd_perf_dcache_miss);
                    assert(!dd_perf_store);
                    assert(!dd_perf_dtlb_miss);
                end

                ////////////////////////////////////////////////////////////
                // Check that a masked lane is properly stored with a
                // scatter access.
                ////////////////////////////////////////////////////////////
                230:
                begin
                    cache_hit(32'h80000000, 0);
                    wb_rollback_pipeline <= PIPE_MEM;
                    dt_instruction.memory_access <= 1;
                    dt_instruction.memory_access_type <= MEM_SCGATH_M;
                    dt_mask_value <= 16'h8000;
                    dt_subcycle <= 15;
                end

                231:
                begin
                    assert(dd_store_en);
                    assert(dd_update_lru_en);
                    assert(!dd_instruction_valid);
                    assert(!dd_cache_miss);
                    assert(!dd_trap);
                    assert(!dd_perf_dcache_hit);
                    assert(!dd_perf_dcache_miss);
                    assert(!dd_perf_store);
                    assert(!dd_perf_dtlb_miss);
                end

                232:
                begin
                    assert(!dd_trap);
                    assert(!dd_cache_miss);
                    assert(dd_instruction_valid);
                    assert(!dd_suspend_thread);
                    assert(!dd_rollback_en);
                    assert(!dd_perf_dcache_hit);
                    assert(!dd_perf_dcache_miss);
                    assert(dd_perf_store);
                    assert(!dd_perf_dtlb_miss);
                end

                ////////////////////////////////////////////////////////////
                // Cache near miss
                ////////////////////////////////////////////////////////////
                240:
                begin
                    cache_miss(NORMAL_ADDR, 1);
                    l2i_dtag_update_en_oh <= 1;
                    l2i_dtag_update_set <= l1d_set_idx_t'(NORMAL_ADDR >> CACHE_LINE_OFFSET_WIDTH);
                    l2i_dtag_update_tag <= l1d_tag_t'(NORMAL_ADDR >> (32 - DCACHE_TAG_BITS));
                end

                241:
                begin
                    // Cache miss is not marked because this was just filled
                    assert(!dd_cache_miss);

                    assert(!dd_update_lru_en);
                    assert(!dd_instruction_valid);
                    assert(!dd_io_write_en);
                    assert(!dd_io_read_en);
                    assert(!dd_creg_write_en);
                    assert(!dd_creg_read_en);
                    assert(!dd_store_en);
                    assert(!dd_flush_en);
                    assert(!dd_membar_en);
                    assert(!dd_iinvalidate_en);
                    assert(!dd_dinvalidate_en);
                    assert(!dd_trap);
                    assert(!dd_perf_dcache_hit);
                    assert(!dd_perf_dcache_miss);
                    assert(!dd_perf_store);
                    assert(!dd_perf_dtlb_miss);
                end

                242:
                begin
                    // This is the key combination: a rollback without a suspend
                    assert(!dd_suspend_thread);
                    assert(dd_rollback_en);

                    assert(!dd_trap);
                    assert(dd_instruction_valid);
                    assert(!dd_perf_dcache_hit);
                    assert(dd_perf_dcache_miss);
                    assert(!dd_perf_store);
                    assert(!dd_perf_dtlb_miss);
                end

                ////////////////////////////////////////////////////////////
                // Synchronized access
                ////////////////////////////////////////////////////////////

                // Sync load
                250:
                begin
                    cache_hit(NORMAL_ADDR, 1);
                    dt_instruction.memory_access_type <= MEM_SYNC;
                end

                251:
                begin
                    // This will force it to send to the L2 cache
                    assert(dd_cache_miss);

                    assert(!dd_instruction_valid);
                    assert(!dd_io_write_en);
                    assert(!dd_io_read_en);
                    assert(!dd_creg_write_en);
                    assert(!dd_creg_read_en);
                    assert(!dd_flush_en);
                    assert(!dd_membar_en);
                    assert(!dd_iinvalidate_en);
                    assert(!dd_dinvalidate_en);
                    assert(!dd_trap);
                    assert(!dd_perf_dcache_hit);
                    assert(!dd_perf_dcache_miss);
                    assert(!dd_perf_store);
                    assert(!dd_perf_dtlb_miss);
                end

                // We get an initial rollback to wait for L2 response
                252:
                begin
                    assert(!dd_trap);
                    assert(!dd_cache_miss);
                    assert(dd_instruction_valid);
                    assert(dd_suspend_thread);
                    assert(dd_rollback_en);
                    assert(dd_load_sync_pending == 4'b0001);
                    assert(!dd_perf_dcache_hit);
                    assert(dd_perf_dcache_miss);
                    assert(!dd_perf_store);
                    assert(!dd_perf_dtlb_miss);
                end

                // Pretend we got woken up, pick up the result...
                253:
                begin
                    cache_hit(NORMAL_ADDR, 1);
                    dt_instruction.memory_access_type <= MEM_SYNC;
                end

                254:
                begin
                    assert(dd_update_lru_en);
                    assert(!dd_instruction_valid);
                    assert(!dd_io_write_en);
                    assert(!dd_io_read_en);
                    assert(!dd_creg_write_en);
                    assert(!dd_creg_read_en);
                    assert(!dd_flush_en);
                    assert(!dd_membar_en);
                    assert(!dd_iinvalidate_en);
                    assert(!dd_dinvalidate_en);
                    assert(!dd_cache_miss);
                    assert(!dd_trap);
                    assert(!dd_perf_dcache_hit);
                    assert(!dd_perf_dcache_miss);
                    assert(!dd_perf_store);
                    assert(!dd_perf_dtlb_miss);
                end

                // Doesn't get suspended
                255:
                begin
                    assert(!dd_trap);
                    assert(!dd_cache_miss);
                    assert(dd_instruction_valid);
                    assert(!dd_suspend_thread);
                    assert(!dd_rollback_en);
                    assert(dd_load_sync_pending == 4'b0000);
                    assert(dd_perf_dcache_hit);
                    assert(!dd_perf_dcache_miss);
                    assert(!dd_perf_store);
                    assert(!dd_perf_dtlb_miss);
                end

                256:
                begin
                    $display("PASS");
                    $finish;
                end
            endcase
        end
    end
endmodule
