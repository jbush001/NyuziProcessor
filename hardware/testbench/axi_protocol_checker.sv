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
    logic [7:0] awlen;
    int write_count;

    always @(posedge axi_bus.m_aclk, negedge axi_bus.m_aresetn)
    begin
        if (!axi_bus.m_aresetn)
        begin
            write_burst_state <= IDLE;

            // A3.1.2: The master must drive AWVALID and WVALID low in reset
            // The slave must drive BVALID low.
            // The time check avoids false assertions when Verilator initially
            // randomly initializes the state.
            // Not checked: these signals shouldn't be driven high until a cycle
            // after reset is deassertted.
            if ($time != 0)
            begin
                assert(axi_bus.m_awvalid == 0);
                assert(axi_bus.m_wvalid == 0);
                assert(axi_bus.s_bvalid == 0);
            end
        end
        else
        begin
            case (write_burst_state)
                IDLE:
                begin
                    if (axi_bus.m_awvalid)
                    begin
                        awaddr <= axi_bus.m_awaddr;
                        awlen <= axi_bus.m_awlen;

                        // This is not a requirement of the spec, but
                        // we've made the simplifying assumption in this module
                        // that only one transaction is valid.
                        assert(!axi_bus.m_wvalid);

                        // A3.4.1 Ensure this transaction doesn't cross a 4k boundary
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
                    // A3.2.2: when asserted, AWVALID must remain asserted
                    // until the slave asserts AWREADY. AWADDR and AWLEN
                    // must also be stable.
                    assert(axi_bus.m_awvalid);
                    assert(axi_bus.m_awaddr === awaddr);
                    assert(axi_bus.m_awlen === awlen);

                    // Ensure single transaction is pending (not spec constraint)
                    assert(!axi_bus.m_wvalid);
                    if (axi_bus.s_awready)
                        write_burst_state <= ADDRESS_ACCEPTED;
                end

                ADDRESS_ACCEPTED:
                begin
                    // Not checked: A3.2.2: once WVALID is asserted, it should
                    // remain so until the rising clock edge after WREADY is
                    // ASSERTED

                    if (axi_bus.m_wvalid && axi_bus.s_wready)
                    begin
                        assert(write_count <= int'(awlen));

                        // A3.2.2: WLAST must be asserted during the final write
                        // transfer of the burst.
                        assert(axi_bus.m_wlast === (write_count == int'(awlen)));
                        assert(!axi_bus.m_awvalid);
                        write_count <= write_count + 1;
                        if (write_count == int'(awlen))
                            write_burst_state <= RESPONSE;
                    end
                end

                RESPONSE:
                begin
                    // A3.3: A write response must always follow the last write
                    // transfer. These assume a single pending transaction.
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
    logic [7:0] arlen;
    int read_count;

    always @(posedge axi_bus.m_aclk, negedge axi_bus.m_aresetn)
    begin
        if (!axi_bus.m_aresetn)
        begin
            read_burst_state <= IDLE;

            // A3.1.2: The master must drive ARVALID low in reset.
            // The slave must drive RVALID low.
            // The time check avoids false assertions when Verilator initially
            // randomly initializes the state.
            // Not checked: these signals shouldn't be driven high until a cycle
            // after reset is deassertted.
            if ($time != 0)
            begin
                assert(axi_bus.m_arvalid == 0);
                assert(axi_bus.s_rvalid == 0);
            end
        end
        else
        begin
            case (read_burst_state)
                IDLE:
                begin
                    if (axi_bus.m_arvalid)
                    begin
                        araddr <= axi_bus.m_araddr;
                        arlen <= axi_bus.m_arlen;

                        // A3.4.1 Ensure this transaction doesn't cross a 4k boundary
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
                    // A3.2.2: ARVALID must remain asserted until the slave
                    // asserts ARREADY. ARADDR and ARLEN must also be stable.
                    assert(axi_bus.m_arvalid);
                    assert(axi_bus.m_araddr === araddr);
                    assert(axi_bus.m_arlen === arlen);

                    if (axi_bus.s_arready)
                        read_burst_state <= ADDRESS_ACCEPTED;
                end

                ADDRESS_ACCEPTED:
                begin
                    if (axi_bus.s_rvalid && axi_bus.m_rready)
                    begin
                        assert(read_count <= int'(arlen));

                        // Check that only a single transaction is pending (not
                        // a spec constraint)
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
