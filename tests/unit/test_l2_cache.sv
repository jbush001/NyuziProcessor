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
// Validate basic level two cache transactions.
//
module test_l2_cache(input clk, input reset);

    parameter ADDR0 = 'h7;
    parameter DATA0 = 512'h88a84df3d616f6e7701e6461010a1f3f2c931fb4b396d059d177c51b3b17c82ad26c90f1f7040331efd466bde698718ec430b97e0c9241b9a57322c9b092bf3e;

    parameter ADDR1 = 'h9;
    parameter DATA1 = 512'h8ddc6625b5f211958e5d77eea014d0500f39ab63bc3cc75f360bf2961bef34ec8f095b878488ed87bc3d499699660adbd5b3a99e8e5fd7a6092dd003dc960d31;
    parameter STORE_DATA1 = 512'h100f067188502a5f107a9279dca9d1602d911573b3e5a87665e910df1cdf8389f7e8152e39d1366560ea3682a380645ff34dbe5ee0f5ced5b28f1b2f3b846865;
    parameter STORE_MASK1 = 64'b0000000000000000000000000000000000000000000000000000000011110000;
    // DATA1 combined with STORE_DATA1 using STORE_MASK1
    parameter STORE_RESULT1 = 512'h8ddc6625b5f211958e5d77eea014d0500f39ab63bc3cc75f360bf2961bef34ec8f095b878488ed87bc3d499699660adbd5b3a99e8e5fd7a6b28f1b2fdc960d31;

    parameter STORE_DATA2 = 512'h53247ca5145aca409f2bb757fc19fc23e865d9ab7ddecf6d556a53affee8c81bf95da344c43d97076fb48746335c2fbc6a2fc3f5ae67d6af291610b7d1062446;
    parameter STORE_MASK2 = 64'b0000111100000000000000000000000000000000000000000000000000000000;
    parameter STORE_RESULT2 = 512'h88a84df3145aca40701e6461010a1f3f2c931fb4b396d059d177c51b3b17c82ad26c90f1f7040331efd466bde698718ec430b97e0c9241b9a57322c9b092bf3e;

    parameter ADDR3 = 'h1c;
    parameter DATA3 = 512'hcf01cb29d7b525268e5182db49872b1987a8565026b935cbaa1ca1af0c0e1d38f658119af5322b0870a678910fd04faf1591bae8c654c5ebc0ac5728bc879d6d;

    parameter DATA4 = 512'h593a8014753f107e6c5dab5bfad7b4057f22fde149e423c629160878ca4a8f91a3af3fdd0c57221dd753d3f237a3b3662a5504b6fda0dbc9440e8c6db7b0f083;

    logic[`NUM_CORES - 1:0] l2i_request_valid;
    l2req_packet_t l2i_request[`NUM_CORES];
    logic l2_ready[`NUM_CORES];
    logic l2_response_valid;
    l2rsp_packet_t l2_response;
    axi4_interface axi_bus();
    logic[L2_PERF_EVENTS - 1:0] l2_perf_events;
    int state;
    cache_line_data_t axi_data;
    int axi_burst_offset;

    l2_cache l2_cache(.*);

    assign axi_bus.s_arready = 1;
    assign axi_bus.s_rvalid = 1;
    assign axi_bus.s_rdata = 32'(axi_data >> ((15 - axi_burst_offset) * 32));
    assign axi_bus.s_bvalid = 1;
    assign axi_bus.s_awready = 1;
    assign axi_bus.s_wready = 1;

    always @(posedge clk, posedge reset)
    begin
        if (reset)
        begin
            state <= 0;
            l2i_request[0].core <= 0;
        end
        else
        begin
            // default values
            l2i_request_valid <= '0;
            if (l2i_request_valid)
                assert(l2_ready[0]);

            case (state)
                //////////////////////////////////////////////////
                // Load miss
                //////////////////////////////////////////////////
                0:
                begin
                    assert(!l2_response_valid);
                    l2i_request_valid <= 1;
                    l2i_request[0].id <= 1;
                    l2i_request[0].packet_type = L2REQ_LOAD;
                    l2i_request[0].cache_type = CT_DCACHE;
                    l2i_request[0].address = ADDR0;
                    axi_data <= DATA0;
                    state <= state + 1;
                end

                // Wait for read address
                1:
                begin
                    assert(!l2_response_valid);
                    assert(!axi_bus.m_awvalid);
                    assert(!axi_bus.m_wvalid);
                    if (axi_bus.m_arvalid)
                    begin
                        assert(axi_bus.m_araddr == ADDR0 * CACHE_LINE_BYTES);
                        assert(axi_bus.m_arlen == 15);
                        state <= state + 1;
                        axi_burst_offset <= 0;
                    end
                end

                // Read data
                2:
                begin
                    assert(!l2_response_valid);
                    if (axi_bus.m_rready)
                    begin
                        if (axi_burst_offset == 15)
                            state <= state + 1;
                        else
                            axi_burst_offset <= axi_burst_offset + 1;
                    end
                end

                // Wait for response
                3:
                begin
                    if (l2_response_valid)
                    begin
                        assert(l2_response.core == 0);
                        assert(l2_response.id == 1);
                        assert(l2_response.packet_type == L2RSP_LOAD_ACK);
                        assert(l2_response.cache_type == CT_DCACHE);
                        assert(l2_response.address == ADDR0);
                        assert(l2_response.data == DATA0);
                        state <= state + 1;
                    end
                end

                //////////////////////////////////////////////////
                // Store miss
                //////////////////////////////////////////////////
                4:
                begin
                    assert(!l2_response_valid);
                    l2i_request_valid <= 1;
                    l2i_request[0].id <= 2;
                    l2i_request[0].packet_type = L2REQ_STORE;
                    l2i_request[0].cache_type = CT_DCACHE;
                    l2i_request[0].address = ADDR1;
                    l2i_request[0].data = STORE_DATA1;
                    l2i_request[0].store_mask = STORE_MASK1;
                    axi_data <= DATA1;
                    state <= state + 1;
                end

                // Wait for read address
                5:
                begin
                    assert(!l2_response_valid);
                    assert(!axi_bus.m_awvalid);
                    assert(!axi_bus.m_wvalid);
                    if (axi_bus.m_arvalid)
                    begin
                        assert(axi_bus.m_araddr == ADDR1 * CACHE_LINE_BYTES);
                        assert(axi_bus.m_arlen == 15);
                        state <= state + 1;
                        axi_burst_offset <= 0;
                    end
                end

                // Read data over AXI
                6:
                begin
                    assert(!l2_response_valid);
                    if (axi_bus.m_rready)
                    begin
                        if (axi_burst_offset == 15)
                            state <= state + 1;
                        else
                            axi_burst_offset <= axi_burst_offset + 1;
                    end
                end

                // Wait for response
                7:
                begin
                    if (l2_response_valid)
                    begin
                        assert(l2_response.core == 0);
                        assert(l2_response.id == 2);
                        assert(l2_response.packet_type == L2RSP_STORE_ACK);
                        assert(l2_response.cache_type == CT_DCACHE);
                        assert(l2_response.address == ADDR1);
                        assert(l2_response.data == STORE_RESULT1);
                        state <= state + 1;
                    end
                end

                /////////////////////////////////////////////////////////////
                // Load hit. This does double duty, validating the value
                // that was stored above.
                /////////////////////////////////////////////////////////////
                8:
                begin
                    assert(!l2_response_valid);
                    l2i_request_valid <= 1;
                    l2i_request[0].id <= 3;
                    l2i_request[0].packet_type = L2REQ_LOAD;
                    l2i_request[0].cache_type = CT_DCACHE;
                    l2i_request[0].address = ADDR1;
                    axi_data <= DATA0;
                    state <= state + 1;
                end

                // Ensure this is cached, we should get the response immediately
                // with no AXI transfer.
                9:
                begin
                    assert(!axi_bus.m_arvalid);
                    assert(!axi_bus.m_awvalid);
                    assert(!axi_bus.m_wvalid);
                    if (l2_response_valid)
                    begin
                        assert(l2_response.core == 0);
                        assert(l2_response.id == 3);
                        assert(l2_response.packet_type == L2RSP_LOAD_ACK);
                        assert(l2_response.cache_type == CT_DCACHE);
                        assert(l2_response.address == ADDR1);
                        assert(l2_response.data == STORE_RESULT1);
                        state <= state + 1;
                    end
                end

                //////////////////////////////////////////////////
                // Store hit
                //////////////////////////////////////////////////
                10:
                begin
                    assert(!l2_response_valid);
                    l2i_request_valid <= 1;
                    l2i_request[0].id <= 0;
                    l2i_request[0].packet_type <= L2REQ_STORE;
                    l2i_request[0].cache_type <= CT_DCACHE;
                    l2i_request[0].address <= ADDR0;
                    l2i_request[0].data <= STORE_DATA2;
                    l2i_request[0].store_mask = STORE_MASK2;
                    state <= state + 1;
                end

                // Wait for response. There shouldn't be an AXI transaction
                11:
                begin
                    assert(!axi_bus.m_arvalid);
                    assert(!axi_bus.m_awvalid);
                    assert(!axi_bus.m_wvalid);
                    if (l2_response_valid)
                    begin
                        assert(l2_response.core == 0);
                        assert(l2_response.id == 0);
                        assert(l2_response.packet_type == L2RSP_STORE_ACK);
                        assert(l2_response.cache_type == CT_DCACHE);
                        assert(l2_response.address == ADDR0);
                        assert(l2_response.data == STORE_RESULT2);
                        state <= state + 1;
                    end
                end

                //////////////////////////////////////////////////////////
                // Collided miss (a second miss occurs to the same address
                // before the first completes
                ///////////////////////////////////////////////////////////
                12:
                begin
                    assert(!l2_response_valid);
                    l2i_request_valid <= 1;
                    l2i_request[0].id <= 1;
                    l2i_request[0].packet_type = L2REQ_LOAD;
                    l2i_request[0].cache_type = CT_DCACHE;
                    l2i_request[0].address = ADDR3;
                    axi_data <= DATA3;
                    state <= state + 1;
                end

                // Send second request for the same address.
                // I'm taking a few shortcuts here based on knowledge of the
                // implementation:
                // - I know the AXI transaction won't come yet, so I don't
                //   bother waiting for it.
                // - I know the L2 cache will be ready to take the transaction
                //   and I don't need to wait for l2_ready (because there are no
                //   restarts pending).
                13:
                begin
                    assert(!l2_response_valid);
                    assert(!axi_bus.m_arvalid);
                    assert(!axi_bus.m_awvalid);
                    assert(!axi_bus.m_wvalid);

                    l2i_request_valid <= 1;
                    l2i_request[0].id <= 2;
                    l2i_request[0].packet_type = L2REQ_LOAD;
                    l2i_request[0].cache_type = CT_DCACHE;
                    l2i_request[0].address = ADDR3;
                    state <= state + 1;
                end

                // Wait for read address
                14:
                begin
                    assert(!l2_response_valid);
                    assert(!axi_bus.m_awvalid);
                    assert(!axi_bus.m_wvalid);
                    if (axi_bus.m_arvalid)
                    begin
                        assert(axi_bus.m_araddr == ADDR3 * CACHE_LINE_BYTES);
                        assert(axi_bus.m_arlen == 15);
                        state <= state + 1;
                        axi_burst_offset <= 0;
                    end
                end

                // Read AXI data
                15:
                begin
                    assert(!l2_response_valid);
                    if (axi_bus.m_rready)
                    begin
                        if (axi_burst_offset == 15)
                            state <= state + 1;
                        else
                            axi_burst_offset <= axi_burst_offset + 1;
                    end
                end

                // Response 1
                16:
                begin
                    assert(!axi_bus.m_arvalid);
                    assert(!axi_bus.m_awvalid);
                    assert(!axi_bus.m_wvalid);

                    if (l2_response_valid)
                    begin
                        assert(l2_response.core == 0);
                        assert(l2_response.id == 1);
                        assert(l2_response.packet_type == L2RSP_LOAD_ACK);
                        assert(l2_response.cache_type == CT_DCACHE);
                        assert(l2_response.address == ADDR3);
                        assert(l2_response.data == DATA3);
                        state <= state + 1;
                    end
                end

                // Response 2. Picks up same data as the first one, but without
                // loading (read combining)
                17:
                begin
                    assert(!axi_bus.m_arvalid);
                    assert(!axi_bus.m_awvalid);
                    assert(!axi_bus.m_wvalid);

                    if (l2_response_valid)
                    begin
                        assert(l2_response.core == 0);
                        assert(l2_response.id == 2);
                        assert(l2_response.packet_type == L2RSP_LOAD_ACK);
                        assert(l2_response.cache_type == CT_DCACHE);
                        assert(l2_response.address == ADDR3);
                        assert(l2_response.data == DATA3);
                        state <= state + 1;
                    end
                end

                /////////////////////////////////////////////////////////
                // Flush a dirty line (we wrote to this address earlier)
                /////////////////////////////////////////////////////////
                18:
                begin
                    assert(!l2_response_valid);
                    l2i_request_valid <= 1;
                    l2i_request[0].id <= 0;
                    l2i_request[0].packet_type = L2REQ_FLUSH;
                    l2i_request[0].cache_type = CT_DCACHE;
                    l2i_request[0].address = ADDR1;
                    state <= state + 1;
                end

                // Wait for write address
                19:
                begin
                    assert(!l2_response_valid);
                    assert(!axi_bus.m_arvalid);
                    assert(!axi_bus.m_wvalid);
                    if (axi_bus.m_awvalid)
                    begin
                        assert(axi_bus.m_awaddr == ADDR1 * CACHE_LINE_BYTES);
                        assert(axi_bus.m_arlen == 15);
                        state <= state + 1;
                        axi_burst_offset <= 0;
                    end
                end

                // write transfer
                20:
                begin
                    assert(!l2_response_valid);
                    if (axi_bus.m_wvalid)
                    begin
                        $display("m_wdata = %x", axi_bus.m_wdata);
                        assert(axi_bus.m_wdata == 32'(STORE_RESULT1 >> ((15 - axi_burst_offset) * 32)));

                        if (axi_burst_offset == 15)
                            state <= state + 1;
                        else
                            axi_burst_offset <= axi_burst_offset + 1;
                    end
                end

                // L2 response
                21:
                begin
                    assert(!axi_bus.m_arvalid);
                    assert(!axi_bus.m_awvalid);
                    assert(!axi_bus.m_wvalid);

                    if (l2_response_valid)
                    begin
                        assert(l2_response.core == 0);
                        assert(l2_response.id == 0);
                        assert(l2_response.packet_type == L2RSP_FLUSH_ACK);
                        assert(l2_response.cache_type == CT_DCACHE);
                        // XXX the address isn't set.
                        state <= state + 1;
                    end
                end

                ////////////////////////////////////////////////////////////
                // Flush a clean line (nothing should be written to memory)
                ////////////////////////////////////////////////////////////
                22:
                begin
                    assert(!l2_response_valid);
                    l2i_request_valid <= 1;
                    l2i_request[0].id <= 1;
                    l2i_request[0].packet_type = L2REQ_FLUSH;
                    l2i_request[0].cache_type = CT_DCACHE;
                    l2i_request[0].address = ADDR3;
                    state <= state + 1;
                end

                // Ensure we get the response after with no AXI transaction.
                23:
                begin
                    assert(!axi_bus.m_arvalid);
                    assert(!axi_bus.m_awvalid);
                    assert(!axi_bus.m_wvalid);
                    if (l2_response_valid)
                    begin
                        assert(l2_response.core == 0);
                        assert(l2_response.id == 1);
                        assert(l2_response.packet_type == L2RSP_FLUSH_ACK);
                        assert(l2_response.cache_type == CT_DCACHE);
                        // XXX the address isn't set.
                        state <= state + 1;
                    end
                end

                //////////////////////////////////////////////////////////////
                // Invalidate (we stored to ADDR0 earlier, so this is dirty)
                //////////////////////////////////////////////////////////////
                24:
                begin
                    assert(!l2_response_valid);
                    l2i_request_valid <= 1;
                    l2i_request[0].id <= 2;
                    l2i_request[0].packet_type = L2REQ_DINVALIDATE;
                    l2i_request[0].cache_type = CT_DCACHE;
                    l2i_request[0].address = ADDR0;
                    state <= state + 1;
                end

                // Response comes back with no AXI write
                25:
                begin
                    assert(!axi_bus.m_arvalid);
                    assert(!axi_bus.m_awvalid);
                    assert(!axi_bus.m_wvalid);
                    if (l2_response_valid)
                    begin
                        assert(l2_response.core == 0);
                        assert(l2_response.id == 2);
                        assert(l2_response.packet_type == L2RSP_DINVALIDATE_ACK);
                        assert(l2_response.cache_type == CT_DCACHE);
                        // XXX the address isn't set.
                        state <= state + 1;
                    end
                end

                // try to reload this address, ensure it attempts a read (confirming
                // it was invalidated).
                26:
                begin
                    assert(!l2_response_valid);
                    l2i_request_valid <= 1;
                    l2i_request[0].id <= 1;
                    l2i_request[0].packet_type = L2REQ_LOAD;
                    l2i_request[0].cache_type = CT_DCACHE;
                    l2i_request[0].address = ADDR0;
                    state <= state + 1;
                end

                // wait for address
                27:
                begin
                    assert(!l2_response_valid);
                    assert(!axi_bus.m_awvalid);
                    assert(!axi_bus.m_wvalid);
                    if (axi_bus.m_arvalid)
                    begin
                        assert(axi_bus.m_araddr == ADDR0 * CACHE_LINE_BYTES);
                        assert(axi_bus.m_arlen == 15);
                        state <= state + 1;
                        axi_burst_offset <= 0;
                        axi_data <= DATA4;
                    end
                end

                // Transfer data
                28:
                begin
                    assert(!l2_response_valid);
                    if (axi_bus.m_rready)
                    begin
                        if (axi_burst_offset == 15)
                            state <= state + 1;
                        else
                            axi_burst_offset <= axi_burst_offset + 1;
                    end
                end

                // End of transaction, verify data in response is the new data
                // read from memory and not what was written there previously
                29:
                begin
                    assert(!axi_bus.m_arvalid);
                    assert(!axi_bus.m_awvalid);
                    assert(!axi_bus.m_wvalid);

                    if (l2_response_valid)
                    begin
                        assert(l2_response.core == 0);
                        assert(l2_response.id == 1);
                        assert(l2_response.packet_type == L2RSP_LOAD_ACK);
                        assert(l2_response.cache_type == CT_DCACHE);
                        assert(l2_response.address == ADDR0);
                        assert(l2_response.data == DATA4);
                        state <= state + 1;
                    end
                end

                30:
                begin
                    $display("PASS");
                    $finish;
                end
            endcase
        end
    end
endmodule
