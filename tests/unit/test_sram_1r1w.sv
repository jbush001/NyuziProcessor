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
// test_sram_1r1w has different implementations for different technologies
// (each FPGA has its own IP blocks), so this only validates the simulator
// version.
//
module test_sram_1r1w(input clk, input reset);
    localparam DATA_WIDTH = 32;
    localparam SIZE = 64;
    localparam ADDR_WIDTH = $clog2(SIZE);

    localparam ADDR1 = 12;
    localparam ADDR2 = 17;
    localparam ADDR3 = 19;
    localparam DATA1 = 'h245fa7d4;
    localparam DATA2 = 'h7b8261b;
    localparam DATA3 = 'h47b06ea2;
    localparam DATA4 = 'hdff64bb1;

    int cycle;

    // These signals are shared between both memories
    logic write_en;
    logic[ADDR_WIDTH - 1:0] write_addr;
    logic[DATA_WIDTH - 1:0] write_data;
    logic read_en;
    logic[ADDR_WIDTH - 1:0] read_addr;

    // Outputs per memory
    logic[DATA_WIDTH - 1:0] read_data1;
    logic[DATA_WIDTH - 1:0] read_data2;

    sram_1r1w #(
        .DATA_WIDTH(32),
        .SIZE(64),
        .ADDR_WIDTH(ADDR_WIDTH),
        .READ_DURING_WRITE("NEW_DATA")
    ) ram1(
        .read_data(read_data1),
        .*);

    sram_1r1w #(
        .DATA_WIDTH(32),
        .SIZE(64),
        .ADDR_WIDTH(ADDR_WIDTH),
        .READ_DURING_WRITE("DONT_CARE")
    ) ram2(
        .read_data(read_data2),
        .*);

    always @(posedge clk, posedge reset)
    begin
        if (reset)
            cycle <= 0;
        else
        begin
            // Default values
            write_en <= 0;
            read_en <= 0;

            cycle <= cycle + 1;
            unique0 case (cycle)
                // Write some values
                0:
                begin
                    write_en <= 1;
                    write_addr <= ADDR1;
                    write_data <= DATA1;
                end

                1:
                begin
                    write_en <= 1;
                    write_addr <= ADDR2;
                    write_data <= DATA2;
                end

                // Read them back
                2:
                begin
                    read_en <= 1;
                    read_addr <= ADDR1;
                end

                // skip 3 to wait for result
                4:
                begin
                    assert(read_data1 == DATA1);
                    assert(read_data2 == DATA1);
                end

                // Now read and write at the same time, but different addresses
                5:
                begin
                    read_en <= 1;
                    read_addr <= ADDR2;
                    write_en <= 1;
                    write_addr <= ADDR3;
                    write_data <= DATA3;
                end

                // skip 6
                7:
                begin
                    assert(read_data1 == DATA2);
                    assert(read_data2 == DATA2);

                    // read back the written value
                    read_en <= 1;
                    read_addr <= ADDR3;
                end

                // skip 8
                9:
                begin
                    assert(read_data1 == DATA3);
                    assert(read_data2 == DATA3);

                    // read and write the same address simultaneously.
                    read_en <= 1;
                    read_addr <= ADDR3;
                    write_en <= 1;
                    write_addr <= ADDR3;
                    write_data <= DATA4;
                end

                // skip 10
                11:
                begin
                    // Here's where we see the difference in behavior with the
                    // READ_DURING_WRITE parameter. The second memory is "don't care",
                    // which, in the simulator implementation, returns a random number.
                    assert(read_data1 == DATA4);
                    assert(read_data2 != DATA4);

                    // Read back the address to ensure it was still written correctly.
                    read_en <= 1;
                    read_addr <= ADDR3;
                end

                // skip 12
                13:
                begin
                    assert(read_data1 == DATA4);
                    assert(read_data2 == DATA4);
                end

                14:
                begin
                    // read_en is not asserted. Ensure it is not the previous value.
                    // (the sim versions of memories explicitly randomize outputs if
                    // the read_en isn't asserted to catch logic that is not respecting
                    // the semantic).
                    assert(read_data1 != DATA4);
                    assert(read_data2 != DATA4);

                    $display("PASS");
                    $finish;
                end
            endcase
        end
    end
endmodule
