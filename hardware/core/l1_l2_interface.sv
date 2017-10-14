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
// This module is in each core and handles communications between
// L1 and L2 caches. It hides the L2 protocol from the execution pipeline,
// making it easier to experiment with alternate protocols and interconnects.
// Additional things this module handles:
// - Tracks pending load misses from L1 instruction and data caches
//   (l1_load_miss_queue).
// - Tracks pending stores from pipeline (l1_store_queue).
// - Arbitrates miss sources and sends L2 cache requests.
// - Processes L2 responses, updating L1 instruction and data caches.
//
// This processes L2 responses using a three stage pipeline:
// 1. Sends store address from the response to L1D tag memory (which
//    has one cycle of latency) to snoop it.
// 2. Checks the snoop responses. If the data are in the cache, selects the
//    way for update. For load responses, update tag memory.
// 3. Update L1D data memory. It must do this a cycle after updating the
//    tags to avoid a race condition becausethey are checked in this sequence
//    by the instruction pipeline during load accesses.
//
// l2i_request_valid does not depend combinationally on l2_ready (to avoid a
// loop), but the opposite is not true (see l2_cache_arb_stage).
//

module l1_l2_interface
    #(parameter CORE_ID = 0)
    (input                                        clk,
    input                                         reset,

    // From l2_cache
    input                                         l2_ready,
    input                                         l2_response_valid,
    input l2rsp_packet_t                          l2_response,

    // To l2_cache
    output logic                                  l2i_request_valid,
    output l2req_packet_t                         l2i_request,

    // To ifetch_tag_stage
    output logic                                  l2i_icache_lru_fill_en,
    output l1i_set_idx_t                          l2i_icache_lru_fill_set,
    output logic[`L1I_WAYS - 1:0]                 l2i_itag_update_en,
    output l1i_set_idx_t                          l2i_itag_update_set,
    output l1i_tag_t                              l2i_itag_update_tag,
    output logic                                  l2i_itag_update_valid,

    // To instruction_decode_stage
    output local_thread_bitmap_t                  sq_sync_store_pending,

    // From ifetch_tag_stage
    input l1i_way_idx_t                           ift_fill_lru,

    // From ifetch_data_stage
    input logic                                   ifd_cache_miss,
    input cache_line_index_t                      ifd_cache_miss_paddr,
    input local_thread_idx_t                      ifd_cache_miss_thread_idx,

    // To ifetch_data_stage
    output logic                                  l2i_idata_update_en,
    output l1i_way_idx_t                          l2i_idata_update_way,
    output l1i_set_idx_t                          l2i_idata_update_set,
    output cache_line_data_t                      l2i_idata_update_data,

    // To thread_select_stage
    output local_thread_bitmap_t                  l2i_dcache_wake_bitmap,
    output local_thread_bitmap_t                  l2i_icache_wake_bitmap,

    // From dcache_tag_stage
    input logic                                   dt_snoop_valid[`L1D_WAYS],
    input l1d_tag_t                               dt_snoop_tag[`L1D_WAYS],
    input l1d_way_idx_t                           dt_fill_lru,

    // To dcache_tag_stage
    output logic                                  l2i_snoop_en,
    output l1d_set_idx_t                          l2i_snoop_set,
    output logic[`L1D_WAYS - 1:0]                 l2i_dtag_update_en_oh,
    output l1d_set_idx_t                          l2i_dtag_update_set,
    output l1d_tag_t                              l2i_dtag_update_tag,
    output logic                                  l2i_dtag_update_valid,
    output logic                                  l2i_dcache_lru_fill_en,
    output l1d_set_idx_t                          l2i_dcache_lru_fill_set,

    // From dcache_data_stage
    input                                         dd_cache_miss,
    input cache_line_index_t                      dd_cache_miss_addr,
    input local_thread_idx_t                      dd_cache_miss_thread_idx,
    input                                         dd_cache_miss_sync,
    input                                         dd_store_en,
    input                                         dd_flush_en,
    input                                         dd_membar_en,
    input                                         dd_iinvalidate_en,
    input                                         dd_dinvalidate_en,
    input [CACHE_LINE_BYTES - 1:0]                dd_store_mask,
    input cache_line_index_t                      dd_store_addr,
    input cache_line_data_t                       dd_store_data,
    input local_thread_idx_t                      dd_store_thread_idx,
    input                                         dd_store_sync,
    input cache_line_index_t                      dd_store_bypass_addr,
    input local_thread_idx_t                      dd_store_bypass_thread_idx,

    // To dcache_data_stage
    output logic                                  l2i_ddata_update_en,
    output l1d_way_idx_t                          l2i_ddata_update_way,
    output l1d_set_idx_t                          l2i_ddata_update_set,
    output cache_line_data_t                      l2i_ddata_update_data,

    // To writeback_stage
    output logic[CACHE_LINE_BYTES - 1:0]          sq_store_bypass_mask,
    output logic                                  sq_store_sync_success,
    output cache_line_data_t                      sq_store_bypass_data,
    output logic                                  sq_rollback_en);

    logic[`L1D_WAYS - 1:0] snoop_hit_way_oh;    // Only snoops dcache
    l1d_way_idx_t snoop_hit_way_idx;
    logic[`L1I_WAYS - 1:0] ifill_way_oh;
    logic[`L1D_WAYS - 1:0] dupdate_way_oh;
    l1d_way_idx_t dupdate_way_idx;
    logic is_ack_for_me;
    logic icache_update_en;
    logic dcache_update_en;
    logic dcache_l2_response_valid;
    l1_miss_entry_idx_t dcache_l2_response_idx;
    logic icache_l2_response_valid;
    l1_miss_entry_idx_t icache_l2_response_idx;
    logic storebuf_l2_response_valid;
    l1_miss_entry_idx_t storebuf_l2_response_idx;
    local_thread_bitmap_t dcache_miss_wake_bitmap;
    logic sq_dequeue_ack;
    logic icache_dequeue_ready;
    logic icache_dequeue_ack;
    logic dcache_dequeue_ready;
    logic dcache_dequeue_ack;
    cache_line_index_t dcache_dequeue_addr;
    logic dcache_dequeue_sync;
    cache_line_index_t icache_dequeue_addr;
    l1_miss_entry_idx_t dcache_dequeue_idx;
    l1_miss_entry_idx_t icache_dequeue_idx;
    logic response_stage2_valid;
    l2rsp_packet_t response_stage2;
    l1d_set_idx_t dcache_set_stage1;
    l1i_set_idx_t icache_set_stage1;
    l1d_set_idx_t dcache_set_stage2;
    l1d_set_idx_t icache_set_stage2;
    l1d_tag_t dcache_tag_stage2;
    l1i_tag_t icache_tag_stage2;
    logic storebuf_l2_sync_success;
    logic response_is_iinvalidate;
    logic response_is_dinvalidate;

    /*AUTOLOGIC*/
    // Beginning of automatic wires (for undeclared instantiated-module outputs)
    cache_line_index_t  sq_dequeue_addr;        // From l1_store_queue of l1_store_queue.v
    cache_line_data_t   sq_dequeue_data;        // From l1_store_queue of l1_store_queue.v
    logic               sq_dequeue_dinvalidate; // From l1_store_queue of l1_store_queue.v
    logic               sq_dequeue_flush;       // From l1_store_queue of l1_store_queue.v
    l1_miss_entry_idx_t sq_dequeue_idx;         // From l1_store_queue of l1_store_queue.v
    logic               sq_dequeue_iinvalidate; // From l1_store_queue of l1_store_queue.v
    logic [CACHE_LINE_BYTES-1:0] sq_dequeue_mask;// From l1_store_queue of l1_store_queue.v
    logic               sq_dequeue_ready;       // From l1_store_queue of l1_store_queue.v
    logic               sq_dequeue_sync;        // From l1_store_queue of l1_store_queue.v
    local_thread_bitmap_t sq_wake_bitmap;       // From l1_store_queue of l1_store_queue.v
    // End of automatics

    l1_store_queue l1_store_queue(.*);

    l1_load_miss_queue l1_load_miss_queue_dcache(
        // Enqueue requests
        .cache_miss(dd_cache_miss),
        .cache_miss_addr(dd_cache_miss_addr),
        .cache_miss_thread_idx(dd_cache_miss_thread_idx),
        .cache_miss_sync(dd_cache_miss_sync),

        // Next request
        .dequeue_ready(dcache_dequeue_ready),
        .dequeue_ack(dcache_dequeue_ack),
        .dequeue_addr(dcache_dequeue_addr),
        .dequeue_idx(dcache_dequeue_idx),
        .dequeue_sync(dcache_dequeue_sync),

        // Wake threads when a transaction is complete
        .l2_response_valid(dcache_l2_response_valid),
        .l2_response_idx(dcache_l2_response_idx),
        .wake_bitmap(dcache_miss_wake_bitmap),
        .*);

    assign l2i_dcache_wake_bitmap = dcache_miss_wake_bitmap | sq_wake_bitmap;

    l1_load_miss_queue l1_load_miss_queue_icache(
        // Enqueue requests
        .cache_miss(ifd_cache_miss),
        .cache_miss_addr(ifd_cache_miss_paddr),
        .cache_miss_thread_idx(ifd_cache_miss_thread_idx),
        .cache_miss_sync('0),

        // Next request
        .dequeue_ready(icache_dequeue_ready),
        .dequeue_ack(icache_dequeue_ack),
        .dequeue_addr(icache_dequeue_addr),
        .dequeue_idx(icache_dequeue_idx),
        .dequeue_sync(),

        // Wake threads when a transaction is complete
        .l2_response_valid(icache_l2_response_valid),
        .l2_response_idx(icache_l2_response_idx),
        .wake_bitmap(l2i_icache_wake_bitmap),
        .*);

    /////////////////////////////////////////////////
    // Response pipeline stage 1
    /////////////////////////////////////////////////

    assign dcache_set_stage1 = l2_response.address[$clog2(`L1D_SETS) - 1:0];
    assign icache_set_stage1 = l2_response.address[$clog2(`L1I_SETS) - 1:0];
    assign l2i_snoop_en = l2_response_valid && l2_response.cache_type == CT_DCACHE;
    assign l2i_snoop_set = dcache_set_stage1;
    assign l2i_dcache_lru_fill_en = l2_response_valid && l2_response.cache_type == CT_DCACHE
        && l2_response.packet_type == L2RSP_LOAD_ACK && l2_response.core == CORE_ID;
    assign l2i_dcache_lru_fill_set = dcache_set_stage1;
    assign l2i_icache_lru_fill_en = l2_response_valid && l2_response.cache_type == CT_ICACHE
        && l2_response.packet_type == L2RSP_LOAD_ACK && l2_response.core == CORE_ID;
    assign l2i_icache_lru_fill_set = icache_set_stage1;

    always_ff @(posedge clk, posedge reset)
    begin
        if (reset)
            response_stage2_valid <= 0;
        else
        begin
            // Should not get a wake from miss queue and store queue in the same cycle.
            assert((dcache_miss_wake_bitmap & sq_wake_bitmap) == 0);
            response_stage2_valid <= l2_response_valid;
        end
    end

    always_ff @(posedge clk)
        response_stage2 <= l2_response;

    /////////////////////////////////////////////////
    // Response pipeline stage 2
    /////////////////////////////////////////////////

    assign {icache_tag_stage2, icache_set_stage2} = response_stage2.address;
    assign {dcache_tag_stage2, dcache_set_stage2} = response_stage2.address;

    //
    // Check snoop result
    //
    genvar way_idx;
    generate
        for (way_idx = 0; way_idx < `L1D_WAYS; way_idx++)
        begin : snoop_hit_check_gen
            assign snoop_hit_way_oh[way_idx] = dt_snoop_tag[way_idx] == dcache_tag_stage2
                && dt_snoop_valid[way_idx];
        end
    endgenerate

    oh_to_idx #(.NUM_SIGNALS(`L1D_WAYS)) convert_snoop_request_pending(
        .index(snoop_hit_way_idx),
        .one_hot(snoop_hit_way_oh));

    //
    // Determine fill way. If this data is already in this cache set, update the
    // way that has the data. This handles write updates and cache synonyms
    // (two virtual addresses point to the same physical address).
    //
    always_comb
    begin
        if (|snoop_hit_way_oh)
            dupdate_way_idx = snoop_hit_way_idx; // Update existing dcache line
        else
            dupdate_way_idx = dt_fill_lru;     // Fill new dcache line
    end

    idx_to_oh #(.NUM_SIGNALS(`L1D_WAYS)) idx_to_oh_dfill_way(
        .index(dupdate_way_idx),
        .one_hot(dupdate_way_oh));

    idx_to_oh #(.NUM_SIGNALS(`L1D_WAYS)) idx_to_oh_ifill_way(
        .index(ift_fill_lru),
        .one_hot(ifill_way_oh));

    assign is_ack_for_me = response_stage2_valid && response_stage2.core == CORE_ID;

    //
    // Update data cache tag
    //
    assign response_is_dinvalidate = response_stage2.packet_type == L2RSP_DINVALIDATE_ACK;
    assign dcache_update_en = (is_ack_for_me && ((response_stage2.packet_type == L2RSP_LOAD_ACK
        && response_stage2.cache_type == CT_DCACHE) || response_stage2.packet_type == L2RSP_STORE_ACK))
        || (response_stage2_valid && response_is_dinvalidate && |snoop_hit_way_oh);
    assign l2i_dtag_update_en_oh = dupdate_way_oh & {`L1D_WAYS{dcache_update_en}};
    assign l2i_dtag_update_tag = dcache_tag_stage2;
    assign l2i_dtag_update_set = dcache_set_stage2;
    assign l2i_dtag_update_valid = !response_is_dinvalidate;

    //
    // Update instruction cache tag. For a fill, mark the line valid and update the tag.
    // For a invalidate, mark all ways for the selected set invalid
    //
    assign response_is_iinvalidate = response_stage2_valid
        && response_stage2.packet_type == L2RSP_IINVALIDATE_ACK;
    assign icache_update_en = (is_ack_for_me && response_stage2.cache_type == CT_ICACHE)
        || response_is_iinvalidate;
    assign l2i_itag_update_en = response_is_iinvalidate ? {`L1I_WAYS{1'b1}}
        : (ifill_way_oh & {`L1I_WAYS{icache_update_en}});
    assign l2i_itag_update_tag = icache_tag_stage2;
    assign l2i_itag_update_set = icache_set_stage2;
    assign l2i_itag_update_valid = !response_is_iinvalidate;

    // Wake up entries that have had their miss satisfied.
    assign icache_l2_response_valid = is_ack_for_me && response_stage2.cache_type == CT_ICACHE;
    assign dcache_l2_response_valid = is_ack_for_me && response_stage2.packet_type == L2RSP_LOAD_ACK
        && response_stage2.cache_type == CT_DCACHE;
    assign storebuf_l2_response_valid = is_ack_for_me
        && (response_stage2.packet_type == L2RSP_STORE_ACK
        || response_stage2.packet_type == L2RSP_FLUSH_ACK
        || response_stage2.packet_type == L2RSP_IINVALIDATE_ACK
        || response_stage2.packet_type == L2RSP_DINVALIDATE_ACK);
    assign dcache_l2_response_idx = response_stage2.id;
    assign icache_l2_response_idx = response_stage2.id;
    assign storebuf_l2_response_idx = response_stage2.id;
    assign storebuf_l2_sync_success = response_stage2.status;

    /////////////////////////////////////////////////
    // Response pipeline stage 3
    /////////////////////////////////////////////////

    always_ff @(posedge clk)
    begin
        l2i_ddata_update_way <= dupdate_way_idx;
        l2i_ddata_update_set <= dcache_set_stage2;
        l2i_ddata_update_data <= response_stage2.data;
        l2i_idata_update_way <= ift_fill_lru;
        l2i_idata_update_set <= icache_set_stage2;
        l2i_idata_update_data <= response_stage2.data;
    end

    always_ff @(posedge clk, posedge reset)
    begin
        if (reset)
        begin
            /*AUTORESET*/
            // Beginning of autoreset for uninitialized flops
            l2i_ddata_update_en <= '0;
            l2i_idata_update_en <= '0;
            // End of automatics
        end
        else
        begin
            // Make sure more than one snoop way isn't a hit
            assert(!response_stage2_valid || response_stage2.cache_type != CT_DCACHE
                || $onehot0(snoop_hit_way_oh));

            // Ensure only one dequeue type is set
            assert(!sq_dequeue_ready || $onehot0({sq_dequeue_flush, sq_dequeue_iinvalidate,
                sq_dequeue_dinvalidate}));

            // These are latched to delay then one cycle from the tag updates
            // Update cache line for data cache
            l2i_ddata_update_en <= dcache_update_en || (|snoop_hit_way_oh && response_stage2_valid
                && response_stage2.packet_type == L2RSP_STORE_ACK);

            // Update cache line for instruction cache
            l2i_idata_update_en <= icache_update_en;
        end
    end

    /////////////////////////////////////////////////
    // Request logic
    /////////////////////////////////////////////////

    always_comb
    begin
        l2i_request_valid = 0;
        l2i_request = 0;
        sq_dequeue_ack = 0;
        icache_dequeue_ack = 0;
        dcache_dequeue_ack = 0;

        l2i_request.core = CORE_ID;

        // Assert the request
        if (dcache_dequeue_ready)
        begin
            // Send data cache request packet
            l2i_request_valid = 1;
            l2i_request.packet_type = dcache_dequeue_sync ? L2REQ_LOAD_SYNC : L2REQ_LOAD;
            l2i_request.id = dcache_dequeue_idx;
            l2i_request.address = dcache_dequeue_addr;
            l2i_request.cache_type = CT_DCACHE;
        end
        else if (icache_dequeue_ready)
        begin
            // Send instruction cache request packet
            l2i_request_valid = 1;
            l2i_request.packet_type = L2REQ_LOAD;
            l2i_request.id = icache_dequeue_idx;
            l2i_request.address = icache_dequeue_addr;
            l2i_request.cache_type = CT_ICACHE;
        end
        else if (sq_dequeue_ready)
        begin
            // Send store request
            l2i_request_valid = 1;
            if (sq_dequeue_flush)
                l2i_request.packet_type = L2REQ_FLUSH;
            else if (sq_dequeue_sync)
                l2i_request.packet_type = L2REQ_STORE_SYNC;
            else if (sq_dequeue_iinvalidate)
                l2i_request.packet_type = L2REQ_IINVALIDATE;
            else if (sq_dequeue_dinvalidate)
                l2i_request.packet_type = L2REQ_DINVALIDATE;
            else
                l2i_request.packet_type = L2REQ_STORE;

            l2i_request.id = sq_dequeue_idx;
            l2i_request.address = sq_dequeue_addr;
            l2i_request.data = sq_dequeue_data;
            l2i_request.store_mask = sq_dequeue_mask;
            l2i_request.cache_type = CT_DCACHE;
        end

        if (l2_ready)
        begin
            // Request acknowledged, mark it as sent
            if (dcache_dequeue_ready)
                dcache_dequeue_ack = 1;
            else if (icache_dequeue_ready)
                icache_dequeue_ack = 1;
            else if (sq_dequeue_ready)
                sq_dequeue_ack = 1;
        end
    end
endmodule
