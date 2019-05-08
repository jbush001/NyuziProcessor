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
    logic[DATA_WIDTH - 1:0] data_from_ram1;
    logic[DATA_WIDTH - 1:0] data_from_ram2;

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
        .rden_b(read1_en),
        .address_b(read1_addr),
        .q_b(data_from_ram1));

    ALTSYNCRAM #(
        .OPERATION_MODE("DUAL_PORT"),
        .WIDTH_A(DATA_WIDTH),
        .WIDTHAD_A(ADDR_WIDTH),
        .WIDTH_B(DATA_WIDTH),
        .WIDTHAD_B(ADDR_WIDTH),
        .READ_DURING_WRITE_MIXED_PORTS("DONT_CARE")
    ) data1(
        .clock0(clk),
        .clock1(clk),

        // Write port
        .wren_a(write_en),
        .address_a(write_addr),
        .data_a(write_data),
        .q_a(),

        // Read port
        .rden_b(read2_en),
        .address_b(read2_addr),
        .q_b(data_from_ram2));

    generate
        if (READ_DURING_WRITE == "NEW_DATA")
        begin
            logic pass_thru1_en;
            logic pass_thru2_en;
            logic[DATA_WIDTH - 1:0] pass_thru_data;

            always_ff @(posedge clk)
            begin
                pass_thru1_en <= write_en && read1_en && read1_addr == write_addr;
                pass_thru2_en <= write_en && read2_en && read2_addr == write_addr;
                pass_thru_data <= write_data;
            end

            assign read1_data = pass_thru1_en ? pass_thru_data : data_from_ram1;
            assign read2_data = pass_thru2_en ? pass_thru_data : data_from_ram2;
        end
        else
        begin
            assign read1_data = data_from_ram1;
            assign read2_data = data_from_ram2;
        end
    endgenerate
`elsif VENDOR_XILINX
    // If you get an error [Synth 8-439] module 'xpm_memory_sdpram' not found,
    // you must set the property XPM_LIBRARIES on the project.
    // https://www.xilinx.com/support/answers/67815.html

    localparam XPM_MEM_SIZE = (1 << ADDR_WIDTH) * DATA_WIDTH; // Memory size in bits

    logic[DATA_WIDTH - 1:0] data_from_ram1;
    logic[DATA_WIDTH - 1:0] data_from_ram2;

    xpm_memory_sdpram # (
        .MEMORY_SIZE        (XPM_MEM_SIZE),    // Size in bits
        .MEMORY_PRIMITIVE   ("auto"),          // Left Vivado choosing
        .CLOCKING_MODE      ("common_clock"),  // Clock both port A and port B with clka
        .MEMORY_INIT_FILE   ("none"),
        .MEMORY_INIT_PARAM  (""    ),
        .USE_MEM_INIT       (0),               // No init
        .WAKEUP_TIME        ("disable_sleep"), // Dynamic power saving Disabled
        .MESSAGE_CONTROL    (0),               // Dynamic message reporting Disabled
        .ECC_MODE           ("no_ecc"),        // No ECC
        .AUTO_SLEEP_TIME    (0),               // Reserved

        // Port A module parameters
        .WRITE_DATA_WIDTH_A (DATA_WIDTH),
        .BYTE_WRITE_WIDTH_A (DATA_WIDTH),
        .ADDR_WIDTH_A       (ADDR_WIDTH),

        // Port B module parameters
        .READ_DATA_WIDTH_B  (DATA_WIDTH),
        .ADDR_WIDTH_B       (ADDR_WIDTH),
        .READ_RESET_VALUE_B ("0"),
        .READ_LATENCY_B     (1),               // Read data output to port doutb takes 1 clk
        .WRITE_MODE_B       ("read_first")     // Seems to be the best choice according to ug974
    ) data0 (
        .sleep          (1'b0),

        // Port A module ports
        .clka           (clk),
        .ena            (write_en),
        .wea            (write_en),
        .addra          (write_addr),
        .dina           (write_data),
        .injectsbiterra (1'b0),
        .injectdbiterra (1'b0),

        // Port B module ports
        .clkb           (clk),
        .rstb           (1'b0),
        .enb            (read1_en),
        .regceb         (1'b1),
        .addrb          (read1_addr),
        .doutb          (data_from_ram1),
        .sbiterrb       (),
        .dbiterrb       ()
    );

    xpm_memory_sdpram # (
        .MEMORY_SIZE        (XPM_MEM_SIZE),
        .MEMORY_PRIMITIVE   ("auto"),
        .CLOCKING_MODE      ("common_clock"),
        .MEMORY_INIT_FILE   ("none"),
        .MEMORY_INIT_PARAM  (""    ),
        .USE_MEM_INIT       (0),
        .WAKEUP_TIME        ("disable_sleep"),
        .MESSAGE_CONTROL    (0),
        .ECC_MODE           ("no_ecc"),
        .AUTO_SLEEP_TIME    (0),

        // Port A module parameters
        .WRITE_DATA_WIDTH_A (DATA_WIDTH),
        .BYTE_WRITE_WIDTH_A (DATA_WIDTH),
        .ADDR_WIDTH_A       (ADDR_WIDTH),

        // Port B module parameters
        .READ_DATA_WIDTH_B  (DATA_WIDTH),
        .ADDR_WIDTH_B       (ADDR_WIDTH),
        .READ_RESET_VALUE_B ("0"),
        .READ_LATENCY_B     (1),
        .WRITE_MODE_B       ("read_first")
    ) data1 (
        .sleep          (1'b0),

        // Port A module ports
        .clka           (clk),
        .ena            (write_en),
        .wea            (write_en),
        .addra          (write_addr),
        .dina           (write_data),
        .injectsbiterra (1'b0),
        .injectdbiterra (1'b0),

        // Port B module ports
        .clkb           (clk),
        .rstb           (1'b0),
        .enb            (read2_en),
        .regceb         (1'b1),
        .addrb          (read2_addr),
        .doutb          (data_from_ram2),
        .sbiterrb       (),
        .dbiterrb       ()
    );

    generate
        if (READ_DURING_WRITE == "NEW_DATA") begin
            logic pass_thru1_en;
            logic pass_thru2_en;
            logic[DATA_WIDTH - 1:0] pass_thru_data;

            always_ff @(posedge clk) begin
                pass_thru1_en <= write_en && read1_en && read1_addr == write_addr;
                pass_thru2_en <= write_en && read2_en && read2_addr == write_addr;
                pass_thru_data <= write_data;
            end

            assign read1_data = pass_thru1_en ? pass_thru_data : data_from_ram1;
            assign read2_data = pass_thru2_en ? pass_thru_data : data_from_ram2;
        end else begin
            assign read1_data = data_from_ram1;
            assign read2_data = data_from_ram2;
        end
    endgenerate
`elsif MEMORY_COMPILER
    generate
        `define _GENERATE_SRAM2R1W
        `include "srams.inc"
        `undef     _GENERATE_SRAM2R1W
    endgenerate
`else
    // Simulation
    logic[DATA_WIDTH - 1:0] data[SIZE];

    // Note: use always here instead of always_ff so Modelsim will allow
    // initializing the array in the initial block (see below).
    always @(posedge clk)
    begin
        if (write_en)
            data[write_addr] <= write_data;

        if (write_addr == read1_addr && write_en && read1_en)
        begin
            if (READ_DURING_WRITE == "NEW_DATA")
                read1_data <= write_data;    // Bypass
            else
                read1_data <= DATA_WIDTH'($random()); // ensure it is really "don't care"
        end
        else if (read1_en)
            read1_data <= data[read1_addr];
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
