//
// Copyright 2017 Jeff Bush
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

module test_load_miss_queue(input clk, input reset);
    localparam ADDR0 = 'h123;
    localparam ADDR1 = 'h1b2;
    localparam ADDR2 = 'ha12;
    localparam ADDR3 = 'hcc3;

    logic cache_miss;
    cache_line_index_t cache_miss_addr;
    local_thread_idx_t cache_miss_thread_idx;
    logic cache_miss_sync;
    logic dequeue_ready;
    logic dequeue_ack;
    cache_line_index_t dequeue_addr;
    l1_miss_entry_idx_t dequeue_idx;
    logic dequeue_sync;
    logic l2_response_valid;
    l1_miss_entry_idx_t l2_response_idx;
    local_thread_bitmap_t wake_bitmap;
    int cycle;
    l1_miss_entry_idx_t saved_request_idx0;
    l1_miss_entry_idx_t saved_request_idx1;
    logic l2_requests_in_order;

    l1_load_miss_queue l1_load_miss_queue(.*);

    always @(posedge clk, posedge reset)
    begin
        if (reset)
        begin
            cycle <= 0;
        end
        else
        begin
            // default values
            cache_miss <= 0;
            dequeue_ack <= 0;
            l2_response_valid <= 0;

            cycle <= cycle + 1;
            unique case (cycle)
                ////////////////////////////////////////////////////////////
                // Basic request flow and load combining
                ////////////////////////////////////////////////////////////

                // Enqueue a load miss, thread 0
                0:
                begin
                    assert(!dequeue_ready);
                    assert(wake_bitmap == 0);

                    cache_miss <= 1;
                    cache_miss_addr <= ADDR0;
                    cache_miss_thread_idx <= 0;
                    cache_miss_sync <= 0;
                end

                // Enqueue a load miss, thread 1. This will not be
                // load combined, because it is a different address
                1:
                begin
                    assert(!dequeue_ready);
                    assert(wake_bitmap == 0);

                    cache_miss <= 1;
                    cache_miss_addr <= ADDR1;
                    cache_miss_thread_idx <= 1;
                    cache_miss_sync <= 0;
                end

                // Check that the request is pending from the queue and acknowledge
                // (we don't check the response fields here because dequeue_ack is
                // not asserted yet, and it can change).
                2:
                begin
                    assert(dequeue_ready);
                    dequeue_ack <= 1;
                end

                // Check dequeue values
                3:
                begin
                    // The order that we will receive these requests is arbitrary,
                    // so keep track of that here.
                    assert(dequeue_ready);
                    if (dequeue_addr == ADDR0)
                    begin
                        l2_requests_in_order <= 1;
                        saved_request_idx0 <= dequeue_idx;
                    end
                    else
                    begin
                        assert(dequeue_addr == ADDR1);
                        l2_requests_in_order <= 0;
                        saved_request_idx1 <= dequeue_idx;
                    end

                    assert(!dequeue_sync);
                    assert(wake_bitmap == 0);
                end

                // Create another request for the second address from thread 2
                4:
                begin
                    assert(dequeue_ready);
                    assert(wake_bitmap == 0);

                    cache_miss <= 1;
                    cache_miss_addr <= ADDR1;
                    cache_miss_thread_idx <= 2;
                    cache_miss_sync <= 0;
                end

                5:
                begin
                    assert(dequeue_ready);
                    dequeue_ack <= 1;
                end

                6:
                begin
                    // Check the request. It should be the one not asserted earlier.
                    if (l2_requests_in_order)
                    begin
                        assert(dequeue_addr == ADDR1);
                        saved_request_idx1 <= dequeue_idx;
                    end
                    else
                    begin
                        assert(dequeue_addr == ADDR0);
                        saved_request_idx0 <= dequeue_idx;
                    end
                    assert(!dequeue_sync);
                    assert(wake_bitmap == 0);
                end

                7:
                begin
                    // Send L2 response for first request
                    assert(!dequeue_ready);
                    assert(wake_bitmap == 0);
                    l2_response_valid <= 1;
                    l2_response_idx <= saved_request_idx0;
                end

                // Check that wake bitmap is asserted.
                8:
                begin
                    assert(!dequeue_ready);
                    assert(wake_bitmap == 4'b0001);
                end

                // Wake bitmap should be deasserted
                9:
                begin
                    assert(!dequeue_ready);
                    assert(wake_bitmap == 0);
                end

                // Send L2 response for second request
                10:
                begin
                    assert(!dequeue_ready);
                    assert(wake_bitmap == 0);
                    l2_response_valid <= 1;
                    l2_response_idx <= saved_request_idx1;
                end

                // Check that wake bitmap is asserted for two combined
                // threads.
                11:
                begin
                    assert(!dequeue_ready);
                    assert(wake_bitmap == 4'b0110);
                end

                // Wake bitmap should be deasserted
                12:
                begin
                    assert(!dequeue_ready);
                    assert(wake_bitmap == 0);
                end

                ////////////////////////////////////////////////////////////
                // Check that synchronized requests are not load combined.
                ////////////////////////////////////////////////////////////

                // Synchronized miss
                13:
                begin
                    cache_miss <= 1;
                    cache_miss_addr <= ADDR2;
                    cache_miss_thread_idx <= 0;
                    cache_miss_sync <= 1;
                end

                // Unsynchronized miss
                14:
                begin
                    cache_miss <= 1;
                    cache_miss_addr <= ADDR2;
                    cache_miss_thread_idx <= 1;
                    cache_miss_sync <= 0;
                    dequeue_ack <= 1;
                end

                // Get first request
                15:
                begin
                    assert(dequeue_ready);
                    assert(dequeue_addr == ADDR2);
                    if (dequeue_sync)
                    begin
                        l2_requests_in_order <= 1;
                        saved_request_idx0 <= dequeue_idx;
                    end
                    else
                    begin
                        l2_requests_in_order <= 0;
                        saved_request_idx1 <= dequeue_idx;
                    end

                    dequeue_ack <= 1;
                end

                // Get second request
                16:
                begin
                    assert(dequeue_ready);
                    assert(dequeue_addr == ADDR2);
                    if (l2_requests_in_order)
                    begin
                        assert(dequeue_idx == saved_request_idx1);
                        assert(!dequeue_sync);
                    end
                    else
                    begin
                        assert(dequeue_sync);
                        assert(dequeue_idx == saved_request_idx0);
                    end
                end

                // First response
                17:
                begin
                    l2_response_valid <= 1;
                    l2_response_idx <= saved_request_idx0;
                end

                // Second response
                18:
                begin
                    assert(wake_bitmap == 4'b0001);

                    l2_response_valid <= 1;
                    l2_response_idx <= saved_request_idx1;
                end

                19:
                begin
                    assert(wake_bitmap == 4'b0010);
                end

                //
                // Do the same thing, but reverse the order of synchronized/
                // unsynchronized
                //

                // Unsynchronized miss
                20:
                begin
                    cache_miss <= 1;
                    cache_miss_addr <= ADDR2;
                    cache_miss_thread_idx <= 2;
                    cache_miss_sync <= 0;
                end

                // Synchronized miss
                21:
                begin
                    cache_miss <= 1;
                    cache_miss_addr <= ADDR2;
                    cache_miss_thread_idx <= 3;
                    cache_miss_sync <= 1;
                    dequeue_ack <= 1;
                end

                // Get first request
                22:
                begin
                    assert(dequeue_ready);
                    assert(dequeue_addr == ADDR2);
                    if (dequeue_sync)
                    begin
                        l2_requests_in_order <= 0;
                        saved_request_idx1 <= dequeue_idx;
                    end
                    else
                    begin
                        l2_requests_in_order <= 1;
                        saved_request_idx0 <= dequeue_idx;
                    end

                    dequeue_ack <= 1;
                end

                // Get second request
                23:
                begin
                    assert(dequeue_ready);
                    assert(dequeue_addr == ADDR2);
                    if (l2_requests_in_order)
                    begin
                        saved_request_idx1 <= dequeue_idx;
                        assert(dequeue_sync);
                    end
                    else
                    begin
                        saved_request_idx0 <= dequeue_idx;
                        assert(!dequeue_sync);
                    end
                end

                // First response
                24:
                begin
                    l2_response_valid <= 1;
                    l2_response_idx <= saved_request_idx0;
                end

                // Second response
                25:
                begin
                    assert(wake_bitmap == 4'b0100);

                    l2_response_valid <= 1;
                    l2_response_idx <= saved_request_idx1;
                end

                26:
                begin
                    assert(wake_bitmap == 4'b1000);
                end

                27:
                begin
                    $display("PASS");
                    $finish;
                end
            endcase
        end
    end
endmodule
