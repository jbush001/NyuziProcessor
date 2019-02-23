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
// Tracks pending cache misses (fills) in the L2 cache pipeline.
// This module detects duplicate loads/stores in the system memory request
// queue. These not only waste memory bandwidth, but can cause data to be
// overwritten.
//
// Each time a cache miss goes past this unit, it records that it is pending.
// When a restarted request goes past, this clears the pending line.
// For each transaction, this asserts the 'duplicate_reqest' signal if
// another transaction for that line is pending.
//
// The pending miss for the line may be anywhere in the L2 pipeline,
// not just the l2 bus interface. Because of this, QUEUE_SIZE must be greater
// than or equal to the number of entries in the bus interface request queue
// + the number of pipeline stages.
//

module l2_cache_pending_miss_cam
    #(parameter QUEUE_SIZE = 16,
    parameter QUEUE_ADDR_WIDTH = $clog2(QUEUE_SIZE))
    (input                   clk,
    input                    reset,
    input                    request_valid,
    input cache_line_index_t request_addr,
    input                    enqueue_fill_request,
    input                    l2r_l2_fill,
    output logic             duplicate_request);

    logic[QUEUE_ADDR_WIDTH - 1:0] cam_hit_entry;
    logic cam_hit;
    logic[QUEUE_SIZE - 1:0] empty_entries;    // 1 if entry is empty
    logic[QUEUE_SIZE - 1:0] next_empty_oh;
    logic[QUEUE_ADDR_WIDTH - 1:0] next_empty;

    assign next_empty_oh = empty_entries & ~(empty_entries - QUEUE_SIZE'(1));

    oh_to_idx #(.NUM_SIGNALS(QUEUE_SIZE)) oh_to_idx_next_empty(
        .one_hot(next_empty_oh),
        .index(next_empty));

    assign duplicate_request = cam_hit && !l2r_l2_fill;

    cam #(
        .NUM_ENTRIES(QUEUE_SIZE),
        .KEY_WIDTH($bits(cache_line_index_t))
    ) cam_pending_miss(
        .clk(clk),
        .reset(reset),
        .lookup_key(request_addr),
        .lookup_idx(cam_hit_entry),
        .lookup_hit(cam_hit),
        .update_en(request_valid && (cam_hit ? l2r_l2_fill
            : enqueue_fill_request)),
        .update_key(request_addr),
        .update_idx(cam_hit ? cam_hit_entry : next_empty),
        .update_valid(cam_hit ? !l2r_l2_fill : enqueue_fill_request));

    always_ff @(posedge clk, posedge reset)
    begin
        // Make sure the queue isn't full
        assert(reset || empty_entries != 0);

        if (reset)
            empty_entries <= {QUEUE_SIZE{1'b1}};
        else if (cam_hit & l2r_l2_fill)
            empty_entries[cam_hit_entry] <= 1'b1;
        else if (!cam_hit && enqueue_fill_request)
            empty_entries[next_empty] <= 1'b0;
    end
endmodule
