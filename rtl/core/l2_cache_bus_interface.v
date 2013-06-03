// 
// Copyright 2011-2012 Jeff Bush
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

`include "defines.v"

//
// L2 External Bus Interface
// Queue L2 cache misses and interacts with system memory to move data to
// and from the L2 cache. Operations are enqueued here after the read stage 
// in the L2 pipeline.  When misses are fulfilled, they are reissued into the
// pipeline via the arbiter.
//
// If the request for this line is already being handled, we set a bit
// in the FIFO that will cause the request to be reissued, but won't actually
// perform the memory transaction.
//
// The interface to system memory is similar to the AMBA AXI interface.
//

module l2_cache_bus_interface
	(input 						clk,
	input						reset,
	
	// From read stage
	input						rd_l2req_valid,
	input[`CORE_INDEX_WIDTH - 1:0] rd_l2req_core,
	input[1:0]					rd_l2req_unit,
	input[1:0]					rd_l2req_strand,
	input[2:0]					rd_l2req_op,
	input[1:0]					rd_l2req_way,
	input[25:0]					rd_l2req_address,
	input[511:0]				rd_l2req_data,
	input[63:0]					rd_l2req_mask,
	input  						rd_is_l2_fill,
	input  						rd_cache_hit,
	input[511:0] 				rd_cache_mem_result,
	input[`L2_TAG_WIDTH - 1:0] 	rd_old_l2_tag,
	input 						rd_line_is_dirty,
	
	// To arbiter (for restarted command)
	output 						bif_input_wait,
	output						bif_duplicate_request,
	output[`CORE_INDEX_WIDTH - 1:0] bif_l2req_core,
	output[1:0]					bif_l2req_unit,				
	output[1:0]					bif_l2req_strand,
	output[2:0]					bif_l2req_op,
	output[1:0]					bif_l2req_way,
	output[25:0]				bif_l2req_address,
	output[511:0]				bif_l2req_data,
	output[63:0]				bif_l2req_mask,
	output [511:0] 				bif_load_buffer_vec,
	output reg					bif_data_ready,
	
	// To system bus (AXI)
	output [31:0]				axi_awaddr,   // Write address channel
	output [7:0]				axi_awlen,
	output reg					axi_awvalid,
	input						axi_awready,
	output [31:0]				axi_wdata,    // Write data channel
	output reg					axi_wlast,
	output reg					axi_wvalid,
	input						axi_wready,
	input						axi_bvalid,   // Write response channel
	output						axi_bready,
	output [31:0]				axi_araddr,   // Read address channel
	output [7:0]				axi_arlen,
	output reg					axi_arvalid,
	input						axi_arready,
	output reg					axi_rready,   // Read data channel
	input						axi_rvalid,         
	input [31:0]				axi_rdata,
	
	// Performance event
	output						pc_event_l2_writeback);

	wire[`L2_SET_INDEX_WIDTH - 1:0] set_index = rd_l2req_address[`L2_SET_INDEX_WIDTH - 1:0];
	wire enqueue_writeback_request = rd_l2req_valid && rd_line_is_dirty
		&& (rd_l2req_op == `L2REQ_FLUSH || rd_is_l2_fill);
	wire[25:0] writeback_address = { rd_old_l2_tag, set_index };	

	wire enqueue_load_request = rd_l2req_valid && !rd_cache_hit && !rd_is_l2_fill
		&& (rd_l2req_op == `L2REQ_LOAD
		|| rd_l2req_op == `L2REQ_STORE
		|| rd_l2req_op == `L2REQ_LOAD_SYNC
		|| rd_l2req_op == `L2REQ_STORE_SYNC);
		
	wire duplicate_request;
		
	wire[511:0] bif_writeback_data;	
	wire[25:0] bif_writeback_address;
	wire writeback_queue_empty;
	wire load_queue_empty;
	wire load_request_pending;
	wire writeback_pending = !writeback_queue_empty;
	reg writeback_complete;
	wire writeback_queue_almost_full;
	wire load_queue_almost_full;

	assign load_request_pending = !load_queue_empty;

	localparam REQUEST_QUEUE_LENGTH = 8;

	// This is the number of stages before SMI in the pipeline. We need to assert
	// the signal to stop accepting new packets this number of cycles early so
	// requests that are already in the L2 pipeline don't overrun one of the FIFOs.
	localparam L2REQ_LATENCY = 4;

	l2_cache_pending_miss l2_cache_pending_miss(/*AUTOINST*/
						    // Outputs
						    .duplicate_request	(duplicate_request),
						    // Inputs
						    .clk		(clk),
						    .reset		(reset),
						    .rd_l2req_valid	(rd_l2req_valid),
						    .rd_l2req_address	(rd_l2req_address[25:0]),
						    .enqueue_load_request(enqueue_load_request),
						    .rd_is_l2_fill	(rd_is_l2_fill));

	assign pc_event_l2_writeback = enqueue_writeback_request && !writeback_queue_almost_full;

	sync_fifo #(.DATA_WIDTH(538), 
		.NUM_ENTRIES(REQUEST_QUEUE_LENGTH), 
		.ALMOST_FULL_THRESHOLD(L2REQ_LATENCY)) writeback_queue(
		.clk(clk),
		.reset(reset),
		.flush_i(1'b0),
		.almost_full_o(writeback_queue_almost_full),
		.enqueue_i(enqueue_writeback_request),
		.value_i({
			writeback_address,	// Old address
			rd_cache_mem_result	// Old line to writeback
		}),
		.empty_o(writeback_queue_empty),
		.dequeue_i(writeback_complete),
		.value_o({
			bif_writeback_address,
			bif_writeback_data
		}),
		.full_o(/* ignore */));

	sync_fifo #(.DATA_WIDTH(612 + `CORE_INDEX_WIDTH), 
		.NUM_ENTRIES(REQUEST_QUEUE_LENGTH), 
		.ALMOST_FULL_THRESHOLD(L2REQ_LATENCY)) load_queue(
		.clk(clk),
		.reset(reset),
		.flush_i(1'b0),
		.almost_full_o(load_queue_almost_full),
		.enqueue_i(enqueue_load_request),
		.value_i(
			{ 
				duplicate_request,
				rd_l2req_core,
				rd_l2req_unit,
				rd_l2req_strand,
				rd_l2req_op,
				rd_l2req_way,
				rd_l2req_address,
				rd_l2req_data,
				rd_l2req_mask
			}),
		.empty_o(load_queue_empty),
		.dequeue_i(bif_data_ready),
		.value_o(
			{ 
				bif_duplicate_request,
				bif_l2req_core,
				bif_l2req_unit,
				bif_l2req_strand,
				bif_l2req_op,
				bif_l2req_way,
				bif_l2req_address,
				bif_l2req_data,
				bif_l2req_mask
			}),
			.full_o(/* ignore */));

	// Stop accepting new L2 packets until space is available in the queues
	assign bif_input_wait = load_queue_almost_full || writeback_queue_almost_full;

	localparam STATE_IDLE = 0;
	localparam STATE_WRITE_ISSUE_ADDRESS = 1;
	localparam STATE_WRITE_TRANSFER = 2;
	localparam STATE_READ_ISSUE_ADDRESS = 3;
	localparam STATE_READ_TRANSFER = 4;
	localparam STATE_READ_COMPLETE = 5;

	localparam BURST_LENGTH = 16;	// 4 bytes per transfer, cache line is 64 bytes

	assign axi_awlen = BURST_LENGTH;
	assign axi_arlen = BURST_LENGTH;
	assign axi_bready = 1'b1;

	reg[2:0] state_ff;
	reg[2:0] state_nxt;
	reg[3:0] burst_offset_ff;
	reg[3:0] burst_offset_nxt;
	reg[31:0] bif_load_buffer[0:15];
	assign bif_load_buffer_vec = {
		bif_load_buffer[0],
		bif_load_buffer[1],
		bif_load_buffer[2],
		bif_load_buffer[3],
		bif_load_buffer[4],
		bif_load_buffer[5],
		bif_load_buffer[6],
		bif_load_buffer[7],
		bif_load_buffer[8],
		bif_load_buffer[9],
		bif_load_buffer[10],
		bif_load_buffer[11],
		bif_load_buffer[12],
		bif_load_buffer[13],
		bif_load_buffer[14],
		bif_load_buffer[15]
	};

	assign axi_awaddr = { bif_writeback_address, 6'd0 };
	assign axi_araddr = { bif_l2req_address, 6'd0 };	

	reg wait_axi_write_response;

	// Bus state machine
	always @*
	begin
		state_nxt = state_ff;
		bif_data_ready = 0;
		burst_offset_nxt = burst_offset_ff;
		writeback_complete = 0;
		axi_awvalid = 0;
		axi_wvalid = 0;
		axi_arvalid = 0;
		axi_rready = 0;
		axi_wlast = 0;

		case (state_ff)
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
					if (bif_duplicate_request)
						state_nxt = STATE_READ_COMPLETE;	// Just re-issue request
					else
						state_nxt = STATE_READ_ISSUE_ADDRESS;
				end
			end

			STATE_WRITE_ISSUE_ADDRESS:
			begin
				axi_awvalid = 1'b1;
				burst_offset_nxt = 0;
				if (axi_awready)
					state_nxt = STATE_WRITE_TRANSFER;
			end

			STATE_WRITE_TRANSFER:
			begin
				axi_wvalid = 1'b1;
				if (axi_wready)
				begin
					if (burst_offset_ff == BURST_LENGTH - 1)
					begin
						axi_wlast = 1'b1;
						writeback_complete = 1;
						state_nxt = STATE_IDLE;
					end

					burst_offset_nxt = burst_offset_ff + 1;
				end
			end

			STATE_READ_ISSUE_ADDRESS:
			begin
				axi_arvalid = 1'b1;
				burst_offset_nxt = 0;
				if (axi_arready)
					state_nxt = STATE_READ_TRANSFER;
			end

			STATE_READ_TRANSFER:
			begin
				axi_rready = 1'b1;
				if (axi_rvalid)
				begin
					if (burst_offset_ff == BURST_LENGTH - 1)
						state_nxt = STATE_READ_COMPLETE;

					burst_offset_nxt = burst_offset_ff + 1;
				end
			end

			STATE_READ_COMPLETE:
			begin
				// Push the response back into the L2 pipeline
				state_nxt = STATE_IDLE;
				bif_data_ready = 1'b1;
			end
		endcase
	end
	
	integer i;

	always @(posedge clk, posedge reset)
	begin
		if (reset)
		begin
			for (i = 0; i < 16; i = i + 1)
				bif_load_buffer[i] <= 0;
		
			/*AUTORESET*/
			// Beginning of autoreset for uninitialized flops
			burst_offset_ff <= 4'h0;
			state_ff <= 3'h0;
			wait_axi_write_response <= 1'h0;
			// End of automatics
		end
		else
		begin
			state_ff <= state_nxt;
			burst_offset_ff <= burst_offset_nxt;
			if (state_ff == STATE_READ_TRANSFER && axi_rvalid)
				bif_load_buffer[burst_offset_ff] <= axi_rdata;
	
			// Write response state machine
			if (state_ff == STATE_WRITE_ISSUE_ADDRESS)
				wait_axi_write_response <= 1;
			else if (axi_bvalid)
				wait_axi_write_response <= 0;
		end
	end

	lane_select_mux #(.ASCENDING_INDEX(1)) data_output_mux(
		.value_i(bif_writeback_data),
		.lane_select_i(burst_offset_ff),
		.value_o(axi_wdata));
endmodule
