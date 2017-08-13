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
// L2 cache pipeline - read stage
// - Checks for cache hit.
// - Drives signals to update LRU flags in previous stage.
// - Reads cache memory
//   * If this is a restarted cache fill request and the replaced line
//     is dirty, reads the old data to that this will write back to
//     system memory.
//   * If this is a cache flush request and this was a cache hit, reads
//     the data in the line to write back.
//   * If this is a cache hit, reads the data in the line.
// - Drives signals to update dirty flags in previous stage
//   * If this is a flush request, clears the dirty bit
//   * If this is a store request, sets the dirty bit
// - Drives signals to update tags in prevous stage if this is a cache fill.
// - Tracks synchronized load/store state.
//

module l2_cache_read_stage(
    input                                     clk,
    input                                     reset,

    // From l2_cache_tag_stage
    input                                     l2t_request_valid,
    input l2req_packet_t                      l2t_request,
    input                                     l2t_valid[`L2_WAYS],
    input l2_tag_t                            l2t_tag[`L2_WAYS],
    input                                     l2t_dirty[`L2_WAYS],
    input                                     l2t_is_l2_fill,
    input                                     l2t_is_restarted_flush,
    input l2_way_idx_t                        l2t_fill_way,
    input cache_line_data_t                   l2t_data_from_memory,

    // To l2_cache_tag_stage
    // Update metadata.
    output logic[`L2_WAYS - 1:0]              l2r_update_dirty_en,
    output l2_set_idx_t                       l2r_update_dirty_set,
    output logic                              l2r_update_dirty_value,
    output logic[`L2_WAYS - 1:0]              l2r_update_tag_en,
    output l2_set_idx_t                       l2r_update_tag_set,
    output logic                              l2r_update_tag_valid,
    output l2_tag_t                           l2r_update_tag_value,
    output logic                              l2r_update_lru_en,
    output l2_way_idx_t                       l2r_update_lru_hit_way,

    // From l2_cache_update_stage
    input                                     l2u_write_en,
    input [$clog2(`L2_WAYS * `L2_SETS) - 1:0] l2u_write_addr,
    input cache_line_data_t                   l2u_write_data,

    // To l2_cache_update_stage
    output logic                              l2r_request_valid,
    output l2req_packet_t                     l2r_request,
    output cache_line_data_t                  l2r_data,    // Also to bus interface unit
    output logic                              l2r_cache_hit,
    output logic[$clog2(`L2_WAYS * `L2_SETS) - 1:0] l2r_hit_cache_idx,
    output logic                              l2r_is_l2_fill,
    output logic                              l2r_is_restarted_flush,
    output cache_line_data_t                  l2r_data_from_memory,
    output logic                              l2r_store_sync_success,

    // To l2_axi_bus_interface
    output l2_tag_t                           l2r_writeback_tag,
    output logic                              l2r_needs_writeback,

    // To performance_counters
    output logic                              l2r_perf_l2_miss,
    output logic                              l2r_perf_l2_hit);

    localparam GLOBAL_THREAD_IDX_WIDTH = $clog2(TOTAL_THREADS);

    // Track synchronized load/stores, and determine if a synchronized store
    // was successful.
    cache_line_index_t sync_load_address[TOTAL_THREADS];
    logic sync_load_address_valid[TOTAL_THREADS];
    logic can_store_sync;

    logic[`L2_WAYS - 1:0] hit_way_oh;
    logic cache_hit;
    l2_way_idx_t hit_way_idx;
    logic[$clog2(`L2_WAYS * `L2_SETS) - 1:0] read_address;
    logic is_load;
    logic is_store;
    logic update_dirty;
    logic update_tag;
    logic is_flush_first_pass;
    l2_way_idx_t writeback_way;
    logic is_hit_or_miss;
    logic is_dinvalidate;
    l2_way_idx_t tag_update_way;
    logic[GLOBAL_THREAD_IDX_WIDTH - 1:0] request_sync_slot;

    assign is_load = l2t_request.packet_type == L2REQ_LOAD
        || l2t_request.packet_type == L2REQ_LOAD_SYNC;
    assign is_store = l2t_request.packet_type == L2REQ_STORE
        || l2t_request.packet_type == L2REQ_STORE_SYNC;
    assign writeback_way = l2t_request.packet_type == L2REQ_FLUSH
        ? hit_way_idx : l2t_fill_way;
    assign is_dinvalidate = l2t_request.packet_type == L2REQ_DINVALIDATE;

    //
    // Check for cache hit
    //
    genvar way_idx;
    generate
        for (way_idx = 0; way_idx < `L2_WAYS; way_idx++)
        begin : hit_way_gen
            assign hit_way_oh[way_idx] = l2t_request.address.tag == l2t_tag[way_idx] && l2t_valid[way_idx];
        end
    endgenerate

    assign cache_hit = |hit_way_oh && l2t_request_valid;

    oh_to_idx #(.NUM_SIGNALS(`L2_WAYS)) oh_to_idx_hit_way(
        .one_hot(hit_way_oh),
        .index(hit_way_idx));

    // If this is a fill, read the old (potentially dirty line) so it can be written back.
    // If it is a cache hit, read the line data.
    assign read_address = {(l2t_is_l2_fill ? l2t_fill_way : hit_way_idx), l2t_request.address.set_idx};

    //
    // Cache memory
    //
    sram_1r1w #(
        .DATA_WIDTH(CACHE_LINE_BITS),
        .SIZE(`L2_WAYS * `L2_SETS),
        .READ_DURING_WRITE("NEW_DATA")
    ) sram_l2_data(
        .read_en(l2t_request_valid && (cache_hit || l2t_is_l2_fill)),
        .read_addr(read_address),
        .read_data(l2r_data),
        .write_en(l2u_write_en),
        .write_addr(l2u_write_addr),
        .write_data(l2u_write_data),
        .*);

    //
    // Update dirty bits. If this is a fill, initialize the dirty bit to the correct
    // value depending on whether this is a write. If it is a cache hit, update the
    // dirty bit only if this is a store.
    //
    assign is_flush_first_pass = l2t_request.packet_type == L2REQ_FLUSH
        && !l2t_is_restarted_flush;
    assign update_dirty = l2t_request_valid && (l2t_is_l2_fill
        || (cache_hit && (is_store || is_flush_first_pass)));
    assign l2r_update_dirty_set = l2t_request.address.set_idx;
    assign l2r_update_dirty_value = is_store;    // This is zero if this is a flush

    genvar dirty_update_idx;
    generate
        for (dirty_update_idx = 0; dirty_update_idx < `L2_WAYS; dirty_update_idx++)
        begin : dirty_update_gen
            assign l2r_update_dirty_en[dirty_update_idx] = update_dirty
                && (l2t_is_l2_fill ? l2t_fill_way == l2_way_idx_t'(dirty_update_idx)
                : hit_way_oh[dirty_update_idx]);
        end
    endgenerate

    //
    // Update tag memory. If this is a fill, make the new line valid. If it is an
    // invalidate make it invalid.
    //
    assign update_tag = l2t_is_l2_fill || (cache_hit && is_dinvalidate);
    assign tag_update_way = l2t_is_l2_fill ? l2t_fill_way : hit_way_idx;
    genvar tag_idx;
    generate
        for (tag_idx = 0; tag_idx < `L2_WAYS; tag_idx++)
        begin : tag_update_gen
            assign l2r_update_tag_en[tag_idx] = update_tag && tag_update_way == l2_way_idx_t'(tag_idx);
        end
    endgenerate

    assign l2r_update_tag_set = l2t_request.address.set_idx;
    assign l2r_update_tag_valid = !is_dinvalidate;
    assign l2r_update_tag_value = l2t_request.address.tag;

    //
    // Update LRU
    //
    assign l2r_update_lru_en = cache_hit && (is_load || is_store);
    assign l2r_update_lru_hit_way = hit_way_idx;

    //
    // Synchronized requests
    //
    assign request_sync_slot = GLOBAL_THREAD_IDX_WIDTH'({l2t_request.core, l2t_request.id});
    assign can_store_sync = sync_load_address[request_sync_slot]
        == {l2t_request.address.tag, l2t_request.address.set_idx}
        && sync_load_address_valid[request_sync_slot]
        && l2t_request.packet_type == L2REQ_STORE_SYNC;

    // Performance events
    assign is_hit_or_miss = l2t_request_valid && (l2t_request.packet_type == L2REQ_STORE || can_store_sync
        || l2t_request.packet_type == L2REQ_LOAD ) && !l2t_is_l2_fill;
    assign l2r_perf_l2_miss = is_hit_or_miss && !(|hit_way_oh);
    assign l2r_perf_l2_hit = is_hit_or_miss && |hit_way_oh;

    always_ff @(posedge clk)
    begin
        l2r_request <= l2t_request;
        l2r_cache_hit <= cache_hit;
        l2r_is_l2_fill <= l2t_is_l2_fill;
        l2r_writeback_tag <= l2t_tag[writeback_way];
        l2r_needs_writeback <= l2t_dirty[writeback_way] && l2t_valid[writeback_way];
        l2r_data_from_memory <= l2t_data_from_memory;
        l2r_hit_cache_idx <= read_address;
        l2r_is_restarted_flush <= l2t_is_restarted_flush;
    end

    always_ff @(posedge clk, posedge reset)
    begin
        if (reset)
        begin
            for (int i = 0; i < TOTAL_THREADS; i++)
            begin
                sync_load_address_valid[i] <= '0;
                sync_load_address[i] <= '0;
            end

            /*AUTORESET*/
            // Beginning of autoreset for uninitialized flops
            l2r_request_valid <= '0;
            l2r_store_sync_success <= '0;
            // End of automatics
        end
        else
        begin
            // A fill and cache hit cannot occur at the same time.
            assert(!l2t_is_l2_fill || !cache_hit);

            // Make sure there isn't a hit on more than one way
            assert(!l2t_request_valid || $onehot0(hit_way_oh));

            l2r_request_valid <= l2t_request_valid;

            if (l2t_request_valid && (cache_hit || l2t_is_l2_fill))
            begin
                // Track synchronized load/stores
                case (l2t_request.packet_type)
                    L2REQ_LOAD_SYNC:
                    begin
                        sync_load_address[request_sync_slot] <= {l2t_request.address.tag, l2t_request.address.set_idx};
                        sync_load_address_valid[request_sync_slot] <= 1;
                    end

                    L2REQ_STORE,
                    L2REQ_STORE_SYNC:
                    begin
                        // Don't invalidate if the sync store is not successful. Otherwise
                        // threads can livelock.
                        if (l2t_request.packet_type == L2REQ_STORE || can_store_sync)
                        begin
                            // Invalidate
                            for (int entry_idx = 0; entry_idx < TOTAL_THREADS; entry_idx++)
                            begin
                                if (sync_load_address[entry_idx] == {l2t_request.address.tag, l2t_request.address.set_idx})
                                    sync_load_address_valid[entry_idx] <= 0;
                            end
                        end
                    end

                    default:
                        ;
                endcase

                l2r_store_sync_success <= can_store_sync;
            end
            else
                l2r_store_sync_success <= 0;
        end
    end
endmodule
