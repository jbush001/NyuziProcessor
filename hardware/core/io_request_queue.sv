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
// Handles non-cacheable memory operations to memory mapped registers
// These always block the thread until the transaction is complete.
//

module io_request_queue
    #(parameter CORE_ID = 0)

    (input                                 clk,
    input                                  reset,

    // From dcache_data_stage
    input                                  dd_io_write_en,
    input                                  dd_io_read_en,
    input local_thread_idx_t               dd_io_thread_idx,
    input scalar_t                         dd_io_addr,
    input scalar_t                         dd_io_write_value,

    // To writeback_stage
    output scalar_t                        ior_read_value,
    output logic                           ior_rollback_en,

    // To instruction_decode_stage
    output local_thread_bitmap_t           ior_pending,

    // To thread_select_stage
    output local_thread_bitmap_t           ior_wake_bitmap,

    // From io_interconnect
    input                                  ii_ready,
    input                                  ii_response_valid,
    input iorsp_packet_t                   ii_response,

    // To io_interconnect
    output logic                           ior_request_valid,
    output ioreq_packet_t                  ior_request);

    struct packed {
        logic valid;
        logic request_sent;
        logic store;
        scalar_t address;
        scalar_t value;
    } pending_request[`THREADS_PER_CORE];
    local_thread_bitmap_t wake_thread_oh;
    local_thread_bitmap_t send_request;
    local_thread_bitmap_t send_grant_oh;
    local_thread_idx_t send_grant_idx;

    genvar thread_idx;
    generate
        for (thread_idx = 0; thread_idx < `THREADS_PER_CORE; thread_idx++)
        begin : io_request_gen
            assign send_request[thread_idx] = pending_request[thread_idx].valid
                && !pending_request[thread_idx].request_sent;
            assign ior_pending[thread_idx] = (pending_request[thread_idx].valid
                && pending_request[thread_idx].request_sent) || send_grant_oh[thread_idx];

            always_ff @(posedge clk, posedge reset)
            begin
                if (reset)
                    pending_request[thread_idx] <= 0;
                else
                begin
                    if ((dd_io_write_en | dd_io_read_en) && dd_io_thread_idx
                        == local_thread_idx_t'(thread_idx))
                    begin
                        if (pending_request[thread_idx].valid)
                        begin
                            // Request completed
                            pending_request[thread_idx].valid <= 0;
                        end
                        else
                        begin
                            // Request initiated
                            pending_request[thread_idx].valid <= 1;
                            pending_request[thread_idx].store <= dd_io_write_en;
                            pending_request[thread_idx].address <= dd_io_addr;
                            pending_request[thread_idx].value <= dd_io_write_value;
                            pending_request[thread_idx].request_sent <= 0;
                        end
                    end

                    if (ii_response_valid && ii_response.core == CORE_ID && ii_response.thread_idx
                        == local_thread_idx_t'(thread_idx))
                    begin
                        // Ensure there isn't a response for an entry that isn't pending
                        assert(pending_request[thread_idx].valid);

                        pending_request[thread_idx].value <= ii_response.read_value;
                    end

                    if (ii_ready && |send_grant_oh && send_grant_idx == local_thread_idx_t'(thread_idx))
                        pending_request[thread_idx].request_sent <= 1;
                end
            end
        end
    endgenerate

    rr_arbiter #(.NUM_REQUESTERS(`THREADS_PER_CORE)) request_arbiter(
        .request(send_request),
        .update_lru(1'b1),
        .grant_oh(send_grant_oh),
        .*);

    oh_to_idx #(.NUM_SIGNALS(`THREADS_PER_CORE)) oh_to_idx_send_thread(
        .one_hot(send_grant_oh),
        .index(send_grant_idx));

    idx_to_oh #(.NUM_SIGNALS(`THREADS_PER_CORE)) idx_to_oh_wake_thread(
        .index(ii_response.thread_idx),
        .one_hot(wake_thread_oh));

    assign ior_wake_bitmap = (ii_response_valid && ii_response.core == CORE_ID)
        ? wake_thread_oh : local_thread_bitmap_t'(0);

    // Send request
    assign ior_request_valid = |send_request;
    assign ior_request.store = pending_request[send_grant_idx].store;
    assign ior_request.address = pending_request[send_grant_idx].address;
    assign ior_request.value = pending_request[send_grant_idx].value;
    assign ior_request.thread_idx = send_grant_idx;

    always_ff @(posedge clk, posedge reset)
    begin
        if (reset)
        begin
            /*AUTORESET*/
            // Beginning of autoreset for uninitialized flops
            ior_rollback_en <= '0;
            // End of automatics
        end
        else
        begin
            if ((dd_io_write_en || dd_io_read_en) && !pending_request[dd_io_thread_idx].valid)
                ior_rollback_en <= 1;    // Start request
            else
                ior_rollback_en <= 0;    // Complete request
        end
    end

    always_ff @(posedge clk)
        ior_read_value <= pending_request[dd_io_thread_idx].value;
endmodule
