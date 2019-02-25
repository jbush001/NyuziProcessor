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
// Drive VGA display.  This is an AXI master that DMAs color
// data from a memory framebuffer and sends it to an ADV7123 VGA
// DAC with timing signals.
//

module vga_controller
    #(parameter BASE_ADDRESS = 0)
    (input                      clk,
    input                       reset,

    // I/O bus control register access
    io_bus_interface.slave      io_bus,
    output logic                frame_interrupt,

    // DMA access to memory
    axi4_interface.master       axi_bus,

    // To DAC
    output [7:0]                vga_r,
    output [7:0]                vga_g,
    output [7:0]                vga_b,
    output logic                vga_clk,
    output logic                vga_blank_n,
    output logic                vga_hs,
    output logic                vga_vs,
    output logic                vga_sync_n);

    // The burst length is twice that of a CPU cache line fill to ensure
    // sufficient memory bandwidth even when ping-ponging.
    localparam BURST_LENGTH = 64;
    localparam PIXEL_FIFO_LENGTH = 128;

    typedef enum {
        STATE_WAIT_FRAME_START,
        STATE_WAIT_FIFO_SPACE,
        STATE_ISSUE_ADDR,
        STATE_BURST_ACTIVE
    } dma_state_t;

    /*AUTOLOGIC*/
    // Beginning of automatic wires (for undeclared instantiated-module outputs)
    logic               in_visible_region;      // From vga_sequencer of vga_sequencer.v
    logic               pixel_en;               // From vga_sequencer of vga_sequencer.v
    logic               start_frame;            // From vga_sequencer of vga_sequencer.v
    // End of automatics
    logic[31:0] vram_addr;
    logic[7:0] _ignore_alpha;
    logic pixel_fifo_empty;
    logic pixel_fifo_almost_empty;
    logic[31:0] fb_base_address;
    logic[31:0] fb_length;
    dma_state_t axi_state;
    logic[7:0] burst_count;
    logic[18:0] pixel_count;
    logic sequencer_en;

    assign frame_interrupt = start_frame;
    assign vga_blank_n = in_visible_region;
    assign vga_sync_n = 1'b0;    // Not used
    assign vga_clk = pixel_en;    // This is a bid odd: using enable as external clock.

    // Buffer data to the display from SDRAM. The enqueue threshold is large
    // enough to enqueue an entire burst from memory. Empty the FIFO at the
    // beginning of the vblank period so it will resynchronize if there was
    // an underrun.
    sync_fifo #(
        .WIDTH(24),
        .SIZE(PIXEL_FIFO_LENGTH),
        .ALMOST_EMPTY_THRESHOLD(PIXEL_FIFO_LENGTH - BURST_LENGTH - 1)) pixel_fifo(
        .clk(clk),
        .reset(reset),
        .flush_en(start_frame),
        .almost_full(),
        .empty(pixel_fifo_empty),
        .almost_empty(pixel_fifo_almost_empty),
        .dequeue_value({vga_r, vga_g, vga_b}),
        .enqueue_value(axi_bus.s_rdata[31:8]),
        .enqueue_en(axi_bus.s_rvalid),
        .full(),
        .dequeue_en(pixel_en && in_visible_region && !pixel_fifo_empty));

    // DMA state machine
    always_ff @(posedge clk, posedge reset)
    begin
        if (reset)
        begin
            vram_addr <= '0;
            axi_state <= STATE_WAIT_FRAME_START;

            /*AUTORESET*/
            // Beginning of autoreset for uninitialized flops
            burst_count <= '0;
            pixel_count <= '0;
            // End of automatics
        end
        else
        begin
            // Check for FIFO underrun
            assert(!(pixel_en && in_visible_region && pixel_fifo_empty));

            unique case (axi_state)
                // This state exists so this will automatically resynchronize in the event
                // of a FIFO underrun. At the beginning of the vblank interval,
                // simultaneously clear the FIFO and start the first DMA transaction.
                STATE_WAIT_FRAME_START:
                begin
                    if (start_frame && sequencer_en)
                    begin
                        // Ensure there is no data left in the FIFO (which
                        // would imply we fetched too much)
                        assert(pixel_fifo_empty);

                        axi_state <= STATE_ISSUE_ADDR;
                        pixel_count <= 0;
                        vram_addr <= fb_base_address;
                    end
                end

                // Wait until there is enough free space in the FIFO to accept
                // an entire burst from memory.
                STATE_WAIT_FIFO_SPACE:
                begin
                    if (pixel_fifo_almost_empty)
                        axi_state <= STATE_ISSUE_ADDR;
                end

                STATE_ISSUE_ADDR:
                begin
                    if (axi_bus.s_arready)
                        axi_state <= STATE_BURST_ACTIVE;
                end

                STATE_BURST_ACTIVE:
                begin
                    if (axi_bus.s_rvalid)
                    begin
                        if (burst_count == BURST_LENGTH - 1)
                        begin
                            // Burst complete
                            burst_count <= 0;
                            if (pixel_count == 19'(fb_length - BURST_LENGTH))
                            begin
                                // Frame complete
                                axi_state <= STATE_WAIT_FRAME_START;
                            end
                            else
                            begin
                                if (!sequencer_en)
                                    axi_state <= STATE_WAIT_FRAME_START; // Abort frame
                                else if (pixel_fifo_almost_empty)
                                    axi_state <= STATE_ISSUE_ADDR;
                                else
                                    axi_state <= STATE_WAIT_FIFO_SPACE;

                                vram_addr <= vram_addr + BURST_LENGTH * 4;
                                pixel_count <= pixel_count + 19'(BURST_LENGTH);
                            end
                        end
                        else
                            burst_count <= burst_count + 8'd1;
                    end
                end

                default: axi_state <= STATE_WAIT_FRAME_START;
            endcase
        end
    end

    assign axi_bus.m_rready = 1'b1;    // The request is only made when there is enough room.
    assign axi_bus.m_arlen = 8'(BURST_LENGTH - 1);
    assign axi_bus.m_arvalid = axi_state == STATE_ISSUE_ADDR;
    assign axi_bus.m_araddr = vram_addr;
    assign axi_bus.m_awaddr = '0;
    assign axi_bus.m_awlen = '0;

    // Write channels not used.
    assign axi_bus.m_wdata = '0;
    assign axi_bus.m_awvalid = '0;
    assign axi_bus.m_wlast = 0;
    assign axi_bus.m_wvalid = 0;
    assign axi_bus.m_bready = 0;

    always_ff @(posedge clk, posedge reset)
    begin
        if (reset)
        begin
            sequencer_en <= 0;
            fb_base_address <= '0;
            fb_length <= '0;
        end
        else if (io_bus.write_en)
        begin
            case (io_bus.address)
                BASE_ADDRESS: sequencer_en <= io_bus.write_data[0];
                BASE_ADDRESS + 8: fb_base_address <= io_bus.write_data;
                BASE_ADDRESS + 12: fb_length <= io_bus.write_data;
            endcase
        end
    end

    assign io_bus.read_data = '0;

    vga_sequencer vga_sequencer(
        .prog_write_en(io_bus.write_en && io_bus.address == BASE_ADDRESS + 4),
        .prog_data(io_bus.write_data),
        .*);
endmodule
