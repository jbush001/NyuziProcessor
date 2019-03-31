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

module de2_115_top(
    input                       clk50,

    // Buttons
    input                       reset_btn,    // KEY[0]

    // Der blinkenlights
    output logic[17:0]          red_led,
    output logic[8:0]           green_led,
    output logic[6:0]           hex0,
    output logic[6:0]           hex1,
    output logic[6:0]           hex2,
    output logic[6:0]           hex3,

    // UART
    output                      uart_tx,
    input                       uart_rx,

    // SDRAM
    output                      dram_clk,
    output                      dram_cke,
    output                      dram_cs_n,
    output                      dram_ras_n,
    output                      dram_cas_n,
    output                      dram_we_n,
    output [1:0]                dram_ba,
    output [12:0]               dram_addr,
    output [3:0]                dram_dqm,
    inout [31:0]                dram_dq,

    // VGA
    output [7:0]                vga_r,
    output [7:0]                vga_g,
    output [7:0]                vga_b,
    output                      vga_clk,
    output                      vga_blank_n,
    output                      vga_hs,
    output                      vga_vs,
    output                      vga_sync_n,

    // SD card
    output                      sd_clk,
    input                       sd_do,
    output                      sd_di,
    output                      sd_cs,

    // PS/2
    input                       ps2_clk,
    input                       ps2_data);

    parameter  bootrom = "../../../software/bootrom/boot.hex";

    localparam BOOT_ROM_BASE = 32'hfffee000;
    localparam NUM_PERIPHERALS = 5;

    /*AUTOLOGIC*/
    // Beginning of automatic wires (for undeclared instantiated-module outputs)
    logic               frame_interrupt;        // From vga_controller of vga_controller.v
    logic               perf_dram_page_hit;     // From sdram_controller of sdram_controller.v
    logic               perf_dram_page_miss;    // From sdram_controller of sdram_controller.v
    logic               timer_interrupt;        // From timer of timer.v
    // End of automatics

    axi4_interface axi_bus_s[1:0]();
    axi4_interface axi_bus_m[1:0]();
    logic reset;
    logic clk;
    scalar_t peripheral_read_data[NUM_PERIPHERALS];
    io_bus_interface peripheral_io_bus[NUM_PERIPHERALS - 1:0]();
    io_bus_interface nyuzi_io_bus();
    jtag_interface jtag();
    enum logic[$clog2(NUM_PERIPHERALS) - 1:0] {
        IO_UART,
        IO_SDCARD,
        IO_PS2,
        IO_VGA,
        IO_TIMER
    } io_bus_source;
    logic uart_rx_interrupt;
    logic ps2_rx_interrupt;
    logic virt_tdo;
    logic virt_tck;
    logic virt_tdi;
    logic virt_data_reg;
    /* verilator lint_off UNDRIVEN */
    logic virt_reset;
    /* verilator lint_on UNDRIVEN */

    assign clk = clk50;

    nyuzi #(.RESET_PC(BOOT_ROM_BASE)) nyuzi(
        .interrupt_req({11'd0,
            frame_interrupt,
            ps2_rx_interrupt,
            uart_rx_interrupt,
            timer_interrupt,
            1'b0}),
        .axi_bus(axi_bus_m[0]),
        .io_bus(nyuzi_io_bus),
        .jtag(jtag),
        .*);

    axi_interconnect #(.M1_BASE_ADDRESS(BOOT_ROM_BASE)) axi_interconnect(
        .axi_bus_s(axi_bus_s),
        .axi_bus_m(axi_bus_m),
        .*);

    // Synchronize from two asynchronous sources, reset_btn is the
    // pushbutton on the dev board (which goes low when pressed),
    // and virt_reset comes from the virtual JTAG.
    synchronizer reset_synchronizer(
        .clk(clk),
        .reset(0),
        .data_o(reset),
        .data_i(!reset_btn || virt_reset));

    // Boot ROM.  Execution starts here. The boot ROM path is relative
    // to the directory that the synthesis tool is invoked from (this
    // directory).
    axi_rom #(.FILENAME(bootrom)) boot_rom(
        .axi_bus(axi_bus_s[1]),
        .*);

    sdram_controller #(
        .DATA_WIDTH(32),
        .ROW_ADDR_WIDTH(13),
        .COL_ADDR_WIDTH(10),

        // 50 Mhz = 20ns clock.  Each value is clocks of delay minus one.
        // Timing values based on datasheet for A3V64S40ETP SDRAM parts
        // on the DE2-115 board.
        .T_REFRESH(390),            // 64 ms / 8192 rows = 7.8125 uS
        .T_POWERUP(10000),          // 200 us
        .T_ROW_PRECHARGE(1),        // 21 ns
        .T_AUTO_REFRESH_CYCLE(3),   // 75 ns
        .T_RAS_CAS_DELAY(1),        // 21 ns
        .T_CAS_LATENCY(1)           // 21 ns (2 cycles)
    ) sdram_controller(
        .axi_bus(axi_bus_s[0]),
        .*);

    // We always access the full word width, so hard code these to active (low)
    assign dram_dqm = 4'b0000;

    vga_controller #(.BASE_ADDRESS('h180)) vga_controller(
        .io_bus(peripheral_io_bus[IO_VGA]),
        .axi_bus(axi_bus_m[1]),
        .*);

`ifdef WITH_LOGIC_ANALYZER
    logic[87:0] capture_data;
    logic capture_enable;
    logic trigger;
    logic[31:0] event_count;

    assign capture_data = { perf_dram_page_hit };
    assign capture_enable = 1;
    assign trigger = event_count == 120;

    logic_analyzer #(.CAPTURE_WIDTH_BITS($bits(capture_data)),
        .CAPTURE_SIZE(128)) logic_analyzer(.*);

    always_ff @(posedge clk, posedge reset)
    begin
        if (reset)
            event_count <= 0;
        else if (capture_enable)
            event_count <= event_count + 1;
    end
`else
    uart #(.BASE_ADDRESS('h40)) uart(
        .io_bus(peripheral_io_bus[IO_UART]),
        .rx_interrupt(uart_rx_interrupt),
        .*);
`endif

    spi_controller #(.BASE_ADDRESS('hc0)) spi_controller(
        .io_bus(peripheral_io_bus[IO_SDCARD]),
        .spi_clk(sd_clk),
        .spi_cs_n(sd_cs),
        .spi_miso(sd_do),
        .spi_mosi(sd_di),
        .*);

    ps2_controller #(.BASE_ADDRESS('h80)) ps2_controller(
        .io_bus(peripheral_io_bus[IO_PS2]),
        .rx_interrupt(ps2_rx_interrupt),
        .*);

    timer #(.BASE_ADDRESS('h240)) timer(
        .io_bus(peripheral_io_bus[IO_TIMER]),
        .*);

    always_ff @(posedge clk, posedge reset)
    begin
        if (reset)
        begin
            red_led <= 0;
            green_led <= 0;
            hex0 <= 7'b1111111;
            hex1 <= 7'b1111111;
            hex2 <= 7'b1111111;
            hex3 <= 7'b1111111;
        end
        else
        begin
            if (nyuzi_io_bus.write_en)
            begin
                case (nyuzi_io_bus.address)
                    'h00: red_led <= nyuzi_io_bus.write_data[17:0];
                    'h04: green_led <= nyuzi_io_bus.write_data[8:0];
                    'h08: hex0 <= nyuzi_io_bus.write_data[6:0];
                    'h0c: hex1 <= nyuzi_io_bus.write_data[6:0];
                    'h10: hex2 <= nyuzi_io_bus.write_data[6:0];
                    'h14: hex3 <= nyuzi_io_bus.write_data[6:0];
                endcase
            end

            casez (nyuzi_io_bus.address)
                'h4?: io_bus_source <= IO_UART;
                'hc?: io_bus_source <= IO_SDCARD;
                'h8?: io_bus_source <= IO_PS2;
                default: io_bus_source <= IO_UART;
            endcase
        end
    end

    assign nyuzi_io_bus.read_data = peripheral_read_data[io_bus_source];

    genvar io_idx;
    generate
        for (io_idx = 0; io_idx < NUM_PERIPHERALS; io_idx++)
        begin : io_gen
            assign peripheral_io_bus[io_idx].write_en = nyuzi_io_bus.write_en;
            assign peripheral_io_bus[io_idx].read_en = nyuzi_io_bus.read_en;
            assign peripheral_io_bus[io_idx].address = nyuzi_io_bus.address;
            assign peripheral_io_bus[io_idx].write_data = nyuzi_io_bus.write_data;
            assign peripheral_read_data[io_idx] = peripheral_io_bus[io_idx].read_data;
        end
    endgenerate

    assign jtag.tck = 0;
    assign jtag.tdi = 0;
    assign jtag.tms = 0;
    assign jtag.trst_n = 0;

// It's a little weird to have this in a VENDOR_ALTERA ifdef, since this file
// is Altera specific, but this is done so Verilator can still run a lint pass
// on this file to check for errors in CI.
`ifdef VENDOR_ALTERA
    //
    // This virtual JTAG block is independent of the JTAG OCD interface on Nyuzi.
    // It's used only to be able to reset the processor from the test harness.
    // It only has one data register, with one bit, which contains the reset
    // state.
    //
    sld_virtual_jtag #(
        .sld_auto_instance_index("NO"),
        .sld_instance_index(0),
        .sld_ir_width(4)
    ) virtual_jtag(
        .tck(virt_tck),
        .tdi(virt_tdi),
        .tdo(virt_data_reg),
        .virtual_state_sdr(virt_sdr),   // Shift data register
        .virtual_state_udr(virt_udr)    // Update data register
    );

    always @(posedge virt_tck)
    begin
        if (virt_sdr)
            virt_data_reg <= virt_tdi;
        else if (virt_udr)
            virt_reset <= virt_data_reg;
    end
`endif
endmodule
