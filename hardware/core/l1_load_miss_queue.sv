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
// Tracks pending L1 misses. Detects and consolidates multiple misses
// for the same address. Wakes threads when loads complete.
//

module l1_load_miss_queue(
    input                                   clk,
    input                                   reset,

    // Enqueue request
    input                                   cache_miss,
    input cache_line_index_t                cache_miss_addr,
    input local_thread_idx_t                cache_miss_thread_idx,
    input                                   cache_miss_sync,

    // Dequeue request
    output logic                            dequeue_ready,
    input                                   dequeue_ack,
    output cache_line_index_t               dequeue_addr,
    output l1_miss_entry_idx_t              dequeue_idx,
    output logic                            dequeue_sync,

    // Wake
    input                                   l2_response_valid,
    input l1_miss_entry_idx_t               l2_response_idx,
    output local_thread_bitmap_t            wake_bitmap);

    struct packed {
        logic valid;
        logic request_sent;
        local_thread_bitmap_t waiting_threads;
        cache_line_index_t address;
        logic sync;
    } pending_entries[`THREADS_PER_CORE];

    local_thread_bitmap_t collided_miss_oh;
    local_thread_bitmap_t miss_thread_oh;
    logic request_unique;
    local_thread_bitmap_t send_grant_oh;
    local_thread_bitmap_t arbiter_request;
    local_thread_idx_t send_grant_idx;

    idx_to_oh #(.NUM_SIGNALS(`THREADS_PER_CORE)) idx_to_oh_miss_thread(
        .index(cache_miss_thread_idx),
        .one_hot(miss_thread_oh));

    rr_arbiter #(.NUM_REQUESTERS(`THREADS_PER_CORE)) request_arbiter(
        .request(arbiter_request),
        .update_lru(1'b1),
        .grant_oh(send_grant_oh),
        .*);

    oh_to_idx #(.NUM_SIGNALS(`THREADS_PER_CORE)) oh_to_idx_send_grant(
        .index(send_grant_idx),
        .one_hot(send_grant_oh));

    // Request out
    assign dequeue_ready = |arbiter_request;
    assign dequeue_addr = pending_entries[send_grant_idx].address;
    assign dequeue_idx = send_grant_idx;
    assign dequeue_sync = pending_entries[send_grant_idx].sync;

    assign request_unique = !(|collided_miss_oh);

    assign wake_bitmap = l2_response_valid ? pending_entries[l2_response_idx].waiting_threads : local_thread_bitmap_t'(0);

    genvar wait_entry;
    generate
        for (wait_entry = 0; wait_entry < `THREADS_PER_CORE; wait_entry++)
        begin : wait_logic_gen
            // Synchronized requests cannot be combined with other requests.
            assign collided_miss_oh[wait_entry] = pending_entries[wait_entry].valid
                && pending_entries[wait_entry].address == cache_miss_addr
                && !pending_entries[wait_entry].sync
                && !cache_miss_sync;
            assign arbiter_request[wait_entry] = pending_entries[wait_entry].valid
                && !pending_entries[wait_entry].request_sent;

            always_ff @(posedge clk, posedge reset)
            begin
                if (reset)
                    pending_entries[wait_entry] <= 0;
                else
                begin
                    if (dequeue_ack && send_grant_oh[wait_entry])
                    begin
                        // Send a new L2 request
                        pending_entries[wait_entry].request_sent <= 1;

                        // Ensure this doesn't dequeue an entry that has already been
                        // sent.
                        assert(pending_entries[wait_entry].valid);
                        assert(!pending_entries[wait_entry].request_sent);
                    end
                    else if (cache_miss && miss_thread_oh[wait_entry] && request_unique)
                    begin
                        // Enqueue a cache miss
                        pending_entries[wait_entry].waiting_threads <= miss_thread_oh;
                        pending_entries[wait_entry].valid <= 1;
                        pending_entries[wait_entry].address <= cache_miss_addr;
                        pending_entries[wait_entry].request_sent <= 0;
                        pending_entries[wait_entry].sync <= cache_miss_sync;

                        // Ensure this entry isn't already in use or a response
                        // isn't coming in this cycle (lower level logic should prevent
                        // the latter)
                        assert(!pending_entries[wait_entry].valid);
                        assert(!(l2_response_valid && l2_response_idx == l1_miss_entry_idx_t'(wait_entry)));
                    end
                    else if (l2_response_valid && l2_response_idx == l1_miss_entry_idx_t'(wait_entry))
                    begin
                        // Got an L2 response
                        pending_entries[wait_entry].valid <= 0;

                        // Ensure there isn't a response to an entry that isn't valid
                        // or hasn't been sent.
                        assert(pending_entries[wait_entry].valid);
                        assert(pending_entries[wait_entry].request_sent);
                    end

                    if (cache_miss && collided_miss_oh[wait_entry])
                    begin
                        // Miss is already pending, add waiting thread
                        pending_entries[wait_entry].waiting_threads <= pending_entries[wait_entry].waiting_threads
                            | miss_thread_oh;

                        // Upper level 'near_miss' logic prevents triggering a miss in the same
                        // cycle it is satisfied.
                        assert(!(l2_response_valid && l2_response_idx == l1_miss_entry_idx_t'(wait_entry)));
                    end
                end
            end
        end
    endgenerate

`ifdef SIMULATION
    always_ff @(posedge clk, posedge reset)
    begin
         if (!reset)
             assert($onehot0(collided_miss_oh));
    end
`endif
endmodule
