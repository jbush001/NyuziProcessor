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
// L2 cache pipeline - tag stage.
// Performs tag lookup. Results will be available in the next stage.
// Also reads the LRU
//

module l2_cache_tag_stage(
    input                                 clk,
    input                                 reset,

    // From l2_cache_arb_stage
    input                                 l2a_request_valid,
    input l2req_packet_t                  l2a_request,
    input cache_line_data_t               l2a_data_from_memory,
    input                                 l2a_l2_fill,
    input                                 l2a_restarted_flush,

    // From l2_cache_read_stage
    input [`L2_WAYS - 1:0]                l2r_update_dirty_en,
    input l2_set_idx_t                    l2r_update_dirty_set,
    input                                 l2r_update_dirty_value,
    input [`L2_WAYS - 1:0]                l2r_update_tag_en,
    input l2_set_idx_t                    l2r_update_tag_set,
    input                                 l2r_update_tag_valid,
    input l2_tag_t                        l2r_update_tag_value,
    input                                 l2r_update_lru_en,
    input l2_way_idx_t                    l2r_update_lru_hit_way,

    // To l2_cache_read_stage
    output logic                          l2t_request_valid,
    output l2req_packet_t                 l2t_request,
    output logic                          l2t_valid[`L2_WAYS],
    output l2_tag_t                       l2t_tag[`L2_WAYS],
    output logic                          l2t_dirty[`L2_WAYS],
    output logic                          l2t_l2_fill,
    output l2_way_idx_t                   l2t_fill_way,
    output cache_line_data_t              l2t_data_from_memory,
    output logic                          l2t_restarted_flush);

    initial
    begin
        assert((`L2_SETS & (`L2_SETS - 1)) == 0);
    end

    cache_lru #(
        .NUM_SETS(`L2_SETS),
        .NUM_WAYS(`L2_WAYS)
    ) cache_lru(
        .fill_en(l2a_l2_fill),
        .fill_set(l2a_request.address.set_idx),
        .fill_way(l2t_fill_way),    // Output to next stage
        .access_en(l2a_request_valid),
        .access_set(l2a_request.address.set_idx),
        .update_en(l2r_update_lru_en),
        .update_way(l2r_update_lru_hit_way),
        .*);

    //
    // Way metadata
    //
    genvar way_idx;
    generate
        for (way_idx = 0; way_idx < `L2_WAYS; way_idx++)
        begin : way_tags_gen
            logic line_valid[`L2_SETS];

            sram_1r1w #(
                .DATA_WIDTH($bits(l2_tag_t)),
                .SIZE(`L2_SETS),
                .READ_DURING_WRITE("NEW_DATA")
            ) sram_tags(
                .read_en(l2a_request_valid),
                .read_addr(l2a_request.address.set_idx),
                .read_data(l2t_tag[way_idx]),
                .write_en(l2r_update_tag_en[way_idx]),
                .write_addr(l2r_update_tag_set),
                .write_data(l2r_update_tag_value),
                .*);

            sram_1r1w #(
                .DATA_WIDTH(1),
                .SIZE(`L2_SETS),
                .READ_DURING_WRITE("NEW_DATA")
            ) sram_dirty_flags(
                .read_en(l2a_request_valid),
                .read_addr(l2a_request.address.set_idx),
                .read_data(l2t_dirty[way_idx]),
                .write_en(l2r_update_dirty_en[way_idx]),
                .write_addr(l2r_update_dirty_set),
                .write_data(l2r_update_dirty_value),
                .*);

            always_ff @(posedge clk, posedge reset)
            begin
                if (reset)
                begin
                    for (int set_idx = 0; set_idx < `L2_SETS; set_idx++)
                        line_valid[set_idx] <= 0;
                end
                else if (l2r_update_tag_en[way_idx])
                    line_valid[l2r_update_tag_set] <= l2r_update_tag_valid;
            end

            always_ff @(posedge clk)
            begin
                if (l2a_request_valid)
                begin
                    if (l2r_update_tag_en[way_idx] && l2r_update_tag_set
                        == l2a_request.address.set_idx)
                        l2t_valid[way_idx] <= l2r_update_tag_valid;    // Bypass
                    else
                        l2t_valid[way_idx] <= line_valid[l2a_request.address.set_idx];
                end
            end
        end
    endgenerate

    always_ff @(posedge clk)
    begin
        l2t_data_from_memory <= l2a_data_from_memory;
        l2t_request <= l2a_request;
        l2t_l2_fill <= l2a_l2_fill;
        l2t_restarted_flush <= l2a_restarted_flush;
    end

    always_ff @(posedge clk, posedge reset)
    begin
        if (reset)
            l2t_request_valid <= 0;
        else
            l2t_request_valid <= l2a_request_valid;
    end
endmodule
