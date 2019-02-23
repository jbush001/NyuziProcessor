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
// SRAM with an AXI interface and external loader interface
//
module axi_sram
    #(parameter MEM_SIZE = 'h40000) // Number of 32-bit words

    (input                      clk,
    input                       reset,

    // AXI interface
    axi4_interface.slave        axi_bus,

    // External loader interface. It is valid to access these when the
    // part is in reset; the reset signal only applies to the AXI state machine.
    input                       loader_we,
    input[31:0]                 loader_addr,
    input[31:0]                 loader_data);

    typedef enum {
        STATE_IDLE,
        STATE_READ_BURST,
        STATE_WRITE_BURST,
        STATE_WRITE_ACK
    } axi_state_t;

    logic[31:0] burst_address;
    logic[31:0] burst_address_nxt;
    logic[7:0] burst_count;
    logic[7:0] burst_count_nxt;
    axi_state_t state;
    axi_state_t state_nxt;
    logic do_read;
    logic do_write;
    logic[31:0] wr_addr;
    logic[31:0] wr_data;

    localparam SRAM_ADDR_WIDTH = $clog2(MEM_SIZE);

    always_comb
    begin
        if (loader_we)
        begin
            wr_addr = 32'(loader_addr[31:2]);
            wr_data = loader_data;
        end
        else // do write
        begin
            wr_addr = burst_address;
            wr_data = axi_bus.m_wdata;
        end
    end

    sram_1r1w #(.SIZE(MEM_SIZE), .DATA_WIDTH(32)) memory(
        .clk(clk),
        .read_en(do_read),
        .read_addr(burst_address_nxt[SRAM_ADDR_WIDTH - 1:0]),
        .read_data(axi_bus.s_rdata),
        .write_en(loader_we || do_write),
        .write_addr(wr_addr[SRAM_ADDR_WIDTH - 1:0]),
        .write_data(wr_data));

    assign axi_bus.s_awready = axi_bus.s_arready;

    // Drive external bus signals
    always_comb
    begin
        axi_bus.s_rvalid = 0;
        axi_bus.s_wready = 0;
        axi_bus.s_bvalid = 0;
        axi_bus.s_arready = 0;
        case (state)
            STATE_IDLE:        axi_bus.s_arready = 1;    // and s_awready
            STATE_READ_BURST:  axi_bus.s_rvalid = 1;
            STATE_WRITE_BURST: axi_bus.s_wready = 1;
            STATE_WRITE_ACK:   axi_bus.s_bvalid = 1;
        endcase
    end

    // Next state logic
    always_comb
    begin
        do_read = 0;
        do_write = 0;
        burst_address_nxt = burst_address;
        burst_count_nxt = burst_count;
        state_nxt = state;

        unique case (state)
            STATE_IDLE:
            begin
                // I've cheated here.  It's legal per the spec for s_arready/s_awready to go low
                // but not if m_arvalid/m_awvalid are already asserted (respectively), because
                // the client would assume the transfer completed (AMBA AXI and ACE protocol
                // spec rev E A3.2.1: "If READY is asserted, it is permitted to deassert READY
                // before VALID is asserted.")  I know that the client never asserts both
                // simultaneously, so I don't bother latching addresses separately.
                if (axi_bus.m_awvalid)
                begin
                    burst_address_nxt = 32'(axi_bus.m_awaddr[31:2]);
                    burst_count_nxt = axi_bus.m_awlen;
                    state_nxt = STATE_WRITE_BURST;
                end
                else if (axi_bus.m_arvalid)
                begin
                    do_read = 1;
                    burst_address_nxt = 32'(axi_bus.m_araddr[31:2]);
                    burst_count_nxt = axi_bus.m_arlen;
                    state_nxt = STATE_READ_BURST;
                end
            end

            STATE_READ_BURST:
            begin
                if (axi_bus.m_rready)
                begin
                    if (burst_count == 0)
                        state_nxt = STATE_IDLE;
                    else
                    begin
                        burst_address_nxt = burst_address + 1;
                        burst_count_nxt = burst_count - 1;
                        do_read = 1;
                    end
                end
            end

            STATE_WRITE_BURST:
            begin
                if (axi_bus.m_wvalid)
                begin
                    do_write = 1;
                    if (burst_count == 0)
                        state_nxt = STATE_WRITE_ACK;
                    else
                    begin
                        burst_address_nxt = burst_address + 1;
                        burst_count_nxt = burst_count - 1;
                    end
                end
            end

            STATE_WRITE_ACK:
            begin
                if (axi_bus.m_bready)
                    state_nxt = STATE_IDLE;
            end

            default:
                state_nxt = STATE_IDLE;
        endcase
    end

    always_ff @(posedge clk, posedge reset)
    begin
        if (reset)
        begin
            state <= STATE_IDLE;
            /*AUTORESET*/
            // Beginning of autoreset for uninitialized flops
            burst_address <= '0;
            burst_count <= '0;
            // End of automatics
        end
        else
        begin
`ifdef SIMULATION
            if (burst_address > MEM_SIZE)
            begin
                // Note that this isn't necessarily indicative of a hardware bug:
                // it could just be a bad memory address produced by software.
                $display("L2 cache accessed invalid address %x", burst_address);
                $finish;
            end
`endif

            burst_address <= burst_address_nxt;
            burst_count <= burst_count_nxt;
            state <= state_nxt;
        end
    end
endmodule
