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

`include "defines.sv"

//
// Block SRAM with 1 read port and 1 write port.
// Reads and writes are performed synchronously. The read value appears
// on the next clock edge after the address and read_en are asserted
// If read_en is not asserted, the value of read_data is undefined during
// the next cycle. The READ_DURING_WRITE parameter determines what happens
// if a read and a write are performed to the same address in the same cycle:
//  - "NEW_DATA" this will return the newly written data ("read-after-write").
//  - "DONT_CARE" The results are undefined. This can be used to improve clock
//    speed.
// This does not clear memory contents on reset.
//

module sram_1r1w
    #(parameter DATA_WIDTH = 32,
    parameter SIZE = 1024,
    parameter READ_DURING_WRITE = "NEW_DATA",
    parameter ADDR_WIDTH = $clog2(SIZE))

    (input                         clk,
    input                          read_en,
    input [ADDR_WIDTH - 1:0]       read_addr,
    output logic[DATA_WIDTH - 1:0] read_data,
    input                          write_en,
    input [ADDR_WIDTH - 1:0]       write_addr,
    input [DATA_WIDTH - 1:0]       write_data);

`ifdef VENDOR_ALTERA
    logic[DATA_WIDTH - 1:0] data_from_ram;

    // Not all Altera FPGA families support READ_DURING_WRITE_MIXED_PORTS
    // (which I found out the hard way). I just set that to DONT_CARE and
    // insert my own logic to bypass results.
    ALTSYNCRAM #(
        .OPERATION_MODE("DUAL_PORT"),
        .WIDTH_A(DATA_WIDTH),
        .WIDTHAD_A(ADDR_WIDTH),
        .WIDTH_B(DATA_WIDTH),
        .WIDTHAD_B(ADDR_WIDTH),
        .READ_DURING_WRITE_MIXED_PORTS("DONT_CARE")
    ) data0(
        .clock0(clk),
        .clock1(clk),

        // Write port
        .wren_a(write_en),
        .address_a(write_addr),
        .data_a(write_data),
        .q_a(),

        // Read port
        .rden_b(read_en),
        .address_b(read_addr),
        .q_b(data_from_ram));

    generate
        if (READ_DURING_WRITE == "NEW_DATA")
        begin
            logic pass_thru_en;
            logic[DATA_WIDTH - 1:0] pass_thru_data;

            always_ff @(posedge clk)
            begin
                pass_thru_en <= write_en && read_en && read_addr == write_addr;
                pass_thru_data <= write_data;
            end

            assign read_data = pass_thru_en ? pass_thru_data : data_from_ram;
        end
        else
        begin
            assign read_data = data_from_ram;
        end
    endgenerate
`elsif MEMORY_COMPILER
    generate
        `define _GENERATE_SRAM1R1W
        `include "srams.inc"
        `undef     _GENERATE_SRAM1R1W
    endgenerate
`else
    // Simulation
    logic[DATA_WIDTH - 1:0] data[SIZE];

    always_ff @(posedge clk)
    begin
        if (write_en)
            data[write_addr] <= write_data;

        if (write_addr == read_addr && write_en && read_en)
        begin
            if (READ_DURING_WRITE == "NEW_DATA")
                read_data <= write_data;    // Bypass
            else
                read_data <= {DATA_WIDTH{1'bx}};    // This will be randomized by Verilator
        end
        else if (read_en)
            read_data <= data[read_addr];
        else
            read_data <= {DATA_WIDTH{1'bx}};
    end

    initial
    begin
        if ($test$plusargs("dumpmems") != 0)
            $display("sram1r1w %d %d", DATA_WIDTH, SIZE);
    end
`endif
endmodule
