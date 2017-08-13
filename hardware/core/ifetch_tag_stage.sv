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

`include "defines.sv"

import defines::*;

//
// Instruction Pipeline - Instruction Fetch Tag Stage
// - Selects a program counter from one of the threads to fetch from the
//   instruction cache. It tries to fetch an instruction from a different
//   thread every cycle whenever possible.
// - Reads instruction cache tag memory to determine if the cache line is
//   resident.
// - Reads translation lookaside buffer to translate from virtual to physical
//   address.
//

module ifetch_tag_stage
    #(parameter RESET_PC = 0)

    (input                              clk,
    input                               reset,

    // From ifetch_data_stage
    input                               ifd_update_lru_en,
    input l1i_way_idx_t                 ifd_update_lru_way,
    input                               ifd_cache_miss,
    input                               ifd_near_miss,
    input local_thread_idx_t            ifd_cache_miss_thread_idx,

    // To ifetch_data_stage
    output logic                        ift_instruction_requested,
    output l1i_addr_t                   ift_pc_paddr,
    output scalar_t                     ift_pc_vaddr,
    output local_thread_idx_t           ift_thread_idx,
    output logic                        ift_tlb_hit,
    output logic                        ift_tlb_present,
    output logic                        ift_tlb_executable,
    output logic                        ift_tlb_supervisor,
    output l1i_tag_t                    ift_tag[`L1I_WAYS],
    output logic                        ift_valid[`L1I_WAYS],

    // From l1_l2_interface
    input                               l2i_icache_lru_fill_en,
    input l1i_set_idx_t                 l2i_icache_lru_fill_set,
    input [`L1I_WAYS - 1:0]             l2i_itag_update_en,
    input l1i_set_idx_t                 l2i_itag_update_set,
    input l1i_tag_t                     l2i_itag_update_tag,
    input                               l2i_itag_update_valid,
    input local_thread_bitmap_t         l2i_icache_wake_bitmap,
    output l1i_way_idx_t                ift_fill_lru,

    // From control_registers
    input                               cr_mmu_en[`THREADS_PER_CORE],
    input [ASID_WIDTH - 1:0]            cr_current_asid[`THREADS_PER_CORE],

    // From dcache_tag_stage
    input                               dt_invalidate_tlb_en,
    input                               dt_invalidate_tlb_all_en,
    input [ASID_WIDTH - 1:0]            dt_itlb_update_asid,
    input page_index_t                  dt_itlb_vpage_idx,
    input                               dt_update_itlb_en,
    input                               dt_update_itlb_supervisor,
    input                               dt_update_itlb_global,
    input                               dt_update_itlb_present,
    input                               dt_update_itlb_executable,
    input page_index_t                  dt_update_itlb_ppage_idx,

    // From writeback_stage
    input                               wb_rollback_en,
    input local_thread_idx_t            wb_rollback_thread_idx,
    input scalar_t                      wb_rollback_pc,

    // From thread_select_stage
    input local_thread_bitmap_t         ts_fetch_en);

    scalar_t next_program_counter[`THREADS_PER_CORE];
    local_thread_idx_t selected_thread_idx;
    scalar_t last_selected_pc;
    l1i_addr_t pc_to_fetch;
    local_thread_bitmap_t can_fetch_thread_bitmap;
    local_thread_bitmap_t selected_thread_oh;
    local_thread_bitmap_t last_selected_thread_oh;
    local_thread_bitmap_t icache_wait_threads;
    local_thread_bitmap_t icache_wait_threads_nxt;
    local_thread_bitmap_t cache_miss_thread_oh;
    local_thread_bitmap_t thread_sleep_mask_oh;
    logic cache_fetch_en;
    page_index_t tlb_ppage_idx;
    page_index_t ppage_idx;
    logic tlb_hit;
    logic tlb_supervisor;
    logic tlb_present;
    logic tlb_executable;

    //
    // Pick which thread to fetch next.
    // Only consider threads that are not blocked, but do not skip threads that
    // are being rolled back in the current cycle because the rollback signals
    // have a long combinational path that is a critical path for clock speed.
    // Instead, when the selected thread is rolled back in the same cycle,
    // invalidate the instruction by deasserting ift_instruction_requested. This
    // wastes a cycle, but should be infrequent.
    //
    assign can_fetch_thread_bitmap = ts_fetch_en & ~icache_wait_threads;

    // If an instruction is updating the TLB, can't access it to translate the next
    // address, so skip instruction fetch this cycle.
    assign cache_fetch_en = |can_fetch_thread_bitmap && !dt_update_itlb_en
        && !dt_invalidate_tlb_en && !dt_invalidate_tlb_all_en;

    rr_arbiter #(.NUM_REQUESTERS(`THREADS_PER_CORE)) thread_select_arbiter(
        .request(can_fetch_thread_bitmap),
        .update_lru(cache_fetch_en),
        .grant_oh(selected_thread_oh),
        .*);

    oh_to_idx #(.NUM_SIGNALS(`THREADS_PER_CORE)) oh_to_idx_selected_thread(
        .one_hot(selected_thread_oh),
        .index(selected_thread_idx));

    //
    // Program counter update logic
    //
    genvar thread_idx;
    generate
        for (thread_idx = 0; thread_idx < `THREADS_PER_CORE; thread_idx++)
        begin : pc_logic_gen
            always_ff @(posedge clk, posedge reset)
            begin
                if (reset)
                    next_program_counter[thread_idx] <= RESET_PC;
                else if (wb_rollback_en && wb_rollback_thread_idx == local_thread_idx_t'(thread_idx))
                    next_program_counter[thread_idx] <= wb_rollback_pc;
                else if ((ifd_cache_miss || ifd_near_miss) && last_selected_thread_oh[thread_idx])
                    next_program_counter[thread_idx] <= next_program_counter[thread_idx] - 4;
                else if (selected_thread_oh[thread_idx] && cache_fetch_en)
                    next_program_counter[thread_idx] <= next_program_counter[thread_idx] + 4;
            end
        end
    endgenerate

    assign pc_to_fetch = next_program_counter[selected_thread_idx];

    //
    // Cache way metadata
    //
    genvar way_idx;
    generate
        for (way_idx = 0; way_idx < `L1I_WAYS; way_idx++)
        begin : way_tag_gen
            // Valid flags are flops instead of SRAM because they need
            // to simultaneously be cleared on reset.
            logic line_valid[`L1I_SETS];

            sram_1r1w #(
                .DATA_WIDTH($bits(l1i_tag_t)),
                .SIZE(`L1I_SETS),
                .READ_DURING_WRITE("NEW_DATA")
            ) sram_tags(
                .read_en(cache_fetch_en),
                .read_addr(pc_to_fetch.set_idx),
                .read_data(ift_tag[way_idx]),
                .write_en(l2i_itag_update_en[way_idx]),
                .write_addr(l2i_itag_update_set),
                .write_data(l2i_itag_update_tag),
                .*);

            always_ff @(posedge clk, posedge reset)
            begin
                if (reset)
                begin
                    for (int set_idx = 0; set_idx < `L1I_SETS; set_idx++)
                        line_valid[set_idx] <= 0;
                end
                else
                begin
                    if (l2i_itag_update_en[way_idx])
                        line_valid[l2i_itag_update_set] <= l2i_itag_update_valid;
                end
            end

            always_ff @(posedge clk)
            begin
                // Fetch cache line state for pipeline
                if (l2i_itag_update_en[way_idx] && l2i_itag_update_set == pc_to_fetch.set_idx)
                    ift_valid[way_idx] <= l2i_itag_update_valid;    // Bypass
                else
                    ift_valid[way_idx] <= line_valid[pc_to_fetch.set_idx];
            end
        end
    endgenerate

`ifdef HAS_MMU
    tlb #(
        .NUM_ENTRIES(`DTLB_ENTRIES),
        .NUM_WAYS(`TLB_WAYS)
    ) itlb(
        .lookup_en(cache_fetch_en),
        .update_en(dt_update_itlb_en),
        .update_present(dt_update_itlb_present),
        .update_exe_writable(dt_update_itlb_executable),
        .update_supervisor(dt_update_itlb_supervisor),
        .update_global(dt_update_itlb_global),
        .invalidate_en(dt_invalidate_tlb_en),
        .invalidate_all_en(dt_invalidate_tlb_all_en),
        .request_vpage_idx(cache_fetch_en ? pc_to_fetch[31-:PAGE_NUM_BITS] : dt_itlb_vpage_idx),
        .request_asid(cache_fetch_en ? cr_current_asid[selected_thread_idx] : dt_itlb_update_asid),
        .update_ppage_idx(dt_update_itlb_ppage_idx),
        .lookup_ppage_idx(tlb_ppage_idx),
        .lookup_hit(tlb_hit),
        .lookup_exe_writable(tlb_executable),
        .lookup_present(tlb_present),
        .lookup_supervisor(tlb_supervisor),
        .*);

    // These combinational signals are after the output flops of this stage (and
    // the TLB has one cycle of latency). All inputs to this should be registered.
    always_comb
    begin
        if (cr_mmu_en[ift_thread_idx])
        begin
            ift_tlb_hit = tlb_hit;
            ift_tlb_present = tlb_present;
            ift_tlb_executable = tlb_executable;
            ift_tlb_supervisor = tlb_supervisor;
            ppage_idx = tlb_ppage_idx;
        end
        else
        begin
            // MMU disabled, identity map.
            ift_tlb_hit = 1;
            ift_tlb_present = 1;
            ift_tlb_executable = 1;
            ift_tlb_supervisor = 0;
            ppage_idx = last_selected_pc[31-:PAGE_NUM_BITS];
        end
    end
`else
    // If MMU is disabled, identity map addresses
    assign ift_tlb_hit = 1;
    assign ift_tlb_present = 1;
    assign ift_executable = 1;
    assign ift_tlb_supervisor = 0;
    assign ppage_idx = last_selected_pc[31-:PAGE_NUM_BITS];
`endif

    cache_lru #(
        .NUM_WAYS(`L1D_WAYS),
        .NUM_SETS(`L1I_SETS)
    ) cache_lru(
        .fill_en(l2i_icache_lru_fill_en),
        .fill_set(l2i_icache_lru_fill_set),
        .fill_way(ift_fill_lru),
        .access_en(cache_fetch_en),
        .access_set(pc_to_fetch.set_idx),
        .access_update_en(ifd_update_lru_en),
        .access_update_way(ifd_update_lru_way),
        .*);

    //
    // Track which threads are waiting on instruction cache misses. Avoid fetching
    // them until the L2 cache fills the miss. If a rollback occurs while a thread
    // is waiting, wait until that miss to be filled by the L2 cache. This avoids
    // a race condition that would occur when that response subsequently arrived.
    //
    idx_to_oh #(.NUM_SIGNALS(`THREADS_PER_CORE)) idx_to_oh_miss_thread(
        .one_hot(cache_miss_thread_oh),
        .index(ifd_cache_miss_thread_idx));

    assign thread_sleep_mask_oh = cache_miss_thread_oh & {`THREADS_PER_CORE{ifd_cache_miss}};
    assign icache_wait_threads_nxt = (icache_wait_threads | thread_sleep_mask_oh)
        & ~l2i_icache_wake_bitmap;

    always_ff @(posedge clk, posedge reset)
    begin
        if (reset)
        begin
            /*AUTORESET*/
            // Beginning of autoreset for uninitialized flops
            icache_wait_threads <= '0;
            ift_instruction_requested <= '0;
            // End of automatics
        end
        else
        begin
            icache_wait_threads <= icache_wait_threads_nxt;
            ift_instruction_requested <= cache_fetch_en
                && !((ifd_cache_miss || ifd_near_miss) && ifd_cache_miss_thread_idx == selected_thread_idx)
                && !(wb_rollback_en && wb_rollback_thread_idx == selected_thread_idx);
        end
    end

    always_ff @(posedge clk)
    begin
        last_selected_pc <= pc_to_fetch;
        ift_thread_idx <= selected_thread_idx;
        last_selected_thread_oh <= selected_thread_oh;
    end

    assign ift_pc_paddr = {ppage_idx, last_selected_pc[31 - PAGE_NUM_BITS:0]};
    assign ift_pc_vaddr = last_selected_pc;
endmodule
