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

`include "defines.svh"

import defines::*;

//
// Ensure L2 respects ready/valid signals.
// Spec references are from AMBA AXI and ACE Protocol Specification, rev E, A3.4.1
//

module test_l2_cache_wait_state(input clk, input reset);
    localparam DELAY = 3;
    localparam ADDR0 = 'h12;
    localparam DATA0 = 512'h88a84df3d616f6e7701e6461010a1f3f2c931fb4b396d059d177c51b3b17c82ad26c90f1f7040331efd466bde698718ec430b97e0c9241b9a57322c9b092bf3e;
    localparam DATA1 = 512'h8ddc6625b5f211958e5d77eea014d0500f39ab63bc3cc75f360bf2961bef34ec8f095b878488ed87bc3d499699660adbd5b3a99e8e5fd7a6092dd003dc960d31;

    logic[`NUM_CORES - 1:0] l2i_request_valid;
    l2req_packet_t l2i_request[`NUM_CORES];
    logic l2_ready[`NUM_CORES];
    logic l2_response_valid;
    l2rsp_packet_t l2_response;
    axi4_interface axi_bus();
    logic[L2_PERF_EVENTS - 1:0] l2_perf_events;
    int state;
    int axi_burst_offset;
    l1_miss_entry_idx_t last_id;
    int wait_count;

    always_comb
        axi_bus.s_rdata = axi_bus.s_rvalid ? 32'(DATA0 >> ((15 - axi_burst_offset) * 32)) : $random();

    assign l2i_request[0].id = 0;

    l2_cache l2_cache(.*);

    always @(posedge clk, posedge reset)
    begin
        if (reset)
        begin
            axi_bus.s_arready <= 0;
            axi_bus.s_rvalid <= 0;
            axi_bus.s_bvalid <= 0;
            axi_bus.s_awready <= 0;
            axi_bus.s_wready <= 0;
        end
        else
        begin
            l2i_request_valid <= '0;

            unique case (state)
                ///////////////////////////////////////////////////
                // Start read transaction
                ///////////////////////////////////////////////////

                // Send a request packet to the L2 cache
                0:
                begin
                    l2i_request_valid <= 1;
                    l2i_request[0].packet_type <= L2REQ_LOAD;
                    l2i_request[0].address <= ADDR0;
                    state <= state + 1;
                end

                // Wait for read address to be asserted on the AXI bus.
                1:
                begin
                    assert(!l2_response_valid);
                    assert(!axi_bus.m_awvalid);
                    assert(!axi_bus.m_wvalid);
                    l2i_request_valid <= 0;
                    if (axi_bus.m_arvalid)
                    begin
                        assert(axi_bus.m_araddr == ADDR0 * CACHE_LINE_BYTES);
                        assert(axi_bus.m_arlen == 15);
                        wait_count <= DELAY;
                        state <= state + 1;
                    end
                end

                // Wait to assert arready.
                // A3.2.2 "A source is not permitted to wait until READY is asserted before
                // asserting VALID."
                2:
                begin
                    assert(!l2_response_valid);
                    assert(!axi_bus.m_awvalid);
                    assert(!axi_bus.m_wvalid);

                    // A3.2.1 "Once VALID is asserted it must remain asserted until the
                    // handshake occurs"
                    assert(axi_bus.m_arvalid);

                    // Ensure these are stable
                    // A3.2.1 "...the source must keep its information stable until the transfer
                    // occurs..."
                    assert(axi_bus.m_araddr == ADDR0 * CACHE_LINE_BYTES);
                    assert(axi_bus.m_arlen == 15);

                    if (wait_count == 0)
                    begin
                        axi_bus.s_arready <= 1;
                        state <= state + 1;
                    end
                    else
                        wait_count <= wait_count - 1;
                end

                3:
                begin
                    axi_bus.s_arready <= 0;
                    axi_burst_offset <= 0;
                    wait_count <= DELAY;
                    state <= state + 1;
                end

                // Read transfer. Assert rvalid periodically. Ensure nothing
                // is transferred when it is not asserted.
                4:
                begin
                    assert(!l2_response_valid);
                    assert(!axi_bus.m_awvalid);
                    assert(!axi_bus.m_wvalid);
                    assert(!axi_bus.m_arvalid);
                    if (wait_count == 0)
                    begin
                        axi_bus.s_rvalid <= 1;
                        wait_count <= DELAY;
                    end
                    else
                    begin
                        axi_bus.s_rvalid <= 0;
                        wait_count <= wait_count - 1;
                    end

                    if (axi_bus.m_rready && axi_bus.s_rvalid)
                    begin
                        if (axi_burst_offset == 15)
                        begin
                            axi_bus.s_rvalid <= 0;
                            state <= state + 1;
                        end
                        else
                            axi_burst_offset <= axi_burst_offset + 1;
                    end
                end

                // Check response packet from cache to pipeline to ensure data
                // was transferred properly.
                5:
                begin
                    if (l2_response_valid)
                    begin
                        assert(l2_response.packet_type == L2RSP_LOAD_ACK);
                        assert(l2_response.address == ADDR0);
                        assert(l2_response.data == DATA0);
                        state <= state + 1;
                    end
                end

                // Dirty the line so we can flush it
                6:
                begin
                    l2i_request_valid <= 1;
                    l2i_request[0].packet_type <= L2REQ_STORE;
                    l2i_request[0].address <= ADDR0;
                    l2i_request[0].data <= DATA1;
                    l2i_request[0].store_mask <= 64'hffffffff_ffffffff;
                    state <= state + 1;
                end

                7:
                begin
                    assert(!axi_bus.m_arvalid);
                    assert(!axi_bus.m_awvalid);
                    assert(!axi_bus.m_wvalid);
                    if (l2_response_valid)
                    begin
                        assert(l2_response.packet_type == L2RSP_STORE_ACK);
                        state <= state + 1;
                    end
                end

                ///////////////////////////////////////////////////
                // Start write (flush) transaction
                ///////////////////////////////////////////////////
                8:
                begin
                    assert(!l2_response_valid);
                    l2i_request_valid <= 1;
                    l2i_request[0].packet_type = L2REQ_FLUSH;
                    l2i_request[0].address = ADDR0;
                    state <= state + 1;
                end

                // Wait for write address on AXI bus
                9:
                begin
                    l2i_request_valid <= 0;

                    assert(!l2_response_valid);
                    assert(!axi_bus.m_arvalid);
                    assert(!axi_bus.m_wvalid);
                    if (axi_bus.m_awvalid)
                    begin
                        assert(axi_bus.m_awaddr == ADDR0 * CACHE_LINE_BYTES);
                        assert(axi_bus.m_awlen == 15);
                        state <= state + 1;
                        wait_count <= DELAY;
                    end
                end

                // Wait for cache to assert awready
                // As above, the master must not wait for awready to be asserted.
                10:
                begin
                    assert(!l2_response_valid);
                    assert(!axi_bus.m_wvalid);
                    assert(!axi_bus.m_arvalid);

                    // A3.2.1 "Once VALID is asserted it must remain asserted until the
                    // handshake occurs"
                    assert(axi_bus.m_awvalid);

                    // Ensure these are stable
                    // A3.2.1 "...the source must keep its information stable until the transfer
                    // occurs..."
                    assert(axi_bus.m_awaddr == ADDR0 * CACHE_LINE_BYTES);
                    assert(axi_bus.m_awlen == 15);

                    if (wait_count == 0)
                    begin
                        axi_bus.s_awready <= 1;
                        state <= state + 1;
                        wait_count <= DELAY;
                        axi_burst_offset <= 0;
                    end
                    else
                        wait_count <= wait_count - 1;
                end

                11:
                begin
                    axi_bus.s_arready <= 0;
                    axi_burst_offset <= 0;
                    wait_count <= DELAY;
                    state <= state + 1;
                end

                // Write transfer. Transfer wready periodically.
                12:
                begin
                    assert(!l2_response_valid);
                    assert(!axi_bus.m_arvalid);
                    assert(!axi_bus.m_awvalid);
                    axi_bus.s_awready <= 0;
                    if (wait_count == 0)
                    begin
                        axi_bus.s_wready <= 1;
                        wait_count <= DELAY;
                    end
                    else
                    begin
                        axi_bus.s_wready <= 0;
                        wait_count <= wait_count - 1;
                    end

                    // A3.2.2 "The master must assert the WLAST signal while
                    // it is driving the final write transfer in the burst."
                    assert(axi_bus.m_wlast == (axi_burst_offset == 15));

                    if (axi_bus.m_wvalid && axi_bus.s_wready)
                    begin
                        assert(axi_bus.m_wdata == 32'(DATA1 >> ((15 - axi_burst_offset) * 32)));
                        if (axi_burst_offset == 15)
                            state <= state + 1;
                        else
                            axi_burst_offset <= axi_burst_offset + 1;
                    end
                end

                // L2 response
                13:
                begin
                    assert(!axi_bus.m_arvalid);
                    assert(!axi_bus.m_awvalid);
                    assert(!axi_bus.m_wvalid);

                    if (l2_response_valid)
                    begin
                        assert(l2_response.packet_type == L2RSP_FLUSH_ACK);
                        // The address isn't set in the response packet, so don't
                        // need to check it.
                        state <= state + 1;
                    end
                end

                14:
                begin
                    $display("PASS");
                    $finish;
                end
            endcase
        end
    end
endmodule
