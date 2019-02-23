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
// L2 cache pipeline - update stage.
// - Update cache data if this is a cache fill or store.
//   This applies the store mask and requested data to the original data.
// - Sends response packet to cores.
//

module l2_cache_update_stage(
    input                                          clk,
    input                                          reset,

    // From l2_cache_read_stage
    input                                          l2r_request_valid,
    input l2req_packet_t                           l2r_request,
    input cache_line_data_t                        l2r_data,
    input                                          l2r_cache_hit,
    input logic[$clog2(`L2_WAYS * `L2_SETS) - 1:0] l2r_hit_cache_idx,
    input                                          l2r_l2_fill,
    input                                          l2r_restarted_flush,
    input cache_line_data_t                        l2r_data_from_memory,
    input                                          l2r_store_sync_success,
    input                                          l2r_needs_writeback,

    // To l2_cache_read_stage
    output logic                                   l2u_write_en,
    output logic[$clog2(`L2_WAYS * `L2_SETS) - 1:0] l2u_write_addr,
    output cache_line_data_t                       l2u_write_data,

    // To cores
    output logic                                   l2_response_valid,
    output l2rsp_packet_t                          l2_response);

    cache_line_data_t original_data;
    logic update_data;
    l2rsp_packet_type_t response_type;
    logic completed_flush;

    assign original_data = l2r_l2_fill ? l2r_data_from_memory : l2r_data;
    assign update_data = l2r_request.packet_type == L2REQ_STORE
        || (l2r_request.packet_type == L2REQ_STORE_SYNC && l2r_store_sync_success);

    genvar byte_lane;
    generate
        for (byte_lane = 0; byte_lane < CACHE_LINE_BYTES; byte_lane++)
        begin : lane_mask_gen
            assign l2u_write_data[byte_lane * 8+:8] = (l2r_request.store_mask[byte_lane] && update_data)
                ? l2r_request.data[byte_lane * 8+:8]
                : original_data[byte_lane * 8+:8];
        end
    endgenerate

    assign l2u_write_en = l2r_request_valid
        && (l2r_l2_fill || (l2r_cache_hit && (l2r_request.packet_type == L2REQ_STORE
        || l2r_request.packet_type == L2REQ_STORE_SYNC)));
    assign l2u_write_addr = l2r_hit_cache_idx;

    // Response packet type
    always_comb
    begin
        unique case (l2r_request.packet_type)
            L2REQ_LOAD,
            L2REQ_LOAD_SYNC:
                response_type = L2RSP_LOAD_ACK;

            L2REQ_STORE,
            L2REQ_STORE_SYNC:
                response_type = L2RSP_STORE_ACK;

            L2REQ_FLUSH:
                response_type = L2RSP_FLUSH_ACK;

            L2REQ_IINVALIDATE:
                response_type = L2RSP_IINVALIDATE_ACK;

            L2REQ_DINVALIDATE:
                response_type = L2RSP_DINVALIDATE_ACK;

            default:
                response_type = L2RSP_LOAD_ACK;
        endcase
    end

    // Check that this is either:
    // - The first pass for a flush request and the data wasn't in the cache
    // - The second pass for a flush request that has written its data back
    assign completed_flush = l2r_request.packet_type == L2REQ_FLUSH
        && (l2r_restarted_flush || !l2r_cache_hit || !l2r_needs_writeback);

    always_ff @(posedge clk, posedge reset)
    begin
        if (reset)
            l2_response_valid <= 0;
        else
        begin
            if (l2r_request_valid
                && ((l2r_cache_hit && l2r_request.packet_type != L2REQ_FLUSH)
                || l2r_l2_fill
                || completed_flush
                || l2r_request.packet_type == L2REQ_DINVALIDATE
                || l2r_request.packet_type == L2REQ_IINVALIDATE))
            begin
                // Restarted flush must have packet type L2REQ_FLUSH
                assert(!l2r_restarted_flush || l2r_request.packet_type == L2REQ_FLUSH);

                // Cannot be both a fill and restarted flush
                assert(!l2r_restarted_flush || !l2r_l2_fill);

                l2_response_valid <= 1;
            end
            else
                l2_response_valid <= 0;
        end
    end

    always_ff @(posedge clk)
    begin
        l2_response.status <= l2r_request.packet_type == L2REQ_STORE_SYNC
            ? l2r_store_sync_success : 1'b1;
        l2_response.core <= l2r_request.core;
        l2_response.id <= l2r_request.id;
        l2_response.packet_type <= response_type;
        l2_response.cache_type <= l2r_request.cache_type;
        l2_response.data <= l2u_write_data;
        l2_response.address <= l2r_request.address;
    end
endmodule
