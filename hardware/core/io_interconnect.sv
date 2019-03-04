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
// Accepts IO requests from all cores and serializes requests to external
// IO interface. Sends responses back to cores.
//

module io_interconnect(
    input                            clk,
    input                            reset,

    // From core
    input [`NUM_CORES - 1:0]         ior_request_valid,
    input ioreq_packet_t             ior_request[`NUM_CORES],

    // To core
    output logic                     ii_ready[`NUM_CORES],
    output logic                     ii_response_valid,
    output iorsp_packet_t            ii_response,
    io_bus_interface.master          io_bus);

    core_id_t grant_idx;
    logic[`NUM_CORES - 1:0] grant_oh;
    logic request_sent;
    core_id_t request_core;
    local_thread_idx_t request_thread_idx;
    ioreq_packet_t grant_request;

    genvar request_idx;
    generate
        for (request_idx = 0; request_idx < `NUM_CORES; request_idx++)
        begin : handshake_gen
            assign ii_ready[request_idx] = grant_oh[request_idx];
        end
    endgenerate

    genvar grant_idx_bit;
    generate
        if (`NUM_CORES > 1)
        begin
            rr_arbiter #(.NUM_REQUESTERS(`NUM_CORES)) request_arbiter(
                .request(ior_request_valid),
                .update_lru(1'b1),
                .grant_oh(grant_oh),
                .*);

            oh_to_idx #(.NUM_SIGNALS(`NUM_CORES)) oh_to_idx_grant(
                .one_hot(grant_oh),
                .index(grant_idx[CORE_ID_WIDTH - 1:0]));

            // Ensure high bits are zeroed. Notes in defines.sv
            // describe why the core ID width needs to be hardcoded.
            for (grant_idx_bit = CORE_ID_WIDTH; grant_idx_bit < $bits(grant_idx);
                grant_idx_bit++)
            begin : grant_bit_gen
                assign grant_idx[grant_idx_bit] = 0;
            end

            assign grant_request = ior_request[grant_idx[CORE_ID_WIDTH - 1:0]];
        end
        else
        begin
            assign grant_oh[0] = ior_request_valid[0];
            assign grant_idx = 0;
            assign grant_request = ior_request[0];
        end
    endgenerate

    assign io_bus.write_en = |grant_oh && grant_request.store;
    assign io_bus.read_en = |grant_oh && !grant_request.store;
    assign io_bus.write_data = grant_request.value;
    assign io_bus.address = grant_request.address;

    always_ff @(posedge clk)
    begin
        ii_response.core <= request_core;
        ii_response.thread_idx <= request_thread_idx;
        ii_response.read_value <= io_bus.read_data;
        if (|ior_request_valid)
        begin
            request_core <= grant_idx;
            request_thread_idx <= grant_request.thread_idx;
        end
    end

    always_ff @(posedge clk, posedge reset)
    begin
        if (reset)
        begin
            /*AUTORESET*/
            // Beginning of autoreset for uninitialized flops
            ii_response_valid <= '0;
            request_sent <= '0;
            // End of automatics
        end
        else
        begin
            request_sent <= |ior_request_valid;
            ii_response_valid <= request_sent;
        end
    end
endmodule
