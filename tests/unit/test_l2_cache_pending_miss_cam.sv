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

// XXX doesn't validate entries are recycled correctly..

module test_l2_cache_pending_miss_cam(input clk, input reset);
    localparam ADDR1 = 0;
    localparam ADDR2 = 1215;
    localparam ADDR3 = 4882;
    localparam ADDR4 = 1143;

    logic request_valid;
    cache_line_index_t request_addr;
    logic enqueue_fill_request;
    logic l2r_l2_fill;
    logic duplicate_request;
    int cycle;

    l2_cache_pending_miss_cam #(.QUEUE_SIZE(8)) l2_cache_pending_miss_cam(.*);

    task enqueue_request(cache_line_index_t addr, logic load_request, logic l2_fill);
        request_valid <= 1;
        request_addr <= addr;
        enqueue_fill_request <= load_request;
        l2r_l2_fill <= l2_fill;
    endtask

    always @(posedge clk, posedge reset)
    begin
        if (reset)
        begin
            cycle <= 0;
            request_valid <= 0;
            request_addr <= 0;
            enqueue_fill_request <= 0;
            l2r_l2_fill <= 0;
        end
        else
        begin
            // Default values
            enqueue_fill_request <= 0;
            l2r_l2_fill <= 0;
            request_valid <= 0;

            cycle <= cycle + 1;
            unique0 case (cycle)
                // Enqueue a few load request
                0: enqueue_request(ADDR1, 1, 0);
                1:
                begin
                    assert(!duplicate_request);

                    // Enqueue load for another address
                    enqueue_request(ADDR2, 1, 0);
                end

                2:
                begin
                    assert(!duplicate_request);

                    // And another
                    enqueue_request(ADDR3, 1, 0);
                end

                3:
                begin
                    assert(!duplicate_request);

                    // Duplicate first request
                    enqueue_request(ADDR1, 1, 0);
                end

                4:
                begin
                    assert(duplicate_request);

                    // Duplicate second request
                    enqueue_request(ADDR2, 1, 0);
                end

                5:
                begin
                    assert(duplicate_request);

                    // Duplicate third request
                    enqueue_request(ADDR3, 1, 0);
                end

                6:
                begin
                    assert(duplicate_request);

                    // load is not valid. Should not update CAM...
                    enqueue_request(ADDR4, 0, 0);
                end

                7:
                begin
                    assert(!duplicate_request);

                    // Enqueue address for real to validate last did not update cam.
                    // Will not be marked as dup because it's new.
                    enqueue_request(ADDR4, 1, 0);
                end

                8:
                begin
                    assert(!duplicate_request);

                    // Completing a request
                    enqueue_request(ADDR2, 0, 1);
                end

                // Need to wait a for next clock cycle for this to take effect
                9:  assert(!duplicate_request);

                10:
                begin
                    // Validate request was completed by reissuing and insuring it
                    // is not marked as a dup.
                    enqueue_request(ADDR2, 1, 0);
                end

                11:
                begin
                    assert(!duplicate_request);

                    // Set request_valid, but don't make it a valid load request
                    // ensure it doesn't mess up existing entry.
                    enqueue_request(ADDR3, 0, 0);
                end

                // Check entry. This should still be a dup.
                12:  enqueue_request(ADDR3, 1, 0);

                13:
                begin
                    assert(duplicate_request);
                    $display("PASS");
                    $finish;
                end
            endcase
        end
    end
endmodule
