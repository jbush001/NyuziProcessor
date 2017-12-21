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

module test_io_request_queue(input clk, input reset);
    localparam ADDR0 = 32'h1234;
    localparam DATA0 = 32'hb421fdc4;
    localparam ADDR1 = 32'habcd;
    localparam DATA1 = 32'h4640426e;

    logic dd_io_write_en;
    logic dd_io_read_en;
    local_thread_idx_t  dd_io_thread_idx;
    scalar_t dd_io_addr;
    scalar_t dd_io_write_value;
    scalar_t ior_read_value;
    logic ior_rollback_en;
    local_thread_bitmap_t ior_pending;
    local_thread_bitmap_t ior_wake_bitmap;
    logic ii_ready;
    logic ii_response_valid;
    iorsp_packet_t ii_response;
    logic ior_request_valid;
    ioreq_packet_t ior_request;
    int state;

    local_thread_bitmap_t expected_wake_bitmap;
    logic expected_rollback_en;


    io_request_queue io_request_queue(.*);

    always @(posedge clk, posedge reset)
    begin
        if (reset)
        begin
            state <= 0;
        end
        else
        begin
            dd_io_write_en <= 0;
            dd_io_read_en <= 0;
            ii_ready <= 0;
            ii_response_valid <= 0;
            expected_wake_bitmap <= 0;
            expected_rollback_en <= 0;

            // Using the 'expected' signals avoids having to duplicate these
            // asserts in every state. These are zero most of the time (which
            // is defaulted above) and set to one when events occur.
            assert(ior_wake_bitmap == expected_wake_bitmap);
            assert(ior_rollback_en == expected_rollback_en);

            unique case (state)
                ////////////////////////////////////////////////
                // Write transaction
                ////////////////////////////////////////////////

                // Enqueue a write request
                0:
                begin
                    assert(!ior_request_valid);
                    assert(ior_pending == 0);

                    dd_io_write_en <= 1;
                    dd_io_thread_idx <= 0;
                    dd_io_addr <= ADDR0;
                    dd_io_write_value <= DATA0;
                    state <= state + 1;
                end

                // Check for rollback
                1:
                begin
                    assert(ior_pending == 0);
                    expected_rollback_en <= 1;
                    state <= state + 1;
                end

                // Pending should now be set.
                2:
                begin
                    assert(ior_pending == 4'b0001);
                    state <= state + 1;
                end

                // Wait for request packet
                3:
                begin
                    assert(ior_pending == 4'b0001);
                    if (ior_request_valid)
                        state <= state + 1;
                end

                // Wait a few more cycles before acknowledging
                4, 5:
                begin
                    assert(ior_pending == 4'b0001);
                    assert(ior_request_valid);
                    state <= state + 1;
                end

                // Acknowledge request
                6:
                begin
                    assert(ior_pending == 4'b0001);
                    assert(ior_request_valid);
                    ii_ready <= 1;
                    state <= state + 1;
                end

                // Check request
                7:
                begin
                    assert(ior_pending == 4'b0001);
                    assert(ior_request_valid);
                    assert(ior_request.store);
                    assert(ior_request.thread_idx == 0);
                    assert(ior_request.address == ADDR0);
                    assert(ior_request.value == DATA0);

                    state <= state + 1;
                end

                // Wait a few cycles before responding
                8, 9:
                begin
                    assert(ior_pending == 4'b0001);
                    assert(!ior_request_valid);
                    state <= state + 1;
                end

                // Send the response packet
                10:
                begin
                    assert(ior_pending == 4'b0001);
                    ii_response_valid <= 1;
                    ii_response.core <= 0;
                    ii_response.thread_idx <= 0;
                    state <= state + 1;
                    expected_wake_bitmap <= 4'b0001;
                end

                // Wait a cycle
                11: state <= state + 1;

                // Repeat the request, should not rollback this time.
                12:
                begin
                    assert(!ior_request_valid);
                    assert(ior_pending == 4'b0001);

                    dd_io_write_en <= 1;
                    dd_io_thread_idx <= 0;
                    dd_io_addr <= ADDR0;
                    dd_io_write_value <= DATA0;
                    state <= state + 1;
                end

                13:
                begin
                    assert(!ior_request_valid);
                    assert(ior_pending == 4'b0001);
                    state <= state + 1;
                end

                // This implicitly checks that there is no rollback
                // (expected_rollback_en defaults to zero)
                14:
                begin
                    state <= state + 1;
                    assert(ior_pending == 0);
                end

                ////////////////////////////////////////////////
                // Read transaction
                ////////////////////////////////////////////////
                15:
                begin
                    assert(!ior_request_valid);
                    assert(ior_pending == 0);

                    dd_io_read_en <= 1;
                    dd_io_thread_idx <= 1;
                    dd_io_addr <= ADDR1;
                    dd_io_write_value <= DATA1;
                    state <= state + 1;
                end

                // Check for rollback
                16:
                begin
                    assert(ior_pending == 0);
                    expected_rollback_en <= 1;
                    state <= state + 1;
                end

                // Pending should now be set.
                17:
                begin
                    assert(ior_pending == 4'b0010);
                    state <= state + 1;
                end

                // Wait for request packet
                18:
                begin
                    assert(ior_pending == 4'b0010);
                    if (ior_request_valid)
                        state <= state + 1;
                end

                // Wait a few more cycles before acknowledging
                19, 20:
                begin
                    assert(ior_pending == 4'b0010);
                    assert(ior_request_valid);
                    state <= state + 1;
                end

                // Acknowledge request
                21:
                begin
                    assert(ior_pending == 4'b0010);
                    assert(ior_request_valid);
                    ii_ready <= 1;
                    state <= state + 1;
                end

                // Check request
                22:
                begin
                    assert(ior_pending == 4'b0010);
                    assert(ior_request_valid);
                    assert(!ior_request.store);
                    assert(ior_request.thread_idx == 1);
                    assert(ior_request.address == ADDR1);

                    state <= state + 1;
                end

                // Wait a few cycles before responding
                23, 24:
                begin
                    assert(ior_pending == 4'b0010);
                    assert(!ior_request_valid);
                    state <= state + 1;
                end

                // Send the response packet
                25:
                begin
                    assert(ior_pending == 4'b0010);
                    ii_response_valid <= 1;
                    ii_response.core <= 0;
                    ii_response.read_value <= DATA1;
                    ii_response.thread_idx <= 1;
                    state <= state + 1;
                    expected_wake_bitmap <= 4'b0010;
                end

                // Wait a cycle
                26: state <= state + 1;

                // Repeat the request, should not rollback this time.
                27:
                begin
                    assert(!ior_request_valid);
                    assert(ior_pending == 4'b0010);

                    dd_io_read_en <= 1;
                    dd_io_thread_idx <= 1;
                    dd_io_addr <= ADDR1;
                    state <= state + 1;
                end

                28:
                begin
                    assert(!ior_request_valid);
                    assert(ior_pending == 4'b0010);
                    state <= state + 1;
                end

                // This implicitly checks that there is no rollback
                // (expected_rollback_en defaults to zero)
                29:
                begin
                    state <= state + 1;
                    assert(ior_pending == 0);
                    assert(ior_read_value == DATA1);
                end

                30:
                begin
                    $display("PASS");
                    $finish;
                end
           endcase
        end
    end
endmodule
