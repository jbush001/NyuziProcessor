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

`include "defines.sv"

//
// L2 AXI Bus Interface
// Receives L2 cache misses and writeback requests from the L2 pipeline and
// controls AXI system memory interface to fulfill them. When fills complete,
// this reissues them to the L2 pipeline via the arbiter.
//
// If this is already handling the request for a line, it set a flag that
// causes it to reissue the request to the L2 pipeline, but doesn't read
// or write system memory.
//
// The interface to system memory is the AMBA AXI interface.
// http://www.arm.com/products/system-ip/amba-specifications.php
//
// XXX This does not overlap address and data phases, but it should to improve
// bus utilization.
//

module l2_axi_bus_interface(
    input                                  clk,
    input                                  reset,

    axi4_interface.master                  axi_bus,

    // to l2_cache_arb_stage
    output logic                           l2bi_request_valid,
    output l2req_packet_t                  l2bi_request,
    output cache_line_data_t               l2bi_data_from_memory,
    output logic                           l2bi_stall,
    output                                 l2bi_collided_miss,

    // From l2_cache_read_stage
    input                                  l2r_needs_writeback,
    input l2_tag_t                         l2r_writeback_tag,
    input cache_line_data_t                l2r_data,
    input                                  l2r_is_l2_fill,
    input                                  l2r_is_restarted_flush,
    input                                  l2r_cache_hit,
    input                                  l2r_request_valid,
    input l2req_packet_t                   l2r_request,

    // Performance event
    output logic                           perf_l2_writeback);

    typedef enum {
        STATE_IDLE,
        STATE_WRITE_ISSUE_ADDRESS,
        STATE_WRITE_TRANSFER,
        STATE_READ_ISSUE_ADDRESS,
        STATE_READ_TRANSFER,
        STATE_READ_COMPLETE
    } bus_interface_state_t;

    typedef struct packed {
        cache_line_index_t address;
        cache_line_data_t data;
        logic is_flush;
        core_id_t core;
        l1_miss_entry_idx_t id;
    } writeback_queue_entry_t;

    localparam REQUEST_QUEUE_LENGTH = 8;

    // This is the number of stages before this one in the pipeline. Assert the
    // signal to stop accepting new packets this number of cycles early so
    // requests that are already in the L2 pipeline don't overrun the FIFOs.
    localparam L2REQ_LATENCY = 4;
    localparam BURST_BEATS = `CACHE_LINE_BITS / `AXI_DATA_WIDTH;
    localparam BURST_OFFSET_WIDTH = $clog2(BURST_BEATS);

    l2_addr_t miss_addr;
    cache_line_index_t bif_writeback_address;
    logic enqueue_writeback_request;
    logic enqueue_load_request;
    logic duplicate_request;
    cache_line_data_t bif_writeback_data;
    logic[`AXI_DATA_WIDTH - 1:0] bif_writeback_lanes[BURST_BEATS];
    logic writeback_queue_empty;
    logic load_queue_empty;
    logic load_request_pending;
    logic writeback_pending;
    logic writeback_complete;
    logic writeback_queue_almost_full;
    logic load_queue_almost_full;
    bus_interface_state_t state_ff;
    bus_interface_state_t state_nxt;
    logic[BURST_OFFSET_WIDTH - 1:0] burst_offset_ff;
    logic[BURST_OFFSET_WIDTH - 1:0] burst_offset_nxt;
    logic[`AXI_DATA_WIDTH - 1:0] bif_load_buffer[0:BURST_BEATS - 1];
    logic restart_flush_request;
    logic load_dequeue_en;
    l2req_packet_t lmq_out_request;
    writeback_queue_entry_t writeback_queue_in;
    writeback_queue_entry_t writeback_queue_out;

    assign miss_addr = l2r_request.address;
    assign enqueue_writeback_request = l2r_request_valid && l2r_needs_writeback
        && ((l2r_request.packet_type == L2REQ_FLUSH && l2r_cache_hit && !l2r_is_restarted_flush)
        || l2r_is_l2_fill);
    assign enqueue_load_request = l2r_request_valid && !l2r_cache_hit && !l2r_is_l2_fill
        && (l2r_request.packet_type == L2REQ_LOAD
        || l2r_request.packet_type == L2REQ_STORE
        || l2r_request.packet_type == L2REQ_LOAD_SYNC
        || l2r_request.packet_type == L2REQ_STORE_SYNC);
    assign writeback_pending = !writeback_queue_empty;
    assign load_request_pending = !load_queue_empty;

    l2_cache_pending_miss_cam l2_cache_pending_miss_cam(
        .request_valid(l2r_request_valid),
        .request_addr({miss_addr.tag, miss_addr.set_idx}),
        .*);

    assign perf_l2_writeback = enqueue_writeback_request && !writeback_queue_almost_full;

    assign writeback_queue_in.address = {l2r_writeback_tag, miss_addr.set_idx}; // Old address
    assign writeback_queue_in.data = l2r_data; // Old line to writeback
    assign writeback_queue_in.is_flush = l2r_request.packet_type == L2REQ_FLUSH;
    assign writeback_queue_in.core = l2r_request.core;
    assign writeback_queue_in.id = l2r_request.id;

    sync_fifo #(
        .WIDTH($bits(writeback_queue_entry_t)),
        .SIZE(REQUEST_QUEUE_LENGTH),
        .ALMOST_FULL_THRESHOLD(REQUEST_QUEUE_LENGTH - L2REQ_LATENCY)
    ) sync_fifo_pending_writeback(
        .clk(clk),
        .reset(reset),
        .flush_en(1'b0),
        .almost_full(writeback_queue_almost_full),
        .enqueue_en(enqueue_writeback_request),
        .value_i(writeback_queue_in),
        .almost_empty(),
        .empty(writeback_queue_empty),
        .dequeue_en(writeback_complete),
        .value_o(writeback_queue_out),
        .full(/* ignore */));

    assign bif_writeback_address = writeback_queue_out.address;
    assign bif_writeback_data = writeback_queue_out.data;

    sync_fifo #(
        .WIDTH($bits(l2req_packet_t) + 1),
        .SIZE(REQUEST_QUEUE_LENGTH),
        .ALMOST_FULL_THRESHOLD(REQUEST_QUEUE_LENGTH - L2REQ_LATENCY)
    ) sync_fifo_pending_load(
        .clk(clk),
        .reset(reset),
        .flush_en(1'b0),
        .almost_full(load_queue_almost_full),
        .enqueue_en(enqueue_load_request),
        .value_i({duplicate_request, l2r_request}),
        .empty(load_queue_empty),
        .almost_empty(),
        .dequeue_en(load_dequeue_en),
        .value_o({l2bi_collided_miss, lmq_out_request}),
        .full(/* ignore */));

    // Stop accepting new L2 packets until space is available in the queues
    assign l2bi_stall = load_queue_almost_full || writeback_queue_almost_full;

    // AMBA AXI and ACE Protocol Specification, rev E, A3.4.1:
    // length field is is burst length - 1
    assign axi_bus.m_awlen = 8'(BURST_BEATS - 1);
    assign axi_bus.m_arlen = 8'(BURST_BEATS - 1);
    assign axi_bus.m_bready = 1'b1;

    // ibid, Table A3-2
    assign axi_bus.m_arsize = `AXI_DATA_WIDTH == 1 ? 3'd0 : 3'($clog2(`AXI_DATA_WIDTH / 8));
    assign axi_bus.m_awsize = axi_bus.m_arsize;

    assign axi_bus.m_awburst = AXI_BURST_INCR;
    assign axi_bus.m_arburst = AXI_BURST_INCR;
    assign axi_bus.m_wstrb = {(`AXI_DATA_WIDTH / 8){1'b1}};

    // ibid, Table A4-3/A4-4
    assign axi_bus.m_awcache = 4'b1110;    // Allocate, Modifiable, Not-Bufferable
    assign axi_bus.m_arcache = 4'b1110;

    // Flatten array
    genvar load_buffer_idx;
    generate
        for (load_buffer_idx = 0; load_buffer_idx < BURST_BEATS; load_buffer_idx++)
        begin : mem_lane_gen
            assign l2bi_data_from_memory[load_buffer_idx * `AXI_DATA_WIDTH+:`AXI_DATA_WIDTH]
                = bif_load_buffer[BURST_BEATS - load_buffer_idx - 1];
        end
    endgenerate

    logic wait_axi_write_response;

    // Bus state machine
    always_comb
    begin
        state_nxt = state_ff;
        load_dequeue_en = 0;
        burst_offset_nxt = burst_offset_ff;
        writeback_complete = 0;
        restart_flush_request = 0;

        unique case (state_ff)
            STATE_IDLE:
            begin
                // Writebacks take precendence over loads to avoid a race condition
                // where this loads stale data. Since loads can also enqueue writebacks,
                // it ensures this doesn't overrun the write FIFO.
                if (writeback_pending)
                begin
                    if (!wait_axi_write_response)
                        state_nxt = STATE_WRITE_ISSUE_ADDRESS;
                end
                else if (load_request_pending)
                begin
                    if (l2bi_collided_miss
                        || (lmq_out_request.store_mask == {`CACHE_LINE_BYTES{1'b1}}
                        && lmq_out_request.packet_type == L2REQ_STORE))
                    begin
                        // Skip the read and restart the request immediately if:
                        // 1. If there is already a pending L2 miss for this cache
                        //    line. Some other request has filled it, so
                        //    don't need to do anything but (try to) pick up the
                        //    result. That could result in another miss in some
                        //    cases, in which case must make another pass through
                        //    here.
                        // 2. It is a store that replaces the entire line.
                        //    Let this flow through the read miss queue instead
                        //    of handling it immediately in the pipeline
                        //    because it must go through the pending miss unit
                        //    to reconcile any other misses that may be in progress.
                        state_nxt = STATE_READ_COMPLETE;
                    end
                    else
                        state_nxt = STATE_READ_ISSUE_ADDRESS;
                end
            end

            STATE_WRITE_ISSUE_ADDRESS:
            begin
                burst_offset_nxt = 0;
                if (axi_bus.s_awready)
                    state_nxt = STATE_WRITE_TRANSFER;
            end

            STATE_WRITE_TRANSFER:
            begin
                if (axi_bus.s_wready)
                begin
                    if (burst_offset_ff == {BURST_OFFSET_WIDTH{1'b1}})
                    begin
                        writeback_complete = 1;
                        restart_flush_request = writeback_queue_out.is_flush;
                        state_nxt = STATE_IDLE;
                    end

                    burst_offset_nxt = burst_offset_ff + BURST_OFFSET_WIDTH'(1);
                end
            end

            STATE_READ_ISSUE_ADDRESS:
            begin
                burst_offset_nxt = 0;
                if (axi_bus.s_arready)
                    state_nxt = STATE_READ_TRANSFER;
            end

            STATE_READ_TRANSFER:
            begin
                if (axi_bus.s_rvalid)
                begin
                    if (burst_offset_ff == {BURST_OFFSET_WIDTH{1'b1}})
                        state_nxt = STATE_READ_COMPLETE;

                    burst_offset_nxt = burst_offset_ff + BURST_OFFSET_WIDTH'(1);
                end
            end

            STATE_READ_COMPLETE:
            begin
                // Push the response back into the L2 pipeline
                state_nxt = STATE_IDLE;
                load_dequeue_en = 1'b1;
            end
        endcase
    end

    genvar writeback_lane;
    generate
        for (writeback_lane = 0; writeback_lane < BURST_BEATS; writeback_lane++)
        begin : writeback_lane_gen
            assign bif_writeback_lanes[writeback_lane] = bif_writeback_data[writeback_lane * `AXI_DATA_WIDTH+:
                `AXI_DATA_WIDTH];
        end
    endgenerate

    always_comb
    begin
        l2bi_request = lmq_out_request;
        if (restart_flush_request)
        begin
            // For this request, the other fields in the request packet are ignored.
            // To avoid creating a mux for them, we just leave them assigned to
            // the load_reuqest fields.
            l2bi_request_valid = 1'b1;
            l2bi_request.packet_type = L2REQ_FLUSH;
            l2bi_request.core = writeback_queue_out.core;
            l2bi_request.id = writeback_queue_out.id;
            l2bi_request.cache_type = CT_DCACHE;
        end
        else
            l2bi_request_valid = load_dequeue_en;
    end

    always_ff @(posedge clk, posedge reset)
    begin : update
        if (reset)
        begin
            state_ff <= STATE_IDLE;
            /*AUTORESET*/
            // Beginning of autoreset for uninitialized flops
            axi_bus.m_arvalid <= '0;
            axi_bus.m_awvalid <= '0;
            axi_bus.m_rready <= '0;
            axi_bus.m_wlast <= '0;
            axi_bus.m_wvalid <= '0;
            burst_offset_ff <= '0;
            wait_axi_write_response <= '0;
            // End of automatics
        end
        else
        begin
            state_ff <= state_nxt;
            burst_offset_ff <= burst_offset_nxt;

            // Write response state machine
            if (state_ff == STATE_WRITE_ISSUE_ADDRESS)
                wait_axi_write_response <= 1;
            else if (axi_bus.s_bvalid)
                wait_axi_write_response <= 0;

            // Register AXI output signals
            axi_bus.m_arvalid <= state_nxt == STATE_READ_ISSUE_ADDRESS;
            axi_bus.m_rready <= state_nxt == STATE_READ_TRANSFER;
            axi_bus.m_awvalid <= state_nxt == STATE_WRITE_ISSUE_ADDRESS;
            axi_bus.m_wvalid <= state_nxt == STATE_WRITE_TRANSFER;
            axi_bus.m_wlast <= state_nxt == STATE_WRITE_TRANSFER
                && axi_bus.s_wready
                && burst_offset_ff == BURST_OFFSET_WIDTH'(BURST_BEATS) - 2;
        end
    end

    always_ff @(posedge clk)
    begin
        if (state_ff == STATE_READ_TRANSFER && axi_bus.s_rvalid)
            bif_load_buffer[burst_offset_ff] <= axi_bus.s_rdata;

        axi_bus.m_araddr <= {l2bi_request.address, {`CACHE_LINE_OFFSET_WIDTH{1'b0}}};
        axi_bus.m_awaddr <= {bif_writeback_address, {`CACHE_LINE_OFFSET_WIDTH{1'b0}}};
        axi_bus.m_wdata <= bif_writeback_lanes[~burst_offset_nxt];
    end
endmodule
