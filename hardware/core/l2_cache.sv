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
// The L2 cache has a four stage pipeline:
//  - Arbitrate: selects one request from cores, or a restarted request
//    (described below) to send to the next stage.
//  - Tag: issues address to tag ram ways, checks LRU.
//  - Read: checks for cache hit, reads cache memory
//  - Update: generates signals to update cache memory and broadcasts response
//    to cores.
// When the cache detects a cache miss (after the read stage), it puts it into
// a fill request queue. The system memory interface fetches the data, then
// restarts the request (with the new data) at the beginning of the L2 pipeline.
// If the evicted line has unwritten data, the read stage reads it from cache
// memory and puts it into a writeback queue in the system memory interface.
//
// The L2 cache is physically indexed/physically tagged, and thus all addresses
// used here are physical. Address translation is done by TLBs in the L1 caches.
//

module l2_cache(
    input                                 clk,
    input                                 reset,

    // From l1_l2_interface
    input [`NUM_CORES - 1:0]              l2i_request_valid,
    input l2req_packet_t                  l2i_request[`NUM_CORES],

    // To l1_l2_interface
    output logic                          l2_ready[`NUM_CORES],
    output logic                          l2_response_valid,
    output l2rsp_packet_t                 l2_response,

    // External bus interface
    axi4_interface.master                 axi_bus,

    // To performance_counters
    output logic[L2_PERF_EVENTS - 1:0]    l2_perf_events);

    /*AUTOLOGIC*/
    // Beginning of automatic wires (for undeclared instantiated-module outputs)
    cache_line_data_t   l2a_data_from_memory;   // From l2_cache_arb_stage of l2_cache_arb_stage.v
    logic               l2a_l2_fill;            // From l2_cache_arb_stage of l2_cache_arb_stage.v
    l2req_packet_t      l2a_request;            // From l2_cache_arb_stage of l2_cache_arb_stage.v
    logic               l2a_request_valid;      // From l2_cache_arb_stage of l2_cache_arb_stage.v
    logic               l2a_restarted_flush;    // From l2_cache_arb_stage of l2_cache_arb_stage.v
    logic               l2bi_collided_miss;     // From l2_axi_bus_interface of l2_axi_bus_interface.v
    cache_line_data_t   l2bi_data_from_memory;  // From l2_axi_bus_interface of l2_axi_bus_interface.v
    logic               l2bi_perf_l2_writeback; // From l2_axi_bus_interface of l2_axi_bus_interface.v
    l2req_packet_t      l2bi_request;           // From l2_axi_bus_interface of l2_axi_bus_interface.v
    logic               l2bi_request_valid;     // From l2_axi_bus_interface of l2_axi_bus_interface.v
    logic               l2bi_stall;             // From l2_axi_bus_interface of l2_axi_bus_interface.v
    logic               l2r_cache_hit;          // From l2_cache_read_stage of l2_cache_read_stage.v
    cache_line_data_t   l2r_data;               // From l2_cache_read_stage of l2_cache_read_stage.v
    cache_line_data_t   l2r_data_from_memory;   // From l2_cache_read_stage of l2_cache_read_stage.v
    logic [$clog2(`L2_WAYS*`L2_SETS)-1:0] l2r_hit_cache_idx;// From l2_cache_read_stage of l2_cache_read_stage.v
    logic               l2r_l2_fill;            // From l2_cache_read_stage of l2_cache_read_stage.v
    logic               l2r_needs_writeback;    // From l2_cache_read_stage of l2_cache_read_stage.v
    logic               l2r_perf_l2_hit;        // From l2_cache_read_stage of l2_cache_read_stage.v
    logic               l2r_perf_l2_miss;       // From l2_cache_read_stage of l2_cache_read_stage.v
    l2req_packet_t      l2r_request;            // From l2_cache_read_stage of l2_cache_read_stage.v
    logic               l2r_request_valid;      // From l2_cache_read_stage of l2_cache_read_stage.v
    logic               l2r_restarted_flush;    // From l2_cache_read_stage of l2_cache_read_stage.v
    logic               l2r_store_sync_success; // From l2_cache_read_stage of l2_cache_read_stage.v
    logic [`L2_WAYS-1:0] l2r_update_dirty_en;   // From l2_cache_read_stage of l2_cache_read_stage.v
    l2_set_idx_t        l2r_update_dirty_set;   // From l2_cache_read_stage of l2_cache_read_stage.v
    logic               l2r_update_dirty_value; // From l2_cache_read_stage of l2_cache_read_stage.v
    logic               l2r_update_lru_en;      // From l2_cache_read_stage of l2_cache_read_stage.v
    l2_way_idx_t        l2r_update_lru_hit_way; // From l2_cache_read_stage of l2_cache_read_stage.v
    logic [`L2_WAYS-1:0] l2r_update_tag_en;     // From l2_cache_read_stage of l2_cache_read_stage.v
    l2_set_idx_t        l2r_update_tag_set;     // From l2_cache_read_stage of l2_cache_read_stage.v
    logic               l2r_update_tag_valid;   // From l2_cache_read_stage of l2_cache_read_stage.v
    l2_tag_t            l2r_update_tag_value;   // From l2_cache_read_stage of l2_cache_read_stage.v
    l2_tag_t            l2r_writeback_tag;      // From l2_cache_read_stage of l2_cache_read_stage.v
    cache_line_data_t   l2t_data_from_memory;   // From l2_cache_tag_stage of l2_cache_tag_stage.v
    logic               l2t_dirty [`L2_WAYS];   // From l2_cache_tag_stage of l2_cache_tag_stage.v
    l2_way_idx_t        l2t_fill_way;           // From l2_cache_tag_stage of l2_cache_tag_stage.v
    logic               l2t_l2_fill;            // From l2_cache_tag_stage of l2_cache_tag_stage.v
    l2req_packet_t      l2t_request;            // From l2_cache_tag_stage of l2_cache_tag_stage.v
    logic               l2t_request_valid;      // From l2_cache_tag_stage of l2_cache_tag_stage.v
    logic               l2t_restarted_flush;    // From l2_cache_tag_stage of l2_cache_tag_stage.v
    l2_tag_t            l2t_tag [`L2_WAYS];     // From l2_cache_tag_stage of l2_cache_tag_stage.v
    logic               l2t_valid [`L2_WAYS];   // From l2_cache_tag_stage of l2_cache_tag_stage.v
    logic [$clog2(`L2_WAYS*`L2_SETS)-1:0] l2u_write_addr;// From l2_cache_update_stage of l2_cache_update_stage.v
    cache_line_data_t   l2u_write_data;         // From l2_cache_update_stage of l2_cache_update_stage.v
    logic               l2u_write_en;           // From l2_cache_update_stage of l2_cache_update_stage.v
    // End of automatics

    l2_cache_arb_stage l2_cache_arb_stage(.*);
    l2_cache_tag_stage l2_cache_tag_stage(.*);
    l2_cache_read_stage l2_cache_read_stage(.*);
    l2_cache_update_stage l2_cache_update_stage(.*);

    l2_axi_bus_interface l2_axi_bus_interface(.*);

    // The number of signals in this assignment must match L2_PERF_EVENTS
    // in defines.sv.
    assign l2_perf_events = {
        l2r_perf_l2_hit,
        l2r_perf_l2_miss,
        l2bi_perf_l2_writeback
    };
endmodule
