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
// Some basic l1_store_queue scenarios.
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
    localparam ADDR4 = 'h108;
    localparam DATA4 = 512'h9a4a5591ca5bbed51472cf95121b2e8b817e6edafa6be26be4415d65a99234690957fdc95fda469fd7ece9e8ac49b06a00329f891ba90ec784d8ef233e030180;
    localparam MASK4 = 64'hffffffff_ffffffff;
    localparam ADDR5 = 'h644;
    localparam DATA5 = 512'hb1c5638548125874ab562243b62795971335ff2ac0ca0f82b60c56d864187e3bf3c1b94666fdf4701ea826f113c137b4969908a193cbf17d96b653d01d09eba3;
    localparam MASK5 = 64'hffffffff_ffffffff;

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
    logic storebuf_dequeue_ack;
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
    int cycle;
    l1_miss_entry_idx_t saved_request_idx;

    l1_store_queue l1_store_queue(.*);

    task store_request(input cache_line_index_t address, input logic[CACHE_LINE_BYTES - 1:0] mask,
        input cache_line_data_t data);
        dd_store_en <= 1;
        dd_store_addr <= address;
        dd_store_mask <= mask;
        dd_store_data <= data;
        dd_store_thread_idx <= 0;
    endtask

    always @(posedge clk, posedge reset)
    begin
        if (reset)
            cycle <= 0;
        else
        begin
            dd_store_en <= 0;
            dd_flush_en <= 0;
            dd_membar_en <= 0;
            dd_iinvalidate_en <= 0;
            dd_dinvalidate_en <= 0;
            dd_store_sync <= 0;
            storebuf_dequeue_ack <= 0;
            storebuf_l2_response_valid <= 0;
            cycle <= cycle + 1;

            unique0 case (cycle)
                ////////////////////////////////////////////////////////////
                // Normal store request, write combine, bypass,
                // rollback on store buffer full, wakeup
                ////////////////////////////////////////////////////////////

                // Queue a store request
                0:
                begin
                    assert(sq_wake_bitmap == 4'd0);
                    assert(!sq_dequeue_ready);
                    store_request(ADDR0, MASK0, DATA0);
                end

                // One cycle delay
                1:
                begin
                    assert(!sq_dequeue_ready);
                    assert(sq_wake_bitmap == 4'd0);
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
                end

                // Perform a read bypass, ensure the data is present
                3:
                begin
                    assert(sq_wake_bitmap == 4'd0);

                    dd_store_bypass_addr <= ADDR0;
                    dd_store_bypass_thread_idx <= 0;
                end

                // wait a cycle...
                4:
                begin
                    assert(sq_wake_bitmap == 4'd0);
                end

                // Check that the data was bypassed correctly
                5:
                begin
                    assert(!sq_rollback_en);
                    assert(sq_wake_bitmap == 4'd0);
                    assert(sq_store_bypass_mask == MASK0);
                    assert(sq_store_bypass_data == DATA0);

                    // Attempt to byapss from a different address that is not in the
                    // store buffer (same thread)
                    dd_store_bypass_addr <= ADDR1;
                    dd_store_bypass_thread_idx <= 0;
                end

                // Wait a cycle...
                6:
                begin
                    assert(sq_wake_bitmap == 4'd0);
                end

                7:
                begin
                    assert(sq_wake_bitmap == 4'd0);
                    assert(sq_store_bypass_mask == 64'd0);

                    // Attempt to bypass from the same address, but different thread
                    dd_store_bypass_addr <= ADDR0;
                    dd_store_bypass_thread_idx <= 1;
                end

                // Wait a cycle...
                8:
                begin
                    assert(sq_wake_bitmap == 4'd0);
                end

                9:
                begin
                    assert(sq_wake_bitmap == 4'd0);
                    assert(sq_store_bypass_mask == 64'd0);

                    // Try to enqueue another store request for the same address.
                    // This should be write combined.
                    store_request(ADDR0, MASK2, DATA2);
                end

                // Wait a cycle...
                10:
                begin
                    assert(sq_wake_bitmap == 4'd0);
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
                end

                // Try to do a write to a different address. This should cause a rollback.
                12:
                begin
                    assert(sq_wake_bitmap == 4'd0);

                    store_request(ADDR3, MASK3, DATA3);
                end

                // Wait a cycle...
                13:
                begin
                    assert(sq_wake_bitmap == 4'd0);
                end

                // Here's our rollback
                14:
                begin
                    assert(sq_wake_bitmap == 4'd0);
                    assert(sq_rollback_en);
                end

                // Check that rollback is deasserted
                15:
                begin
                    assert(sq_wake_bitmap == 4'd0);
                    assert(!sq_rollback_en);

                    // Accept from the L2 interface
                    storebuf_dequeue_ack <= 1;
                end

                // Wait a cycle...
                16:
                begin
                    assert(sq_wake_bitmap == 4'd0);
                    assert(sq_dequeue_ready);
                end

                // It's no longer trying to send a request.
                17:
                begin
                    assert(sq_wake_bitmap == 4'd0);
                    assert(!sq_dequeue_ready);

                    // Send the response from the L2 cache
                    storebuf_l2_response_valid <= 1;
                    storebuf_l2_response_idx <= saved_request_idx;
                end

                // Should get a wakeup from the store buffer.
                18:
                begin
                    assert(sq_wake_bitmap == 4'b0001);

                    // Now try to send that store request that caused the
                    // rollback again.
                    store_request(ADDR3, MASK3, DATA3);
                end

                // Wait a cycle
                19:
                begin
                    assert(sq_wake_bitmap == 4'd0);
                    storebuf_dequeue_ack <= 1;
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
                end

                // Wait a cycle. There's no wakeup, because a thread was not rolled back.
                21, 22:
                begin
                    assert(sq_wake_bitmap == 4'd0);
                end

                ////////////////////////////////////////////////////////////
                // Synchronized store request
                ////////////////////////////////////////////////////////////

                // Send a synchronized store request.
                23:
                begin
                    assert(sq_wake_bitmap == 4'd0);
                    assert(!sq_dequeue_ready);
                    store_request(ADDR4, MASK4, DATA4);
                    dd_store_sync <= 1;
                end

                // Wait a cycle
                24:
                begin
                    assert(sq_wake_bitmap == 4'd0);
                end

                // On the first pass, this should be rolled back to
                // wait for an L2 response
                25:
                begin
                    assert(sq_wake_bitmap == 4'd0);
                    assert(sq_rollback_en);
                end

                // Check the request and acknowledge it
                26:
                begin
                    assert(sq_dequeue_ready);
                    assert(sq_dequeue_addr == ADDR4);
                    assert(sq_dequeue_mask == MASK4);
                    assert(sq_dequeue_data == DATA4);
                    assert(sq_dequeue_sync);
                    assert(!sq_dequeue_flush);
                    assert(!sq_dequeue_iinvalidate);
                    assert(!sq_dequeue_dinvalidate);
                    saved_request_idx <= sq_dequeue_idx;
                    storebuf_dequeue_ack <= 1;
                end

                // Wait a cycle
                27:
                begin
                    assert(sq_wake_bitmap == 4'd0);
                end

                // L2 response
                28:
                begin
                    storebuf_l2_response_valid <= 1;
                    storebuf_l2_response_idx <= saved_request_idx;
                    storebuf_l2_sync_success <= 1;
                end

                // Wakeup from store buffer.
                29:
                begin
                    assert(sq_wake_bitmap == 4'b0001);
                end

                30:
                begin
                    assert(sq_wake_bitmap == 4'd0);

                    // Resend synchronized store request
                    store_request(ADDR4, MASK4, DATA4);
                    dd_store_sync <= 1;
                end

                // Wait a cycle
                31:
                begin
                    assert(sq_wake_bitmap == 4'd0);
                end

                // Check that this was not rolled back
                32:
                begin
                    assert(!sq_rollback_en);
                    assert(sq_wake_bitmap == 4'd0);
                    assert(sq_store_sync_success);
                end

                ////////////////////////////////////////////////////////////
                // Memory barrier
                ////////////////////////////////////////////////////////////

                // Send memory barrier when nothing is pending. This should
                // not roll back.
                33:
                begin
                    assert(sq_wake_bitmap == 4'd0);
                    dd_membar_en <= 1;
                    dd_store_thread_idx <= 2;
                end

                // Wait a cycle
                34:
                begin
                    assert(sq_wake_bitmap == 4'd0);
                    assert(!sq_rollback_en);
                end

                // Ensure there isn't a rollback
                35:
                begin
                    assert(sq_wake_bitmap == 4'd0);
                    assert(!sq_rollback_en);
                end

                // Queue a pending store request
                36:
                begin
                    assert(sq_wake_bitmap == 4'd0);
                    assert(!sq_dequeue_ready);
                    store_request(ADDR5, MASK5, DATA5);
                    dd_store_thread_idx <= 2;
                end

                // Then send a memory barrier again.
                37:
                begin
                    assert(sq_wake_bitmap == 4'd0);
                    dd_membar_en <= 1;
                    dd_store_thread_idx <= 2;
                end

                // Wait a cycle
                38:
                begin
                    assert(sq_wake_bitmap == 4'd0);
                    assert(!sq_rollback_en);
                end

                // This time there should be a rollback
                39:
                begin
                    assert(sq_wake_bitmap == 4'd0);
                    assert(sq_rollback_en);
                end

                // Check the request and acknowledge it
                40:
                begin
                    assert(sq_dequeue_ready);
                    assert(sq_dequeue_addr == ADDR5);
                    assert(sq_dequeue_mask == MASK5);
                    assert(sq_dequeue_data == DATA5);
                    assert(!sq_dequeue_sync);
                    assert(!sq_dequeue_flush);
                    assert(!sq_dequeue_iinvalidate);
                    assert(!sq_dequeue_dinvalidate);
                    saved_request_idx <= sq_dequeue_idx;
                    storebuf_dequeue_ack <= 1;
                end

                // Wait a cycle
                41:
                begin
                    assert(sq_wake_bitmap == 4'd0);
                end

                // L2 response
                42:
                begin
                    storebuf_l2_response_valid <= 1;
                    storebuf_l2_response_idx <= saved_request_idx;
                    storebuf_l2_sync_success <= 1;
                end

                // Wakeup from store buffer.
                43:
                begin
                    assert(sq_wake_bitmap == 4'b0100);
                end

                ////////////////////////////////////////////////////////////
                // L2 responds same cycle a new entry is sent. This is a
                // special case to avoid the thread hanging.
                ////////////////////////////////////////////////////////////
                60:
                begin
                    // Put an entry into the store buffer
                    store_request(ADDR4, MASK4, DATA4);
                end
                // wait a cycle

                62:
                begin
                    // Accept request from L2 cache
                    saved_request_idx <= sq_dequeue_idx;
                    storebuf_dequeue_ack <= 1;
                end

                63:
                begin
                    // Second request. Would normally block, but L2 acknowledges the
                    // same cycle.
                    store_request(ADDR5, MASK5, DATA5);
                    storebuf_l2_response_valid <= 1;
                    storebuf_l2_response_idx <= saved_request_idx;
                end
                // wait cycle

                65:
                begin
                    // Check that there isn't a rollback and the new request is
                    // pending.
                    assert(!sq_rollback_en);
                    assert(sq_dequeue_ready);
                    assert(sq_dequeue_addr == ADDR5);
                    assert(sq_dequeue_mask == MASK5);
                    assert(sq_dequeue_data == DATA5);

                    // Acknowledge it to get back to known state
                    saved_request_idx <= sq_dequeue_idx;
                    storebuf_dequeue_ack <= 1;
                end

                66:
                begin
                    storebuf_l2_response_valid <= 1;
                    storebuf_l2_response_idx <= saved_request_idx;
                end

                ////////////////////////////////////////////////////////////
                // Cache control commands
                ////////////////////////////////////////////////////////////
                70: dd_flush_en <= 1;
                // wait a cycle

                72:
                begin
                    assert(!sq_rollback_en);
                    assert(sq_dequeue_ready);
                    assert(sq_dequeue_flush);
                    assert(!sq_dequeue_iinvalidate);
                    assert(!sq_dequeue_dinvalidate);

                    storebuf_dequeue_ack <= 1;
                end

                73:
                begin
                    storebuf_l2_response_valid <= 1;
                    storebuf_l2_response_idx <= sq_dequeue_idx;
                end
                // wait a cycle


                75: dd_iinvalidate_en <= 1;
                // wait a cycle

                77:
                begin
                    assert(!sq_rollback_en);
                    assert(sq_dequeue_ready);
                    assert(!sq_dequeue_flush);
                    assert(sq_dequeue_iinvalidate);
                    assert(!sq_dequeue_dinvalidate);

                    storebuf_dequeue_ack <= 1;
                end

                78:
                begin
                    storebuf_l2_response_valid <= 1;
                    storebuf_l2_response_idx <= sq_dequeue_idx;
                end
                // wait a cycle

                80: dd_dinvalidate_en <= 1;
                // wait a cycle

                82:
                begin
                    assert(!sq_rollback_en);
                    assert(sq_dequeue_ready);
                    assert(!sq_dequeue_flush);
                    assert(!sq_dequeue_iinvalidate);
                    assert(sq_dequeue_dinvalidate);

                    storebuf_dequeue_ack <= 1;
                end

                83:
                begin
                    storebuf_l2_response_valid <= 1;
                    storebuf_l2_response_idx <= sq_dequeue_idx;
                end

                85:
                begin
                    $display("PASS");
                    $finish;
                end
            endcase
        end
    end
endmodule
