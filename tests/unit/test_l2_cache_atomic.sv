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
// Test atomic operations in L2 cache
//
module test_l2_cache_atomic(input clk, input reset);
    localparam ADDR0 = 'h123;

    localparam DATA0 = 512'h5f4bfd55;
    localparam DATA1 = 512'h43931f6f;
    localparam DATA2 = 512'h44dff947;

    logic[`NUM_CORES - 1:0] l2i_request_valid;
    l2req_packet_t l2i_request[`NUM_CORES];
    logic l2_ready[`NUM_CORES];
    logic l2_response_valid;
    l2rsp_packet_t l2_response;
    axi4_interface axi_bus();
    logic[L2_PERF_EVENTS - 1:0] l2_perf_events;
    int state;

    l2_cache l2_cache(.*);

    assign axi_bus.s_arready = 1;
    assign axi_bus.s_rvalid = 1;
    assign axi_bus.s_rdata = 32'd0;
    assign axi_bus.s_bvalid = 1;
    assign axi_bus.s_awready = 1;
    assign axi_bus.s_wready = 1;

    assign l2i_request[0].store_mask = 64'b1111;


    always @(posedge clk, posedge reset)
    begin
        if (reset)
        begin
            state <= 0;
            l2i_request[0].core <= 0;
        end
        else
        begin
            // default values
            l2i_request_valid <= '0;

            unique case (state)
                /////////////////////////////////////////////////////////////
                // Do an initial load miss so a cache line is resident.
                /////////////////////////////////////////////////////////////
                0:
                begin
                    l2i_request_valid <= 1;
                    l2i_request[0].id <= 0;
                    l2i_request[0].packet_type = L2REQ_LOAD;
                    l2i_request[0].cache_type = CT_DCACHE;
                    l2i_request[0].address = ADDR0;
                    state <= state + 1;
                end

                // Wait for response
                1: if (l2_response_valid)
                    state <= state + 1;

                /////////////////////////////////////////////////////////////
                // Successful sync load/store
                /////////////////////////////////////////////////////////////

                // Sync load
                2:
                begin
                    l2i_request_valid <= 1;
                    l2i_request[0].id <= 0;
                    l2i_request[0].packet_type = L2REQ_LOAD_SYNC;
                    state <= state + 1;
                end

                // Wait for response
                3: if (l2_response_valid)
                begin
                    assert(l2_response.core == 0);
                    assert(l2_response.id == 0);
                    assert(l2_response.packet_type == L2RSP_LOAD_ACK);
                    assert(l2_response.cache_type == CT_DCACHE);
                    assert(l2_response.address == ADDR0);
                    assert(l2_response.data == '0);
                    state <= state + 1;
                end

                // Sync store
                4:
                begin
                    l2i_request_valid <= 1;
                    l2i_request[0].packet_type = L2REQ_STORE_SYNC;
                    l2i_request[0].data = DATA0;  // LSB aligned
                    state <= state + 1;
                end

                5: if (l2_response_valid)
                begin
                    assert(l2_response.core == 0);
                    assert(l2_response.id == 0);
                    assert(l2_response.packet_type == L2RSP_STORE_ACK);
                    assert(l2_response.cache_type == CT_DCACHE);
                    assert(l2_response.address == ADDR0);
                    assert(l2_response.data == DATA0);
                    assert(l2_response.status);    // succcessfully stored
                    state <= state + 1;
                end

                /////////////////////////////////////////////////////////////
                // Two threads attempt to update the same location, one
                // wins and the other one loses
                /////////////////////////////////////////////////////////////

                // Thread 1 requests
                6:
                begin
                    l2i_request_valid <= 1;
                    l2i_request[0].id <= 1;
                    l2i_request[0].packet_type = L2REQ_LOAD_SYNC;
                    state <= state + 1;
                end

                7:  // Thread 2 requests
                begin
                    l2i_request_valid <= 1;
                    l2i_request[0].id <= 2;
                    l2i_request[0].packet_type = L2REQ_LOAD_SYNC;
                    state <= state + 1;
                end

                // Response 1
                8: if (l2_response_valid)
                begin
                    assert(l2_response.core == 0);
                    assert(l2_response.id == 1);
                    assert(l2_response.packet_type == L2RSP_LOAD_ACK);
                    assert(l2_response.address == ADDR0);
                    assert(l2_response.data == DATA0);
                    state <= state + 1;
                end

                // Response 2
                9: if (l2_response_valid)
                begin
                    assert(l2_response.core == 0);
                    assert(l2_response.id == 2);
                    assert(l2_response.packet_type == L2RSP_LOAD_ACK);
                    assert(l2_response.address == ADDR0);
                    assert(l2_response.data == DATA0);
                    state <= state + 1;
                end

                // Sync store 1
                10:
                begin
                    l2i_request_valid <= 1;
                    l2i_request[0].id = 1;
                    l2i_request[0].packet_type = L2REQ_STORE_SYNC;
                    l2i_request[0].data = DATA1;
                    state <= state + 1;
                end

                // Sync store 2
                11:
                begin
                    l2i_request_valid <= 1;
                    l2i_request[0].id = 2;
                    l2i_request[0].packet_type = L2REQ_STORE_SYNC;
                    l2i_request[0].data = DATA2;
                    state <= state + 1;
                end

                // Response 1
                12: if (l2_response_valid)
                begin
                    assert(l2_response.core == 0);
                    assert(l2_response.id == 1);
                    assert(l2_response.packet_type == L2RSP_STORE_ACK);
                    assert(l2_response.address == ADDR0);
                    assert(l2_response.data == DATA1);
                    assert(l2_response.status); // succcessfully stored
                    state <= state + 1;
                end

                // Response 2
                13: if (l2_response_valid)
                begin
                    assert(l2_response.core == 0);
                    assert(l2_response.id == 2);
                    assert(l2_response.packet_type == L2RSP_STORE_ACK);
                    assert(l2_response.address == ADDR0);
                    assert(l2_response.data == DATA1);
                    assert(!l2_response.status); // unsuccessful
                    state <= state + 1;
                end

                14:
                begin
                    $display("PASS");
                    $finish;
                end
            endcase
        end
    end
endmodule


