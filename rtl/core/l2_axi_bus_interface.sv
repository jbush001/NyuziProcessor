//
// Copyright (C) 2011-2014 Jeff Bush
// 
// This library is free software; you can redistribute it and/or
// modify it under the terms of the GNU Library General Public
// License as published by the Free Software Foundation; either
// version 2 of the License, or (at your option) any later version.
// 
// This library is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
// Library General Public License for more details.
// 
// You should have received a copy of the GNU Library General Public
// License along with this library; if not, write to the
// Free Software Foundation, Inc., 51 Franklin St, Fifth Floor,
// Boston, MA  02110-1301, USA.
//

`include "defines.sv"

//
// L2 AXI Bus Interface
// Receives L2 cache misses and writeback requests from the L2 pipeline and controls
// AXI system memory interface to fulfull them.  When misses are fulfilled, they are
// reissued into the pipeline via the arbiter.
//
// If the request for this line is already being handled, we set a flag
// that causes the request to be reissued, but won't actually
// perform the memory transaction.
//
// The interface to system memory is a simplified subset of the AMBA AXI interface.
//

module l2_axi_bus_interface(
	input                                  clk,
	input                                  reset,

	axi_interface.master                   axi_bus,
	
	// to l2_cache_arb
	output l2req_packet_t                  l2bi_request,
	output cache_line_data_t               l2bi_data_from_memory,
	output logic                           l2bi_stall,
	output logic                           l2bi_ready,
	output                                 l2bi_collided_miss,

	// From l2_cache_read
	input                                  l2r_needs_writeback,
	input l2_tag_t                         l2r_writeback_tag,
	input cache_line_data_t                l2r_data,
	input                                  l2r_is_l2_fill,
	input                                  l2r_cache_hit,
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

	localparam REQUEST_QUEUE_LENGTH = 8;

	// This is the number of stages before this one in the pipeline. We need to assert
	// the signal to stop accepting new packets this number of cycles early so
	// requests that are already in the L2 pipeline don't overrun one of the FIFOs.
	localparam L2REQ_LATENCY = 4;
	localparam BURST_BEATS = `CACHE_LINE_BITS / `AXI_DATA_WIDTH;	
	localparam BURST_OFFSET_WIDTH = $clog2(BURST_BEATS);

	l2_addr_t miss_addr;
	cache_line_index_t writeback_address;
	cache_line_index_t bif_writeback_address;
	logic enqueue_writeback_request;
	logic enqueue_load_request;
	logic duplicate_request;
	cache_line_data_t bif_writeback_data;	
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
	
	assign miss_addr = l2r_request.address;
	assign enqueue_writeback_request = l2r_request.valid && l2r_needs_writeback
		&& ((l2r_request.packet_type == L2REQ_FLUSH && l2r_cache_hit) || l2r_is_l2_fill);
	assign writeback_address = { l2r_writeback_tag, miss_addr.set_idx };
	assign enqueue_load_request = l2r_request.valid && !l2r_cache_hit && !l2r_is_l2_fill
		&& (l2r_request.packet_type == L2REQ_LOAD
		|| l2r_request.packet_type == L2REQ_STORE
		|| l2r_request.packet_type == L2REQ_LOAD_SYNC
		|| l2r_request.packet_type == L2REQ_STORE_SYNC);
	assign writeback_pending = !writeback_queue_empty;
	assign load_request_pending = !load_queue_empty;

	l2_cache_pending_miss_cam l2_cache_pending_miss_cam(
						    .request_valid(l2r_request.valid),
						    .request_addr({miss_addr.tag, miss_addr.set_idx}),
							.*);

	assign perf_l2_writeback = enqueue_writeback_request && !writeback_queue_almost_full;

	sync_fifo #(.DATA_WIDTH($bits(writeback_address) + $bits(l2r_data)), 
		.NUM_ENTRIES(REQUEST_QUEUE_LENGTH), 
		.ALMOST_FULL_THRESHOLD(REQUEST_QUEUE_LENGTH - L2REQ_LATENCY)) sync_fifo_pending_writeback(
		.clk(clk),
		.reset(reset),
		.flush_en(1'b0),
		.almost_full(writeback_queue_almost_full),
		.enqueue_en(enqueue_writeback_request),
		.value_i({
			writeback_address,	// Old address
			l2r_data	// Old line to writeback
		}),
		.almost_empty(),
		.empty(writeback_queue_empty),
		.dequeue_en(writeback_complete),
		.value_o({
			bif_writeback_address,
			bif_writeback_data
		}),
		.full(/* ignore */));

	sync_fifo #(.DATA_WIDTH($bits(l2req_packet_t) + 1), 
		.NUM_ENTRIES(REQUEST_QUEUE_LENGTH), 
		.ALMOST_FULL_THRESHOLD(REQUEST_QUEUE_LENGTH - L2REQ_LATENCY)) sync_fifo_pending_load(
		.clk(clk),
		.reset(reset),
		.flush_en(1'b0),
		.almost_full(load_queue_almost_full),
		.enqueue_en(enqueue_load_request),
		.value_i({ 
			duplicate_request,
			l2r_request
		}),
		.empty(load_queue_empty),
		.almost_empty(),
		.dequeue_en(l2bi_ready),
		.value_o({ 
			l2bi_collided_miss,
			l2bi_request
		}),
		.full(/* ignore */));
			
	// Stop accepting new L2 packets until space is available in the queues
	assign l2bi_stall = load_queue_almost_full || writeback_queue_almost_full;

	// Per AMBA AXI protocol spec v3, A3.4.1, length field is is burst length - 1
	assign axi_bus.awlen = BURST_BEATS - 1;	
	assign axi_bus.arlen = BURST_BEATS - 1;	
	assign axi_bus.bready = 1'b1;
	
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
		l2bi_ready = 0;
		burst_offset_nxt = burst_offset_ff;
		writeback_complete = 0;

		unique case (state_ff)
			STATE_IDLE:
			begin	
				// Writebacks take precendence over loads to avoid a race condition 
				// where we load stale data. Since loads can also enqueue writebacks,
				// it ensures we don't overrun the write FIFO.
				//				
				// In the normal case, writebacks can only be initiated as the side 
				// effect of a load, so they can't starve them.  The flush 
				// instruction introduces a bit of a wrinkle here, because they *can* 
				// starve loads.
				if (writeback_pending)
				begin
					if (!wait_axi_write_response)
						state_nxt = STATE_WRITE_ISSUE_ADDRESS;
				end
				else if (load_request_pending)
				begin
					if (l2bi_collided_miss 
						|| (l2bi_request.store_mask == {`CACHE_LINE_BYTES{1'b1}}
						&& l2bi_request.packet_type == L2REQ_STORE))
					begin
						// There are a few scenarios where we skip the read
						// and reissue the command immediately.
						// 1. If there is already a pending L2 miss for this cache 
						//    line.  Some other request has filled it, so we 
						//    don't need to do anything but (try to) pick up the 
						//    result (that could result in another miss in some
						//    cases, in which case we must make another pass through
						//    here).
						// 2. It is a store that replaces the entire line.
						//    We let this flow through the read miss queue instead
						//    of handling it immediately in the pipeline
						//    because we need it to go through the pending miss unit
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
				if (axi_bus.awready)
					state_nxt = STATE_WRITE_TRANSFER;
			end

			STATE_WRITE_TRANSFER:
			begin
				if (axi_bus.wready)
				begin
					if (burst_offset_ff == BURST_BEATS - 1)
					begin
						writeback_complete = 1;
						state_nxt = STATE_IDLE;
					end

					burst_offset_nxt = burst_offset_ff + 1;
				end
			end

			STATE_READ_ISSUE_ADDRESS:
			begin
				burst_offset_nxt = 0;
				if (axi_bus.arready)
					state_nxt = STATE_READ_TRANSFER;
			end

			STATE_READ_TRANSFER:
			begin
				if (axi_bus.rvalid)
				begin
					if (burst_offset_ff == BURST_BEATS - 1)
						state_nxt = STATE_READ_COMPLETE;

					burst_offset_nxt = burst_offset_ff + 1;
				end
			end

			STATE_READ_COMPLETE:
			begin
				// Push the response back into the L2 pipeline
				state_nxt = STATE_IDLE;
				l2bi_ready = 1'b1;
			end
		endcase
	end

	always_ff @(posedge clk, posedge reset)
	begin : update_gen
		if (reset)
		begin
			for (int i = 0; i < BURST_BEATS; i++)
				bif_load_buffer[i] <= 0;
		
			state_ff <= STATE_IDLE;
			/*AUTORESET*/
			// Beginning of autoreset for uninitialized flops
			axi_bus.araddr <= 1'h0;
			axi_bus.arvalid <= 1'h0;
			axi_bus.awaddr <= 1'h0;
			axi_bus.awvalid <= 1'h0;
			axi_bus.rready <= 1'h0;
			axi_bus.wdata <= 1'h0;
			axi_bus.wlast <= 1'h0;
			axi_bus.wvalid <= 1'h0;
			burst_offset_ff <= {BURST_OFFSET_WIDTH{1'b0}};
			wait_axi_write_response <= 1'h0;
			// End of automatics
		end
		else
		begin
			state_ff <= state_nxt;
			burst_offset_ff <= burst_offset_nxt;
			if (state_ff == STATE_READ_TRANSFER && axi_bus.rvalid)
				bif_load_buffer[burst_offset_ff] <= axi_bus.rdata;
	
			// Write response state machine
			if (state_ff == STATE_WRITE_ISSUE_ADDRESS)
				wait_axi_write_response <= 1;
			else if (axi_bus.bvalid)
				wait_axi_write_response <= 0;

			// Register AXI output signals
			axi_bus.arvalid <= state_nxt == STATE_READ_ISSUE_ADDRESS;
			axi_bus.araddr <= { l2bi_request.address[31:`CACHE_LINE_OFFSET_WIDTH], 
				{`CACHE_LINE_OFFSET_WIDTH{1'b0}} };	
			axi_bus.rready <= state_nxt == STATE_READ_TRANSFER;
			axi_bus.awvalid <= state_nxt == STATE_WRITE_ISSUE_ADDRESS;
			axi_bus.awaddr <= { bif_writeback_address, {`CACHE_LINE_OFFSET_WIDTH{1'b0}} };
			axi_bus.wvalid <= state_nxt == STATE_WRITE_TRANSFER;
			axi_bus.wdata <= bif_writeback_data[~burst_offset_nxt * `AXI_DATA_WIDTH+:`AXI_DATA_WIDTH];
			axi_bus.wlast <= state_nxt == STATE_WRITE_TRANSFER	
				&& axi_bus.wready
				&& burst_offset_ff == BURST_BEATS - 2;
		end
	end
endmodule

// Local Variables:
// verilog-typedef-regexp:"_t$"
// End:
