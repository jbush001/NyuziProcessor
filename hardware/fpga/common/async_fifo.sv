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
// Asynchronous FIFO, with two clock domains
// reset is asynchronous and is synchronized to each clock domain
// internally.
// NUM_ENTRIES must be a power of two and >= 2
//

module async_fifo
    #(parameter WIDTH = 32,
    parameter NUM_ENTRIES = 8)

    (input                  reset,

    // Read.
    input                   read_clk,
    input                   read_en,
    output [WIDTH - 1:0]    read_data,
    output logic            empty,

    // Write
    input                   write_clk,
    input                   write_en,
    output logic            full,
    input [WIDTH - 1:0]     write_data);

    localparam ADDR_WIDTH = $clog2(NUM_ENTRIES);

    logic[ADDR_WIDTH - 1:0] write_ptr_sync;
    logic[ADDR_WIDTH - 1:0] read_ptr;
    logic[ADDR_WIDTH - 1:0] read_ptr_gray;
    logic[ADDR_WIDTH - 1:0] read_ptr_nxt;
    logic[ADDR_WIDTH - 1:0] read_ptr_gray_nxt;
    logic reset_rsync;
    logic[ADDR_WIDTH - 1:0] read_ptr_sync;
    logic[ADDR_WIDTH - 1:0] write_ptr;
    logic[ADDR_WIDTH - 1:0] write_ptr_gray;
    logic[ADDR_WIDTH - 1:0] write_ptr_nxt;
    logic[ADDR_WIDTH - 1:0] write_ptr_gray_nxt;
    logic reset_wsync;
    logic [WIDTH - 1:0] fifo_data[0:NUM_ENTRIES - 1];

    assign read_ptr_nxt = read_ptr + 1;
    assign read_ptr_gray_nxt = read_ptr_nxt ^ (read_ptr_nxt >> 1);
    assign write_ptr_nxt = write_ptr + 1;
    assign write_ptr_gray_nxt = write_ptr_nxt ^ (write_ptr_nxt >> 1);

    //
    // Read clock domain
    //
    synchronizer #(.WIDTH(ADDR_WIDTH)) write_ptr_synchronizer(
        .clk(read_clk),
        .reset(reset_rsync),
        .data_o(write_ptr_sync),
        .data_i(write_ptr_gray));

    assign empty = write_ptr_sync == read_ptr_gray;

    synchronizer #(.RESET_STATE(1)) read_reset_synchronizer(
        .clk(read_clk),
        .reset(reset),
        .data_i(0),
        .data_o(reset_rsync));

    always_ff @(posedge read_clk, posedge reset_rsync)
    begin
        if (reset_rsync)
        begin
            /*AUTORESET*/
            // Beginning of autoreset for uninitialized flops
            read_ptr <= '0;
            read_ptr_gray <= '0;
            // End of automatics
        end
        else if (read_en && !empty)
        begin
            read_ptr <= read_ptr_nxt;
            read_ptr_gray <= read_ptr_gray_nxt;
        end
    end

    assign read_data = fifo_data[read_ptr];

    //
    // Write clock domain
    //
    synchronizer #(.WIDTH(ADDR_WIDTH)) read_ptr_synchronizer(
        .clk(write_clk),
        .reset(reset_wsync),
        .data_o(read_ptr_sync),
        .data_i(read_ptr_gray));

    assign full = write_ptr_gray_nxt == read_ptr_sync;

    synchronizer #(.RESET_STATE(1)) write_reset_synchronizer(
        .clk(write_clk),
        .reset(reset),
        .data_i(0),
        .data_o(reset_wsync));

    always_ff @(posedge write_clk, posedge reset_wsync)
    begin
        if (reset_wsync)
        begin
            `ifdef NEVER
            fifo_data <= 0;    // Suppress autoreset
            `endif

            /*AUTORESET*/
            // Beginning of autoreset for uninitialized flops
            write_ptr <= '0;
            write_ptr_gray <= '0;
            // End of automatics
        end
        else if (write_en && !full)
        begin
            fifo_data[write_ptr] <= write_data;
            write_ptr <= write_ptr_nxt;
            write_ptr_gray <= write_ptr_gray_nxt;
        end
    end
endmodule
