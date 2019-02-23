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
// Queues store requests from the instruction pipeline, sends store requests to
// L2 interconnect, and processes responses. Cache control commands go through
// here as well.
// A memory barrier request waits until all pending store requests finish.
// It acts like a store in terms of rollback logic, but doesn't enqueue
// anything.
//

module l1_store_queue(
    input                                  clk,
    input                                  reset,

    // To instruction_decode_stage
    output local_thread_bitmap_t           sq_store_sync_pending,

    // From dache_data_stage
    input                                  dd_store_en,
    input                                  dd_flush_en,
    input                                  dd_membar_en,
    input                                  dd_iinvalidate_en,
    input                                  dd_dinvalidate_en,
    input cache_line_index_t               dd_store_addr,
    input [CACHE_LINE_BYTES - 1:0]         dd_store_mask,
    input cache_line_data_t                dd_store_data,
    input                                  dd_store_sync,
    input local_thread_idx_t               dd_store_thread_idx,
    input cache_line_index_t               dd_store_bypass_addr,
    input local_thread_idx_t               dd_store_bypass_thread_idx,

    // To writeback_stage
    output logic [CACHE_LINE_BYTES - 1:0]  sq_store_bypass_mask,
    output cache_line_data_t               sq_store_bypass_data,
    output logic                           sq_store_sync_success,

    // From l1_l2_interface
    input                                  storebuf_dequeue_ack,
    input                                  storebuf_l2_response_valid,
    input l1_miss_entry_idx_t              storebuf_l2_response_idx,
    input                                  storebuf_l2_sync_success,

    // To l1_l2_interface
    output logic                           sq_dequeue_ready,
    output cache_line_index_t              sq_dequeue_addr,
    output l1_miss_entry_idx_t             sq_dequeue_idx,
    output logic[CACHE_LINE_BYTES - 1:0]   sq_dequeue_mask,
    output cache_line_data_t               sq_dequeue_data,
    output logic                           sq_dequeue_sync,
    output logic                           sq_dequeue_flush,
    output logic                           sq_dequeue_iinvalidate,
    output logic                           sq_dequeue_dinvalidate,
    output logic                           sq_rollback_en,
    output local_thread_bitmap_t           sq_wake_bitmap);

    struct packed {
        logic sync;
        logic flush;
        logic iinvalidate;
        logic dinvalidate;
        logic request_sent;
        logic response_received;
        logic sync_success;
        logic thread_waiting;
        logic valid;
        cache_line_data_t data;
        logic[CACHE_LINE_BYTES - 1:0] mask;
        cache_line_index_t address;
    } pending_stores[`THREADS_PER_CORE];
    local_thread_bitmap_t rollback;
    local_thread_bitmap_t send_request;
    local_thread_idx_t send_grant_idx;
    local_thread_bitmap_t send_grant_oh;

    rr_arbiter #(.NUM_REQUESTERS(`THREADS_PER_CORE)) request_arbiter(
        .request(send_request),
        .update_lru(1'b1),
        .grant_oh(send_grant_oh),
        .*);

    oh_to_idx #(.NUM_SIGNALS(`THREADS_PER_CORE)) oh_to_idx_send_grant(
        .index(send_grant_idx),
        .one_hot(send_grant_oh));

    genvar thread_idx;
    generate
        for (thread_idx = 0; thread_idx < `THREADS_PER_CORE; thread_idx++)
        begin : thread_store_buf_gen
            logic update_store_entry;
            logic can_write_combine;
            logic store_requested_this_entry;
            logic send_this_cycle;
            logic restarted_sync_request;
            logic got_response_this_entry;
            logic membar_requested_this_entry;
            logic enqueue_cache_control;

            assign send_request[thread_idx] = pending_stores[thread_idx].valid
                && !pending_stores[thread_idx].request_sent;
            assign store_requested_this_entry = dd_store_en && dd_store_thread_idx == local_thread_idx_t'(thread_idx);
            assign membar_requested_this_entry = dd_membar_en && dd_store_thread_idx == local_thread_idx_t'(thread_idx);
            assign send_this_cycle = send_grant_oh[thread_idx] && storebuf_dequeue_ack;
            assign can_write_combine = pending_stores[thread_idx].valid
                && pending_stores[thread_idx].address == dd_store_addr
                && !pending_stores[thread_idx].flush
                && !pending_stores[thread_idx].iinvalidate
                && !pending_stores[thread_idx].dinvalidate
                && !dd_store_sync
                && !pending_stores[thread_idx].request_sent
                && !send_this_cycle
                && !dd_flush_en
                && !dd_iinvalidate_en
                && !dd_dinvalidate_en;
            assign restarted_sync_request = pending_stores[thread_idx].valid
                && pending_stores[thread_idx].response_received
                && pending_stores[thread_idx].sync;
            assign update_store_entry = store_requested_this_entry
                && (!pending_stores[thread_idx].valid || can_write_combine || got_response_this_entry)
                && !restarted_sync_request;
            assign got_response_this_entry = storebuf_l2_response_valid
                && storebuf_l2_response_idx == local_thread_idx_t'(thread_idx);
            assign sq_wake_bitmap[thread_idx] = got_response_this_entry
                && pending_stores[thread_idx].thread_waiting;
            assign enqueue_cache_control = dd_store_thread_idx == local_thread_idx_t'(thread_idx)
                && (!pending_stores[thread_idx].valid || got_response_this_entry)
                && (dd_flush_en || dd_dinvalidate_en || dd_iinvalidate_en);
            assign sq_store_sync_pending[thread_idx] = pending_stores[thread_idx].valid
                && pending_stores[thread_idx].sync;

            always_comb
            begin
                rollback[thread_idx] = 0;
                if (dd_store_thread_idx == local_thread_idx_t'(thread_idx)
                     && (dd_flush_en || dd_dinvalidate_en || dd_iinvalidate_en || dd_store_en))
                begin
                    // Trigger a rollback if the store buffer is full.
                    // - On the first synchronized store request, always suspend the thread, even
                    //   when there is space in the buffer, because this must wait for a response.
                    // - If the store entry is full, but it got a response this cycle,
                    //   allow enqueuing a new one. This is simpler, because it avoids
                    //   needing to handle the lost wakeup issue (like the near miss case
                    //   in the data cache)
                    if (dd_store_sync)
                        rollback[thread_idx] = !restarted_sync_request;
                    else if (pending_stores[thread_idx].valid && !can_write_combine
                        && !got_response_this_entry)
                        rollback[thread_idx] = 1;
                end
                else if (membar_requested_this_entry && pending_stores[thread_idx].valid
                    && !got_response_this_entry)
                    rollback[thread_idx] = 1;
            end

            always_ff @(posedge clk, posedge reset)
            begin
                if (reset)
                    pending_stores[thread_idx] <= 0;
                else
                begin
                    if ((dd_store_en || dd_flush_en || dd_membar_en
                        || dd_iinvalidate_en || dd_dinvalidate_en)
                        && dd_store_thread_idx == thread_idx)
                    begin
                        // Can't issue a new request if the thread is waiting.
                        assert(!pending_stores[thread_idx].thread_waiting);
                    end

                    if (dd_store_en && dd_store_thread_idx == thread_idx
                        && pending_stores[thread_idx].sync
                        && pending_stores[thread_idx].valid)
                    begin
                        // A synchronized store is already pending for this thread.
                        // This must be the second pass to pick up the result. Ensure
                        // some constraints are true:

                        // The thread should be unblocked until the L2 cache responds.
                        assert(pending_stores[thread_idx].response_received);

                        // The restarted store should be synchronized
                        assert(dd_store_sync);

                        // The request should be for the same address.
                        assert(dd_store_addr == pending_stores[thread_idx].address);
                    end

                    if (send_this_cycle)
                        pending_stores[thread_idx].request_sent <= 1;

                    if (update_store_entry)
                    begin
                        assert(!enqueue_cache_control);

                        for (int byte_lane = 0; byte_lane < CACHE_LINE_BYTES; byte_lane++)
                        begin
                            if (dd_store_mask[byte_lane])
                                pending_stores[thread_idx].data[byte_lane * 8+:8] <= dd_store_data[byte_lane * 8+:8];
                        end

                        if (can_write_combine)
                            pending_stores[thread_idx].mask <= pending_stores[thread_idx].mask | dd_store_mask;
                        else
                            pending_stores[thread_idx].mask <= dd_store_mask;
                    end

                    if (sq_wake_bitmap[thread_idx])
                        pending_stores[thread_idx].thread_waiting <= 0;
                    else if (rollback[thread_idx])
                        pending_stores[thread_idx].thread_waiting <= 1;

                    if (store_requested_this_entry)
                    begin
                        // Attempt to enqueue a new request. This may happen the same cycle
                        // an old request is satisfied. In this case, replace the old entry.
                        if (restarted_sync_request)
                        begin
                            // This is the restarted request after a synchronized load/store.
                            // Clear the entry.
                            assert(pending_stores[thread_idx].response_received);
                            assert(!got_response_this_entry);
                            assert(!pending_stores[thread_idx].flush);
                            assert(!rollback[thread_idx]);
                            assert(dd_store_sync);    // Restarted instruction must be synchronized
                            assert(!enqueue_cache_control);
                            pending_stores[thread_idx].valid <= 0;
                        end
                        else if (update_store_entry && !can_write_combine)
                        begin
                            // New store

                            // Ensure this entry isn't in use (or that it is being cleared this
                            // cycle)
                            assert(!pending_stores[thread_idx].valid || got_response_this_entry);

                            assert(!enqueue_cache_control);

                            pending_stores[thread_idx].valid <= 1;
                            pending_stores[thread_idx].address <= dd_store_addr;
                            pending_stores[thread_idx].sync <= dd_store_sync;
                            pending_stores[thread_idx].flush <= 0;
                            pending_stores[thread_idx].iinvalidate <= 0;
                            pending_stores[thread_idx].dinvalidate <= 0;
                            pending_stores[thread_idx].request_sent <= 0;
                            pending_stores[thread_idx].response_received <= 0;
                        end
                    end
                    else if (enqueue_cache_control)
                    begin
                        assert(!rollback[thread_idx]);

                        pending_stores[thread_idx].valid <= 1;
                        pending_stores[thread_idx].address <= dd_store_addr;
                        pending_stores[thread_idx].sync <= 0;
                        pending_stores[thread_idx].flush <= dd_flush_en;
                        pending_stores[thread_idx].iinvalidate <= dd_iinvalidate_en;
                        pending_stores[thread_idx].dinvalidate <= dd_dinvalidate_en;
                        pending_stores[thread_idx].request_sent <= 0;
                        pending_stores[thread_idx].response_received <= 0;
                    end

                    // If this got a response *and* hasn't queued a new one over the top of it in the
                    // same cycle, clear it.
                    if (got_response_this_entry && (!store_requested_this_entry || !update_store_entry)
                        && !enqueue_cache_control)
                    begin
                        // Ensure a response isn't sent for an entry that hasn't been sent.
                        assert(pending_stores[thread_idx].valid);
                        assert(pending_stores[thread_idx].request_sent);

                        // Ensure a response isn't sent multiple times
                        assert(!pending_stores[thread_idx].response_received);

                        // When the L2 cache responds to a synchronized memory transaction, the
                        // entry is still valid until the thread wakes back up and retrives the
                        // result. If it is not synchronized, finish the transaction.
                        if (pending_stores[thread_idx].sync)
                        begin
                            pending_stores[thread_idx].response_received <= 1;
                            pending_stores[thread_idx].sync_success <= storebuf_l2_sync_success;
                        end
                        else
                            pending_stores[thread_idx].valid <= 0;
                    end
                end
            end
        end
    endgenerate

    // New request out.
    // XXX may want to register this to reduce latency.
    assign sq_dequeue_ready = |send_grant_oh;
    assign sq_dequeue_idx = send_grant_idx;
    assign sq_dequeue_addr = pending_stores[send_grant_idx].address;
    assign sq_dequeue_mask = pending_stores[send_grant_idx].mask;
    assign sq_dequeue_data = pending_stores[send_grant_idx].data;
    assign sq_dequeue_sync = pending_stores[send_grant_idx].sync;
    assign sq_dequeue_flush = pending_stores[send_grant_idx].flush;
    assign sq_dequeue_iinvalidate = pending_stores[send_grant_idx].iinvalidate;
    assign sq_dequeue_dinvalidate = pending_stores[send_grant_idx].dinvalidate;

    always_ff @(posedge clk)
    begin
        sq_store_bypass_data <= pending_stores[dd_store_bypass_thread_idx].data;
        if (dd_store_bypass_addr == pending_stores[dd_store_bypass_thread_idx].address
            && pending_stores[dd_store_bypass_thread_idx].valid
            && !pending_stores[dd_store_bypass_thread_idx].flush
            && !pending_stores[dd_store_bypass_thread_idx].iinvalidate
            && !pending_stores[dd_store_bypass_thread_idx].dinvalidate)
        begin
            // There is a store for this address, set mask
            sq_store_bypass_mask <= pending_stores[dd_store_bypass_thread_idx].mask;
        end
        else
            sq_store_bypass_mask <= 0;

        sq_store_sync_success <= pending_stores[dd_store_thread_idx].sync_success;
    end

    always_ff @(posedge clk, posedge reset)
    begin
        if (reset)
        begin
            /*AUTORESET*/
            // Beginning of autoreset for uninitialized flops
            sq_rollback_en <= '0;
            // End of automatics
        end
        else
        begin
            // Only one request can be active per cycle.
            assert($onehot0({dd_store_en, dd_flush_en, dd_membar_en, dd_iinvalidate_en,
                dd_dinvalidate_en}));

            // Check that above is true for dequeued entries
            assert(!sq_dequeue_ready || $onehot0({pending_stores[send_grant_idx].flush,
                pending_stores[send_grant_idx].dinvalidate, pending_stores[send_grant_idx].iinvalidate,
                pending_stores[send_grant_idx].sync}));

            // Can't assert wake and sleep signals in same cycle
            assert((sq_wake_bitmap & rollback) == 0);

            sq_rollback_en <= |rollback;
        end
    end
endmodule
