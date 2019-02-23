//
// Copyright 2019 Jeff Bush
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

// Ensure AXI protocol transactions conform to the specification.
// This primarily validates the master. It assumes only one transaction
// is outstanding.
module axi_protocol_checker(
    input                       clk,
    input                       reset,
    axi4_interface.slave        axi_bus);

    typedef enum int {
        IDLE,
        ADDRESS_ASSERTED,
        ADDRESS_ACCEPTED,
        RESPONSE
    } burst_state_t;

    // Write checks
    burst_state_t write_burst_state;
    logic[AXI_ADDR_WIDTH - 1:0] awaddr;
    defines::axi_burst_type_t awburst;
    logic [7:0] awlen;
    logic [2:0] awsize;
    int write_count;

    always @(posedge clk, posedge reset)
    begin
        if (reset)
            write_burst_state <= IDLE;
        else
        begin
            case (write_burst_state)
                IDLE:
                begin
                    if (axi_bus.m_awvalid)
                    begin
                        awaddr <= axi_bus.m_awaddr;
                        awburst <= axi_bus.m_awburst;
                        awlen <= axi_bus.m_awlen;
                        awsize <= axi_bus.m_awsize;
                        assert(!axi_bus.m_wvalid);

                        // Ensure this transaction doesn't cross a 4k boundary
                        assert ((int'(axi_bus.m_awaddr) / 4096) ==
                            ((int'(axi_bus.m_awaddr) + int'(axi_bus.m_awlen) * 4) / 4096));

                        write_count <= 0;
                        if (axi_bus.s_awready)
                            write_burst_state <= ADDRESS_ACCEPTED;
                        else
                            write_burst_state <= ADDRESS_ASSERTED;
                    end
                end

                ADDRESS_ASSERTED:
                begin
                    // Ensure signals are stable until accepted.
                    assert(axi_bus.m_awaddr === awaddr);
                    assert(axi_bus.m_awburst === awburst);
                    assert(axi_bus.m_awlen === awlen);
                    assert(axi_bus.m_awsize == awsize);
                    assert(axi_bus.m_awvalid);
                    assert(!axi_bus.m_wvalid);
                    if (axi_bus.s_awready)
                        write_burst_state <= ADDRESS_ACCEPTED;
                end

                ADDRESS_ACCEPTED:
                begin
                    if (axi_bus.m_wvalid && axi_bus.s_wready)
                    begin
                        assert(write_count <= int'(awlen));
                        assert(axi_bus.m_wlast === (write_count == int'(awlen)));
                        assert(!axi_bus.m_awvalid);
                        write_count <= write_count + 1;
                        if (write_count == int'(awlen))
                            write_burst_state <= RESPONSE;
                    end
                end

                RESPONSE:
                begin
                    assert(!axi_bus.m_awvalid);
                    assert(!axi_bus.m_wvalid);
                    if (axi_bus.m_bready && axi_bus.s_bvalid)
                        write_burst_state <= IDLE;
                end
            endcase
        end
    end

    // Read checks
    burst_state_t read_burst_state;
    logic[AXI_ADDR_WIDTH - 1:0] araddr;
    defines::axi_burst_type_t arburst;
    logic [7:0] arlen;
    logic [2:0] arsize;
    int read_count;

    always @(posedge clk, posedge reset)
    begin
        if (reset)
            read_burst_state <= IDLE;
        else
        begin
            case (read_burst_state)
                IDLE:
                begin
                    if (axi_bus.m_arvalid)
                    begin
                        araddr <= axi_bus.m_araddr;
                        arburst <= axi_bus.m_arburst;
                        arlen <= axi_bus.m_arlen;
                        arsize <= axi_bus.m_arsize;

                        // Ensure this transaction doesn't cross a 4k boundary
                        assert ((int'(axi_bus.m_araddr) / 4096) ==
                            ((int'(axi_bus.m_araddr) + int'(axi_bus.m_arlen) * 4) / 4096));

                        read_count <= 0;
                        if (axi_bus.s_arready)
                            read_burst_state <= ADDRESS_ACCEPTED;
                        else
                            read_burst_state <= ADDRESS_ASSERTED;
                    end
                end

                ADDRESS_ASSERTED:
                begin
                    // Ensure signals are stable.
                    assert(axi_bus.m_araddr === araddr);
                    assert(axi_bus.m_arburst === arburst);
                    assert(axi_bus.m_arlen === arlen);
                    assert(axi_bus.m_arsize == arsize);
                    assert(axi_bus.m_arvalid);
                    if (axi_bus.s_arready)
                        read_burst_state <= ADDRESS_ACCEPTED;
                end

                ADDRESS_ACCEPTED:
                begin
                    if (axi_bus.s_rvalid && axi_bus.m_rready)
                    begin
                        assert(read_count <= int'(arlen));
                        assert(!axi_bus.m_arvalid);
                        read_count <= read_count + 1;
                        if (read_count == int'(arlen))
                            read_burst_state <= IDLE;
                    end
                end
            endcase
        end
    end
endmodule
