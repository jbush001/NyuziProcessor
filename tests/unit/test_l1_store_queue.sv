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

//
// Some basic l1_store_queue scenarios. Lots of edge and normal cases not covered.
//

module test_l1_store_queue(input clk, input reset);

    // XXX Ideally MASK0 would be non-zero, so when we write combined with MASK2/DATA2, we could
    // ensure new mask bits were set. However, there is a mismatch when checking DATA0, since
    // the store buffer only updates lines that are masked.

    localparam ADDR0 = 'h123;
    localparam DATA0 = 512'h88a84df3d616f6e7701e6461010a1f3f2c931fb4b396d059d177c51b3b17c82ad26c90f1f7040331efd466bde698718ec430b97e0c9241b9a57322c9b092bf3e;
    localparam MASK0 = 64'hffffffff_ffffffff;
    localparam ADDR1 = 'habc;
    localparam ADDR2 = 'h765;
    localparam DATA2 = 512'hcccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc;
    localparam MASK2 = 64'h00000000_00000ff0;
    localparam COMBINED_MASK = 64'hffffffff_ffffffff;
    localparam COMBINED_DATA = 512'h88a84df3d616f6e7701e6461010a1f3f2c931fb4b396d059d177c51b3b17c82ad26c90f1f7040331efd466bde698718ec430b97eccccccccccccccccb092bf3e;
    localparam ADDR3 = 'h928;
    localparam MASK3 = 64'hffffffff_ffffffff;
    localparam DATA3 = 512'hcf01cb29d7b525268e5182db49872b1987a8565026b935cbaa1ca1af0c0e1d38f658119af5322b0870a678910fd04faf1591bae8c654c5ebc0ac5728bc879d6d;

    local_thread_bitmap_t sq_store_sync_pending;
    logic dd_store_en;
    logic dd_flush_en;
    logic dd_membar_en;
    logic dd_iinvalidate_en;
    logic dd_dinvalidate_en;
    cache_line_index_t dd_store_addr;
    logic[CACHE_LINE_BYTES - 1:0] dd_store_mask;
    cache_line_data_t dd_store_data;
    logic dd_store_sync;
    local_thread_idx_t dd_store_thread_idx;
    cache_line_index_t dd_store_bypass_addr;
    local_thread_idx_t dd_store_bypass_thread_idx;
    logic [CACHE_LINE_BYTES - 1:0] sq_store_bypass_mask;
    cache_line_data_t sq_store_bypass_data;
    logic sq_store_sync_success;
    logic sq_dequeue_ack;
    logic storebuf_l2_response_valid;
    l1_miss_entry_idx_t storebuf_l2_response_idx;
    logic storebuf_l2_sync_success;
    logic sq_dequeue_ready;
    cache_line_index_t sq_dequeue_addr;
    l1_miss_entry_idx_t sq_dequeue_idx;
    logic[CACHE_LINE_BYTES - 1:0] sq_dequeue_mask;
    cache_line_data_t sq_dequeue_data;
    logic sq_dequeue_sync;
    logic sq_dequeue_flush;
    logic sq_dequeue_iinvalidate;
    logic sq_dequeue_dinvalidate;
    logic sq_rollback_en;
    local_thread_bitmap_t sq_wake_bitmap;
    int state;
    l1_miss_entry_idx_t saved_request_idx;

    l1_store_queue l1_store_queue(.*);

    always @(posedge clk, posedge reset)
    begin
        if (reset)
            state <= 0;
        else
        begin
            dd_store_en <= 0;
            dd_flush_en <= 0;
            dd_membar_en <= 0;
            dd_iinvalidate_en <= 0;
            dd_dinvalidate_en <= 0;
            dd_store_sync <= 0;
            sq_dequeue_ack <= 0;
            storebuf_l2_response_valid <= 0;

            unique case (state)
                // Queue a store request
                0:
                begin
                    assert(sq_wake_bitmap == 4'd0);
                    assert(!sq_dequeue_ready);
                    dd_store_en <= 1;
                    dd_store_addr <= ADDR0;
                    dd_store_mask <= MASK0;
                    dd_store_data <= DATA0;
                    dd_store_thread_idx <= 0;
                    state <= state + 1;
                end

                // One cycle delay
                1:
                begin
                    assert(!sq_dequeue_ready);
                    assert(sq_wake_bitmap == 4'd0);
                    state <= state + 1;
                end

                // Check that the request is pending for the L2 cache, and
                // that this doesn't cause a rollback
                2:
                begin
                    assert(!sq_rollback_en);
                    assert(sq_wake_bitmap == 4'd0);

                    assert(sq_dequeue_ready);
                    assert(sq_dequeue_addr == ADDR0);
                    assert(sq_dequeue_mask == MASK0);
                    assert(sq_dequeue_data == DATA0);
                    assert(!sq_dequeue_sync);
                    assert(!sq_dequeue_flush);
                    assert(!sq_dequeue_iinvalidate);
                    assert(!sq_dequeue_dinvalidate);
                    state <= state + 1;
                end

                // Perform a read bypass, ensure the data is present
                3:
                begin
                    assert(sq_wake_bitmap == 4'd0);

                    dd_store_bypass_addr <= ADDR0;
                    dd_store_bypass_thread_idx <= 0;
                    state <= state + 1;
                end

                // wait a cycle...
                4:
                begin
                    assert(sq_wake_bitmap == 4'd0);
                    state <= state + 1;
                end

                // Check that the data was bypassed correctly
                5:
                begin
                    assert(sq_wake_bitmap == 4'd0);
                    assert(sq_store_bypass_mask == MASK0);
                    assert(sq_store_bypass_data == DATA0);

                    // Attempt to byapss from a different address that is not in the
                    // store buffer (same thread)
                    dd_store_bypass_addr <= ADDR1;
                    dd_store_bypass_thread_idx <= 0;
                    state <= state + 1;
                end

                // Wait a cycle...
                6:
                begin
                    assert(sq_wake_bitmap == 4'd0);
                    state <= state + 1;
                end

                7:
                begin
                    assert(sq_wake_bitmap == 4'd0);
                    assert(sq_store_bypass_mask == 64'd0);

                    // Attempt to bypass from the same address, but different thread
                    dd_store_bypass_addr <= ADDR0;
                    dd_store_bypass_thread_idx <= 1;
                    state <= state + 1;
                end

                // Wait a cycle...
                8:
                begin
                    assert(sq_wake_bitmap == 4'd0);
                    state <= state + 1;
                end

                9:
                begin
                    assert(sq_wake_bitmap == 4'd0);
                    assert(sq_store_bypass_mask == 64'd0);

                    // Try to enqueue another store request for the same address.
                    // This should be write combined.
                    dd_store_en <= 1;
                    dd_store_addr <= ADDR0;
                    dd_store_mask <= MASK2;
                    dd_store_data <= DATA2;
                    dd_store_thread_idx <= 0;
                    state <= state + 1;
                end

                // Wait a cycle...
                10:
                begin
                    assert(sq_wake_bitmap == 4'd0);
                    state <= state + 1;
                end

                // Check that the request has been updated
                11:
                begin
                    assert(sq_wake_bitmap == 4'd0);
                    assert(!sq_rollback_en);

                    assert(sq_dequeue_ready);
                    assert(sq_dequeue_addr == ADDR0);
                    assert(sq_dequeue_mask == COMBINED_MASK);
                    assert(sq_dequeue_data == COMBINED_DATA);
                    assert(!sq_dequeue_sync);
                    assert(!sq_dequeue_flush);
                    assert(!sq_dequeue_iinvalidate);
                    assert(!sq_dequeue_dinvalidate);
                    saved_request_idx <= sq_dequeue_idx;
                    state <= state + 1;
                end

                // Try to do a write to a different address. This should cause a rollback.
                12:
                begin
                    assert(sq_wake_bitmap == 4'd0);

                    dd_store_en <= 1;
                    dd_store_addr <= ADDR3;
                    dd_store_mask <= MASK3;
                    dd_store_data <= DATA3;
                    dd_store_thread_idx <= 0;
                    state <= state + 1;
                end

                // Wait a cycle...
                13:
                begin
                    assert(sq_wake_bitmap == 4'd0);
                    state <= state + 1;
                end

                // Here's our rollback
                14:
                begin
                    assert(sq_wake_bitmap == 4'd0);
                    assert(sq_rollback_en);
                    state <= state + 1;
                end

                // Check that rollback is deasserted
                15:
                begin
                    assert(sq_wake_bitmap == 4'd0);
                    assert(!sq_rollback_en);

                    // Accept from the L2 interface
                    sq_dequeue_ack <= 1;
                    state <= state + 1;
                end

                // Wait a cycle...
                16:
                begin
                    assert(sq_wake_bitmap == 4'd0);
                    assert(sq_dequeue_ready);
                    state <= state + 1;
                end

                // It's no longer trying to send a request.
                17:
                begin
                    assert(sq_wake_bitmap == 4'd0);
                    assert(!sq_dequeue_ready);

                    // Send the response from the L2 cache
                    storebuf_l2_response_valid <= 1;
                    storebuf_l2_response_idx <= saved_request_idx;
                    state <= state + 1;
                end

                // Should get a wakeup from the store buffer.
                18:
                begin
                    assert(sq_wake_bitmap == 4'b0001);

                    // Now try to send that store request that caused the
                    // rollback again.
                    dd_store_en <= 1;
                    dd_store_addr <= ADDR3;
                    dd_store_mask <= MASK3;
                    dd_store_data <= DATA3;
                    dd_store_thread_idx <= 0;
                    state <= state + 1;
                end

                // Wait a cycle
                19:
                begin
                    assert(sq_wake_bitmap == 4'd0);
                    state <= state + 1;
                    sq_dequeue_ack <= 1;
                end

                // Check that the request is correct.
                20:
                begin
                    assert(!sq_rollback_en);
                    assert(sq_wake_bitmap == 4'd0);

                    assert(sq_dequeue_ready);
                    assert(sq_dequeue_addr == ADDR3);
                    assert(sq_dequeue_mask == MASK3);
                    assert(sq_dequeue_data == DATA3);
                    assert(!sq_dequeue_sync);
                    assert(!sq_dequeue_flush);
                    assert(!sq_dequeue_iinvalidate);
                    assert(!sq_dequeue_dinvalidate);
                    storebuf_l2_response_valid <= 1;
                    storebuf_l2_response_idx <= sq_dequeue_idx;
                    state <= state + 1;
                end

                // Wait a cycle
                21, 22:
                begin
                    assert(sq_wake_bitmap == 4'd0);
                    state <= state + 1;
                end


                23:
                begin
                    $display("PASS");
                    $finish;
                end
            endcase
        end
    end
endmodule
