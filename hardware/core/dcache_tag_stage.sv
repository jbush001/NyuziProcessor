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
// Instruction Pipeline L1 Data Cache Tag Stage.
// Contains tags and cache line states, which it queries when a memory access
// occurs. There is one cycle of latency to fetch these, so the next stage
// will handle the result. The L1 data cache is set associative. There is a
// separate block of tag ram for each way, which this reads in parallel. The
// next stage will check them to see if there is a cache hit on one of the
// ways. This also contains the translation lookaside buffer, which will
// convert the virtual memory address to a physical one. The cache is
// virtually indexed and physically tagged: the tag memories contain physical
// addresses, translated by the TLB.
//
// Snoop addresses from the l1_l2_interface are physical addresses, but the
// tag memory is virtually indexed. To avoid aliasing, the size of a way must
// be the same size or smaller than a virtual page
// (cache line size * num sets <= page_size).
//

module dcache_tag_stage
    (input                                      clk,
    input                                       reset,

    // From operand_fetch_stage
    input vector_t                              of_operand1,
    input vector_lane_mask_t                    of_mask_value,
    input vector_t                              of_store_value,
    input                                       of_instruction_valid,
    input decoded_instruction_t                 of_instruction,
    input local_thread_idx_t                    of_thread_idx,
    input subcycle_t                            of_subcycle,

    // From dcache_data_stage
    input                                       dd_update_lru_en,
    input l1d_way_idx_t                         dd_update_lru_way,

    // To dcache_data_stage
    output logic                                dt_instruction_valid,
    output decoded_instruction_t                dt_instruction,
    output vector_lane_mask_t                   dt_mask_value,
    output local_thread_idx_t                   dt_thread_idx,
    output l1d_addr_t                           dt_request_vaddr,
    output l1d_addr_t                           dt_request_paddr,
    output logic                                dt_tlb_hit,
    output logic                                dt_tlb_writable,
    output vector_t                             dt_store_value,
    output subcycle_t                           dt_subcycle,
    output logic                                dt_valid[`L1D_WAYS],
    output l1d_tag_t                            dt_tag[`L1D_WAYS],
    output logic                                dt_tlb_supervisor,
    output logic                                dt_tlb_present,

    // To ifetch_tag_stage
    output logic                                dt_invalidate_tlb_en,
    output logic                                dt_invalidate_tlb_all_en,
    output page_index_t                         dt_itlb_vpage_idx,
    output [ASID_WIDTH - 1:0]                   dt_itlb_update_asid,
    output logic                                dt_update_itlb_en,
    output page_index_t                         dt_update_itlb_ppage_idx,
    output logic                                dt_update_itlb_present,
    output logic                                dt_update_itlb_supervisor,
    output logic                                dt_update_itlb_global,
    output logic                                dt_update_itlb_executable,

    // From l1_l2_interface
    input                                       l2i_dcache_lru_fill_en,
    input l1d_set_idx_t                         l2i_dcache_lru_fill_set,
    input [`L1D_WAYS - 1:0]                     l2i_dtag_update_en_oh,
    input l1d_set_idx_t                         l2i_dtag_update_set,
    input l1d_tag_t                             l2i_dtag_update_tag,
    input                                       l2i_dtag_update_valid,
    input                                       l2i_snoop_en,
    input l1d_set_idx_t                         l2i_snoop_set,

    // To l1_l2_interface
    output logic                                dt_snoop_valid[`L1D_WAYS],
    output l1d_tag_t                            dt_snoop_tag[`L1D_WAYS],
    output l1d_way_idx_t                        dt_fill_lru,

    // From control_registers
    input                                       cr_mmu_en[`THREADS_PER_CORE],
    input logic                                 cr_supervisor_en[`THREADS_PER_CORE],
    input [ASID_WIDTH - 1:0]                    cr_current_asid[`THREADS_PER_CORE],

    // From writeback_stage
    input logic                                 wb_rollback_en,
    input local_thread_idx_t                    wb_rollback_thread_idx);

    l1d_addr_t request_addr_nxt;
    logic cache_load_en;
    logic instruction_valid;
    logic[$clog2(NUM_VECTOR_LANES) - 1:0] scgath_lane;
    page_index_t tlb_ppage_idx;
    logic tlb_hit;
    page_index_t ppage_idx;
    scalar_t fetched_addr;
    logic tlb_lookup_en;
    logic is_valid_cache_control;
    logic update_dtlb_en;
    logic tlb_writable;
    logic tlb_present;
    logic tlb_supervisor;
    tlb_entry_t new_tlb_value;

    assign instruction_valid = of_instruction_valid
        && (!wb_rollback_en || wb_rollback_thread_idx != of_thread_idx)
        && of_instruction.pipeline_sel == PIPE_MEM;
    assign is_valid_cache_control = instruction_valid
        && of_instruction.is_cache_control;
    assign cache_load_en = instruction_valid
        && of_instruction.memory_access_type != MEM_CONTROL_REG
        && of_instruction.is_memory_access      // Not cache control
        && of_instruction.is_load;
    assign scgath_lane = ~of_subcycle;
    assign request_addr_nxt = of_operand1[scgath_lane] + of_instruction.immediate_value;
    assign new_tlb_value = of_store_value[0];
    assign dt_invalidate_tlb_en = is_valid_cache_control
        && of_instruction.cache_control_op == CACHE_TLB_INVAL
        && cr_supervisor_en[of_thread_idx];
    assign dt_invalidate_tlb_all_en = is_valid_cache_control
        && of_instruction.cache_control_op == CACHE_TLB_INVAL_ALL
        && cr_supervisor_en[of_thread_idx];
    assign update_dtlb_en = is_valid_cache_control
        && of_instruction.cache_control_op == CACHE_DTLB_INSERT
        && cr_supervisor_en[of_thread_idx];
    assign dt_update_itlb_en = is_valid_cache_control
        && of_instruction.cache_control_op == CACHE_ITLB_INSERT
        && cr_supervisor_en[of_thread_idx];
    assign dt_update_itlb_supervisor = new_tlb_value.supervisor;
    assign dt_update_itlb_global = new_tlb_value.global_map;
    assign dt_update_itlb_present = new_tlb_value.present;
    assign tlb_lookup_en = instruction_valid
        && of_instruction.memory_access_type != MEM_CONTROL_REG
        && !update_dtlb_en
        && !dt_invalidate_tlb_en
        && !dt_invalidate_tlb_all_en;
    assign dt_itlb_vpage_idx = of_operand1[0][31-:PAGE_NUM_BITS];
    assign dt_update_itlb_ppage_idx = new_tlb_value.ppage_idx;
    assign dt_update_itlb_executable = new_tlb_value.executable;
    assign dt_itlb_update_asid = cr_current_asid[of_thread_idx];

    initial
    begin
        if (`L1D_SETS > 64 && `HAS_MMU)
        begin
            $display("Cannot use more than 64 dcache sets with MMU enabled");
            $finish;
        end
    end

    //
    // Way metadata
    //
    genvar way_idx;
    generate
        for (way_idx = 0; way_idx < `L1D_WAYS; way_idx++)
        begin : way_tag_gen
            // Valid flags are flops instead of SRAM because they need
            // to all be cleared on reset.
            logic line_valid[`L1D_SETS];

            sram_2r1w #(
                .DATA_WIDTH($bits(l1d_tag_t)),
                .SIZE(`L1D_SETS),
                .READ_DURING_WRITE("NEW_DATA")
            ) sram_tags(
                .read1_en(cache_load_en),
                .read1_addr(request_addr_nxt.set_idx),
                .read1_data(dt_tag[way_idx]),
                .read2_en(l2i_snoop_en),
                .read2_addr(l2i_snoop_set),
                .read2_data(dt_snoop_tag[way_idx]),
                .write_en(l2i_dtag_update_en_oh[way_idx]),
                .write_addr(l2i_dtag_update_set),
                .write_data(l2i_dtag_update_tag),
                .*);

            always_ff @(posedge clk, posedge reset)
            begin
                if (reset)
                begin
                    for (int set_idx = 0; set_idx < `L1D_SETS; set_idx++)
                        line_valid[set_idx] <= 0;
                end
                else
                begin
                    if (l2i_dtag_update_en_oh[way_idx])
                        line_valid[l2i_dtag_update_set] <= l2i_dtag_update_valid;
                end
            end

            always_ff @(posedge clk)
            begin
                // Fetch cache line state for pipeline
                if (cache_load_en)
                begin
                    if (l2i_dtag_update_en_oh[way_idx] && l2i_dtag_update_set == request_addr_nxt.set_idx)
                        dt_valid[way_idx] <= l2i_dtag_update_valid;    // Bypass
                    else
                        dt_valid[way_idx] <= line_valid[request_addr_nxt.set_idx];
                end

                // Fetch cache line state for snoop
                if (l2i_snoop_en)
                begin
                    if (l2i_dtag_update_en_oh[way_idx] && l2i_dtag_update_set == l2i_snoop_set)
                        dt_snoop_valid[way_idx] <= l2i_dtag_update_valid;    // Bypass
                    else
                        dt_snoop_valid[way_idx] <= line_valid[l2i_snoop_set];
                end
            end
        end
    endgenerate

`ifdef HAS_MMU
    tlb #(
        .NUM_ENTRIES(`DTLB_ENTRIES),
        .NUM_WAYS(`TLB_WAYS)
    ) dtlb(
        .lookup_en(tlb_lookup_en),
        .update_en(update_dtlb_en),
        .invalidate_en(dt_invalidate_tlb_en),
        .invalidate_all_en(dt_invalidate_tlb_all_en),
        .request_vpage_idx(request_addr_nxt[31-:PAGE_NUM_BITS]),
        .request_asid(cr_current_asid[of_thread_idx]),
        .update_ppage_idx(new_tlb_value.ppage_idx),
        .update_present(new_tlb_value.present),
        .update_exe_writable(new_tlb_value.writable),
        .update_supervisor(new_tlb_value.supervisor),
        .update_global(new_tlb_value.global_map),
        .lookup_ppage_idx(tlb_ppage_idx),
        .lookup_hit(tlb_hit),
        .lookup_present(tlb_present),
        .lookup_exe_writable(tlb_writable),
        .lookup_supervisor(tlb_supervisor),
        .*);

    // This combinational logic is after the flip flops,
    // so these signals are delayed one cycle from other signals
    // in this module.
    always_comb
    begin
        if (cr_mmu_en[dt_thread_idx])
        begin
            dt_tlb_hit = tlb_hit;
            dt_tlb_writable = tlb_writable;
            dt_tlb_present = tlb_present;
            dt_tlb_supervisor = tlb_supervisor;
            ppage_idx = tlb_ppage_idx;
        end
        else
        begin
            dt_tlb_hit = 1;
            dt_tlb_writable = 1;
            dt_tlb_present = 1;
            dt_tlb_supervisor = 0;
            ppage_idx = fetched_addr[31-:PAGE_NUM_BITS];
        end
    end
`else
    // If MMU is disabled, identity map addresses
    assign dt_tlb_hit = 1;
    assign dt_tlb_writable = 1;
    assign dt_tlb_present = 1;
    assign ppage_idx = fetched_addr[31-:PAGE_NUM_BITS];
`endif

    cache_lru #(
        .NUM_WAYS(`L1D_WAYS),
        .NUM_SETS(`L1D_SETS)
    ) lru(
        .fill_en(l2i_dcache_lru_fill_en),
        .fill_set(l2i_dcache_lru_fill_set),
        .fill_way(dt_fill_lru),
        .access_en(instruction_valid),
        .access_set(request_addr_nxt.set_idx),
        .access_update_en(dd_update_lru_en),
        .access_update_way(dd_update_lru_way),
        .*);

    always_ff @(posedge clk)
    begin
        dt_instruction <= of_instruction;
        dt_mask_value <= of_mask_value;
        dt_thread_idx <= of_thread_idx;
        dt_store_value <= of_store_value;
        dt_subcycle <= of_subcycle;
        fetched_addr <= request_addr_nxt;
    end

    always_ff @(posedge clk, posedge reset)
    begin
        if (reset)
            dt_instruction_valid <= '0;
        else
        begin
            assert($onehot0(l2i_dtag_update_en_oh));
            dt_instruction_valid <= instruction_valid;
        end
    end

    assign dt_request_paddr = {ppage_idx, fetched_addr[31 - PAGE_NUM_BITS:0]};
    assign dt_request_vaddr = fetched_addr;
endmodule
