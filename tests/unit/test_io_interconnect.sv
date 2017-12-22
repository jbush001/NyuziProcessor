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

module test_io_interconnect(input clk, input reset);
    localparam ADDR0 = 32'h1234;
    localparam ADDR1 = 32'h5678;
    localparam DATA0 = 32'h5f168902;
    localparam DATA1 = 32'h1d483d36;

    logic [`NUM_CORES - 1:0] ior_request_valid;
    ioreq_packet_t ior_request[`NUM_CORES];
    logic ii_ready[`NUM_CORES];
    logic ii_response_valid;
    iorsp_packet_t ii_response;
    io_bus_interface io_bus();
    int state;

    io_interconnect io_interconnect(.*);

    always @(posedge clk, posedge reset)
    begin
        if (reset)
            state <= 0;
        else
        begin
            ior_request[0] <= '0;

            unique case (state)
                // Issue a store request
                0:
                begin
                    assert(!io_bus.read_en);
                    assert(!io_bus.write_en);
                    assert(!ii_response_valid);

                    ior_request[0].store <= 1;
                    ior_request[0].thread_idx <= 1;
                    ior_request[0].address <= ADDR0;
                    ior_request[0].value <= DATA0;
                    ior_request_valid[0] <= 1;
                    state <= state + 1;
                end

                // Request on I/O bus
                1:
                begin
                    ior_request_valid[0] <= 0;

                    assert(ii_ready[0]);
                    assert(!io_bus.read_en);
                    assert(!ii_response_valid);
                    assert(ii_ready[0]);
                    assert(io_bus.write_en);
                    assert(io_bus.address == ADDR0);
                    assert(io_bus.write_data == DATA0);
                    state <= state + 1;
                end

                2: state <= state + 1;


                // Response packet
                3:
                begin
                    assert(!io_bus.read_en);
                    assert(!io_bus.write_en);
                    assert(ii_response_valid);
                    assert(ii_response.core == 0);
                    assert(ii_response.thread_idx == 1);
                    state <= state + 1;
                end

                // Issue a load request
                4:
                begin
                    assert(!io_bus.read_en);
                    assert(!io_bus.write_en);
                    assert(!ii_response_valid);

                    ior_request[0].store <= 0;
                    ior_request[0].thread_idx <= 2;
                    ior_request[0].address <= ADDR1;
                    ior_request_valid[0] <= 1;
                    state <= state + 1;
                end

                // Load request on the I/O bus
                5:
                begin
                    ior_request_valid[0] <= 0;

                    assert(!io_bus.write_en);
                    assert(!ii_response_valid);
                    assert(ii_ready[0]);
                    assert(io_bus.read_en);
                    assert(io_bus.read_en);
                    assert(io_bus.address == ADDR1);
                    state <= state + 1;
                    io_bus.read_data <= DATA1;
                end

                6: state <= 7;

                // Response packet
                7:
                begin
                    assert(!io_bus.read_en);
                    assert(!io_bus.write_en);
                    assert(ii_response_valid);
                    assert(ii_response.core == 0);
                    assert(ii_response.thread_idx == 2);
                    assert(ii_response.read_value == DATA1);
                    state <= state + 1;
                end

                8:
                begin
                    $display("PASS");
                    $finish;
                end
            endcase
        end
    end
endmodule
