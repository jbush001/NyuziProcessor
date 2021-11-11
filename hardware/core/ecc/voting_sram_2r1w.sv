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

//
// Block SRAM with 2 read ports and 1 write port.
// Reads and writes are performed synchronously. The read value appears
// on the next clock edge after the address and readx_en are asserted
// If readx_en is not asserted, the value of readx_data is undefined during
// the next cycle. The READ_DURING_WRITE parameter determines what happens
// if a read and a write are performed to the same address in the same cycle:
//  - "NEW_DATA" this will return the newly written data ("read-after-write").
//  - "DONT_CARE" The results are undefined. This can be used to improve clock
//    speed.
// This does not clear memory contents on reset.
//

// ECC Extension (ONLY SIMULATION)
// This module thoes all the above and adds 2 more srams in order to vote for the
// resultall the above and adds 2 more srams in order to vote for the
// result. If one srams gives an incorrect result, its value is corrected.

module sram_2r1w
    #(parameter DATA_WIDTH = 32,
    parameter SIZE = 1024,
    parameter READ_DURING_WRITE = "NEW_DATA",
    parameter ADDR_WIDTH = $clog2(SIZE))

    (input                           clk,
    input                            read1_en,
    input [ADDR_WIDTH - 1:0]         read1_addr,
    output logic[DATA_WIDTH - 1:0]   read1_data,
    input                            read2_en,
    input [ADDR_WIDTH - 1:0]         read2_addr,
    output logic[DATA_WIDTH - 1:0]   read2_data,
    input                            write_en,
    input [ADDR_WIDTH - 1:0]         write_addr,
    input [DATA_WIDTH - 1:0]         write_data);

`ifdef VENDOR_ALTERA
    VENDOR_ALTERA_IS_NOT_SUPPORTED
`elsif VENDOR_XILINX
    VENDOR_XILINX_IS_NOT_SUPPORTED
`elsif MEMORY_COMPILER
    MEMORY_COMPILER_IS_NOT_SUPPORTED
`else
    // Simulation
    logic[DATA_WIDTH - 1:0] data_0[SIZE];
    logic[DATA_WIDTH - 1:0] data_1[SIZE];
    logic[DATA_WIDTH - 1:0] data_2[SIZE];
    logic voting_mismatch;
    logic [1:0] voting_mismatch_addr;
    logic [DATA_WIDTH-1:0] voting_data;

    // Do the voting when a read takes place
    always_comb begin
        logic [DATA_WIDTH-1:0] read_data_0, read_data_1, read_data_2;
        if (read1_en) begin
            read_data_0 = data_0[read1_addr];
            read_data_1 = data_1[read1_addr];
            read_data_2 = data_2[read1_addr];

            if ((read_data_0 != read_data_1) || (read_data_0 != read_data_2) || (read_data_1 != read_data_2)) begin
                voting_mismatch = 1'b1;
                if (read_data_0 == read_data_1) begin
                    voting_mismatch_addr = 2'd2;
                    voting_data = read_data_0;
                end
                else if (read_data_0 == read_data_2) begin
                    voting_mismatch_addr = 2'd1;
                    voting_data = read_data_0;
                end
                else begin
                    voting_mismatch_addr = 2'd0;
                    voting_data = read_data_1;
                end
            end
            else
                voting_data = read_data_0;
        end
        if (read2_en) begin
        end
    end

    // Note: use always here instead of always_ff so Modelsim will allow
    // initializing the array in the initial block (see below).
    always @(posedge clk)
    begin
        if (write_en) begin
            data_0[write_addr] <= write_data;
            data_1[write_addr] <= write_data;
            data_2[write_addr] <= write_data;
        end

        if (write_addr == read1_addr && write_en && read1_en)
        begin
            if (READ_DURING_WRITE == "NEW_DATA")
                read1_data <= write_data;    // Bypass
            else
                read1_data <= DATA_WIDTH'($random()); // ensure it is really "don't care"
        end
        else if (read1_en) begin
            read1_data <= data[read1_addr];
        end
        else
            read1_data <= DATA_WIDTH'($random());

        if (write_addr == read2_addr && write_en && read2_en)
        begin
            if (READ_DURING_WRITE == "NEW_DATA")
                read2_data <= write_data;    // Bypass
            else
                read2_data <= DATA_WIDTH'($random());
        end
        else if (read2_en)
            read2_data <= data[read2_addr];
        else
            read2_data <= DATA_WIDTH'($random());
    end

    initial
    begin
`ifndef VERILATOR
        // Initialize RAM with random values. This is unneeded on Verilator
        // (which already does randomizes memory), but is necessary on
        // 4-state simulators because memory is initially filled with Xs.
        // This was causing x-propagation bugs in some modules previously.
        for (int i = 0; i < SIZE; i++)
            data[i] = DATA_WIDTH'($random());
`endif

        if ($test$plusargs("dumpmems") != 0)
            $display("sram2r1w %d %d", DATA_WIDTH, SIZE);
    end
`endif
endmodule
