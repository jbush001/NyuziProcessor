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
// Instruction Pipeline - Instruction Fetch Data Stage
// - If PC selected in the ifetch_tag_stage is in the instruction cache, reads
//   the contents of the cache line.
// - Drives signals to update LRU in previous stage
// - Detects alignment fault and TLB misses.
//

module ifetch_data_stage(
    input                            clk,
    input                            reset,

    // From ifetch_tag_stage.
    // If ift_instruction_requested is low, the other signals in this group are
    // undefined.
    input                            ift_instruction_requested,
    input l1i_addr_t                 ift_pc_paddr,
    input scalar_t                   ift_pc_vaddr,
    input local_thread_idx_t         ift_thread_idx,
    input                            ift_tlb_hit,
    input                            ift_tlb_present,
    input                            ift_tlb_executable,
    input                            ift_tlb_supervisor,
    input l1i_tag_t                  ift_tag[`L1D_WAYS],
    input                            ift_valid[`L1D_WAYS],

    // To ifetch_tag_stage
    output logic                     ifd_update_lru_en,
    output l1i_way_idx_t             ifd_update_lru_way,
    output logic                     ifd_near_miss,

    // From l1_l2_interface
    input                            l2i_idata_update_en,
    input l1i_way_idx_t              l2i_idata_update_way,
    input l1i_set_idx_t              l2i_idata_update_set,
    input cache_line_data_t          l2i_idata_update_data,
    input [`L1I_WAYS - 1:0]          l2i_itag_update_en,
    input l1i_set_idx_t              l2i_itag_update_set,
    input l1i_tag_t                  l2i_itag_update_tag,

    // To l1_l2_interface
    output logic                     ifd_cache_miss,
    output cache_line_index_t        ifd_cache_miss_paddr,
    output local_thread_idx_t        ifd_cache_miss_thread_idx,    // also to ifetch_tag

    // From control registers
    input logic                      cr_supervisor_en[`THREADS_PER_CORE],

    // To instruction_decode_stage
    output scalar_t                  ifd_instruction,
    output logic                     ifd_instruction_valid,
    output scalar_t                  ifd_pc,
    output local_thread_idx_t        ifd_thread_idx,
    output logic                     ifd_alignment_fault,
    output logic                     ifd_tlb_miss,
    output logic                     ifd_supervisor_fault,
    output logic                     ifd_page_fault,
    output logic                     ifd_executable_fault,

    // From writeback_stage
    input                            wb_rollback_en,
    input local_thread_idx_t         wb_rollback_thread_idx,

    // To performance_counters
    output logic                     ifd_perf_icache_hit,
    output logic                     ifd_perf_icache_miss,
    output logic                     ifd_perf_itlb_miss);

    logic cache_hit;
    logic[`L1I_WAYS - 1:0] way_hit_oh;
    l1i_way_idx_t way_hit_idx;
    logic[CACHE_LINE_BITS - 1:0] fetched_cache_line;
    scalar_t fetched_word;
    logic[$clog2(CACHE_LINE_WORDS) - 1:0] cache_lane_idx;
    logic alignment_fault;
    logic rollback_this_stage;

    //
    // Check for cache hit
    //
    genvar way_idx;
    generate
        for (way_idx = 0; way_idx < `L1I_WAYS; way_idx++)
        begin : hit_check_gen
            assign way_hit_oh[way_idx] = ift_pc_paddr.tag == ift_tag[way_idx]
                && ift_valid[way_idx];
        end
    endgenerate

    assign cache_hit = |way_hit_oh && ift_tlb_hit;

    oh_to_idx #(.NUM_SIGNALS(`L1D_WAYS)) oh_to_idx_hit_way(
        .one_hot(way_hit_oh),
        .index(way_hit_idx));

    // ifd_near_miss is high if the cache line requested in the last stage
    // is filled this cycle. Treating this as a cache miss would fetch
    // duplicate lines into the cache set. Blocking the thread would hang
    // (because the wakeup signal is happening this cycle). The cache interface
    // updates the tag, then the data a cycle later, so the data will appear in
    // the next cycle. In order to pick up the data, this signal goes back to
    // the previous stage to make it retry the same PC.
    assign ifd_near_miss = !cache_hit
        && ift_tlb_hit
        && ift_instruction_requested
        && |l2i_itag_update_en
        && l2i_itag_update_set == ift_pc_paddr.set_idx
        && l2i_itag_update_tag == ift_pc_paddr.tag;
    assign ifd_cache_miss = !cache_hit
        && ift_tlb_hit
        && ift_instruction_requested
        && !ifd_near_miss;
    assign ifd_cache_miss_paddr = {ift_pc_paddr.tag, ift_pc_paddr.set_idx};
    assign ifd_cache_miss_thread_idx = ift_thread_idx;
    assign ifd_perf_icache_hit = cache_hit && ift_instruction_requested;
    assign ifd_perf_icache_miss = !cache_hit && ift_tlb_hit && ift_instruction_requested;
    assign ifd_perf_itlb_miss = ift_instruction_requested && !ift_tlb_hit;
    assign alignment_fault = ift_pc_paddr[1:0] != 0;

    //
    // Cache data
    //
    sram_1r1w #(
        .DATA_WIDTH(CACHE_LINE_BITS),
        .SIZE(`L1I_WAYS * `L1I_SETS),
        .READ_DURING_WRITE("NEW_DATA")
    ) sram_l1i_data(
        .read_en(cache_hit && ift_instruction_requested),
        .read_addr({way_hit_idx, ift_pc_paddr.set_idx}),
        .read_data(fetched_cache_line),
        .write_en(l2i_idata_update_en),
        .write_addr({l2i_idata_update_way, l2i_idata_update_set}),
        .write_data(l2i_idata_update_data),
        .*);

    assign cache_lane_idx = ~ifd_pc[CACHE_LINE_OFFSET_WIDTH - 1:2];
    assign fetched_word = fetched_cache_line[32 * cache_lane_idx+:32];
    assign ifd_instruction = {fetched_word[7:0], fetched_word[15:8], fetched_word[23:16], fetched_word[31:24]};

    assign ifd_update_lru_en = cache_hit && ift_instruction_requested;
    assign ifd_update_lru_way = way_hit_idx;
    assign rollback_this_stage = wb_rollback_en && wb_rollback_thread_idx
        == ift_thread_idx;

    always_ff @(posedge clk)
    begin
        ifd_pc <= ift_pc_vaddr;
        ifd_thread_idx <= ift_thread_idx;
    end

    always_ff @(posedge clk, posedge reset)
    begin
        if (reset)
        begin
            /*AUTORESET*/
            // Beginning of autoreset for uninitialized flops
            ifd_alignment_fault <= '0;
            ifd_executable_fault <= '0;
            ifd_instruction_valid <= '0;
            ifd_page_fault <= '0;
            ifd_supervisor_fault <= '0;
            ifd_tlb_miss <= '0;
            // End of automatics
        end
        else
        begin
            // Ensure more than one way isn't a hit (way_hit_oh is undefined
            // if an instruction wasn't requested).
            assert(!ift_instruction_requested || $onehot0(way_hit_oh));

            ifd_instruction_valid <= ift_instruction_requested && !rollback_this_stage
                && cache_hit && ift_tlb_hit && !alignment_fault;
            ifd_alignment_fault <= ift_instruction_requested && !rollback_this_stage
                && alignment_fault;
            ifd_supervisor_fault <= ift_instruction_requested && ift_tlb_supervisor
                && !cr_supervisor_en[ift_thread_idx];
            ifd_tlb_miss <= ift_instruction_requested && !rollback_this_stage
                && !ift_tlb_hit;
            ifd_page_fault <= ift_instruction_requested && !rollback_this_stage
                && !ift_tlb_present;
            ifd_executable_fault <= ift_instruction_requested && !rollback_this_stage
                && !ift_tlb_executable;
        end
    end
endmodule
