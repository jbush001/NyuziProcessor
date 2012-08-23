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

`include "l2_cache.h"

//
// L2 Cache System Memory Interface 
// Queue L2 cache misses and interacts with system memory to move data to
// and from the L2 cache. Operations are enqueued here after the read stage 
// in the L2 pipeline.  When misses are fulfilled, they are reissued into the
// pipeline via the arbiter.
//
// If the request for this line is already being handled, we set a bit
// in the FIFO that will cause the request to be reissued, but won't actually
// perform the memory transaction.
//

module l2_cache_smi
	(input clk,
	output stall_pipeline,
	input						rd_l2req_valid,
	input[1:0]					rd_l2req_unit,
	input[1:0]					rd_l2req_strand,
	input[2:0]					rd_l2req_op,
	input[1:0]					rd_l2req_way,
	input[25:0]					rd_l2req_address,
	input[511:0]				rd_l2req_data,
	input[63:0]					rd_l2req_mask,
	input  						rd_has_sm_data,
	input [1:0] 				rd_replace_l2_way,
	input  						rd_cache_hit,
	input[511:0] 				rd_cache_mem_result,
	input[`L2_TAG_WIDTH - 1:0] 	rd_old_l2_tag,
	input 						rd_line_is_dirty,
	output						smi_duplicate_request,
	output[1:0]					smi_l2req_unit,				
	output[1:0]					smi_l2req_strand,
	output[2:0]					smi_l2req_op,
	output[1:0]					smi_l2req_way,
	output[25:0]				smi_l2req_address,
	output[511:0]				smi_l2req_data,
	output[63:0]				smi_l2req_mask,
	output [511:0] 				smi_load_buffer_vec,
	output reg					smi_data_ready = 0,
	output[1:0]					smi_fill_l2_way,
	output [31:0]				axi_awaddr,         // Write address channel
	output [7:0]				axi_awlen,
	output reg					axi_awvalid = 0,
	input						axi_awready,
	output [31:0]				axi_wdata,          // Write data channel
	output reg					axi_wlast = 0,
	output reg					axi_wvalid = 0,
	input						axi_wready,
	input						axi_bvalid,         // Write response channel
	output						axi_bready,
	output [31:0]				axi_araddr,         // Read address channel
	output [7:0]				axi_arlen,
	output reg					axi_arvalid = 0,
	input						axi_arready,
	output reg					axi_rready = 0,     // Read data channel
	input						axi_rvalid,         
	input [31:0]				axi_rdata);

	wire[`L2_SET_INDEX_WIDTH - 1:0] set_index = rd_l2req_address[`L2_SET_INDEX_WIDTH - 1:0];
	wire enqueue_writeback_request = rd_l2req_valid && rd_line_is_dirty
		&& (rd_l2req_op == `L2REQ_FLUSH || rd_has_sm_data);
	wire[25:0] writeback_address = { rd_old_l2_tag, set_index };	


	wire enqueue_load_request = rd_l2req_valid && !rd_cache_hit && !rd_has_sm_data
		&& rd_l2req_op != `L2REQ_FLUSH && rd_l2req_op != `L2REQ_INVALIDATE;
	assign stall_pipeline = enqueue_writeback_request && writeback_queue_full;
		//XXX should also check enqueue_load_request && load_queue_full, but that will deadlock pipeline.
	wire duplicate_request;
		
	wire[511:0] smi_writeback_data;	
	wire[25:0] smi_writeback_address;
	wire writeback_queue_empty;
	wire load_queue_empty;
	wire load_request_pending;
	wire writeback_pending = !writeback_queue_empty;
	reg writeback_complete = 0;
	wire writeback_queue_full;
	wire load_queue_full;

	assign load_request_pending = !load_queue_empty;

	localparam REQUEST_QUEUE_LENGTH = 12;
	localparam REQUEST_QUEUE_ADDR_WIDTH = $clog2(REQUEST_QUEUE_LENGTH);

	l2_cache_pending_miss l2_cache_pending_miss(/*AUTOINST*/
						    // Outputs
						    .duplicate_request	(duplicate_request),
						    // Inputs
						    .clk		(clk),
						    .rd_l2req_valid	(rd_l2req_valid),
						    .rd_l2req_address	(rd_l2req_address[25:0]),
						    .enqueue_load_request(enqueue_load_request),
						    .rd_has_sm_data	(rd_has_sm_data));

	sync_fifo #(538, REQUEST_QUEUE_LENGTH, REQUEST_QUEUE_ADDR_WIDTH) writeback_queue(
		.clk(clk),
		.flush_i(1'b0),
		.full_o(writeback_queue_full),
		.enqueue_i(enqueue_writeback_request && !writeback_queue_full),
		.value_i({
			writeback_address,	// Old address
			rd_cache_mem_result	// Old line to writeback
		}),
		.empty_o(writeback_queue_empty),
		.dequeue_i(writeback_complete),
		.value_o({
			smi_writeback_address,
			smi_writeback_data
		}));

	sync_fifo #(614, REQUEST_QUEUE_LENGTH, REQUEST_QUEUE_ADDR_WIDTH) load_queue(
		.clk(clk),
		.flush_i(1'b0),
		.full_o(load_queue_full),
		.enqueue_i(enqueue_load_request),
		.value_i(
			{ 
				duplicate_request,
				rd_replace_l2_way,			// which way to fill
				rd_l2req_unit,
				rd_l2req_strand,
				rd_l2req_op,
				rd_l2req_way,
				rd_l2req_address,
				rd_l2req_data,
				rd_l2req_mask
			}),
		.empty_o(load_queue_empty),
		.dequeue_i(smi_data_ready),
		.value_o(
			{ 
				smi_duplicate_request,
				smi_fill_l2_way,
				smi_l2req_unit,
				smi_l2req_strand,
				smi_l2req_op,
				smi_l2req_way,
				smi_l2req_address,
				smi_l2req_data,
				smi_l2req_mask
			}));

	localparam STATE_IDLE = 0;
	localparam STATE_WRITE_ISSUE_ADDRESS = 1;
	localparam STATE_WRITE_TRANSFER = 2;
	localparam STATE_READ_ISSUE_ADDRESS = 3;
	localparam STATE_READ_TRANSFER = 4;
	localparam STATE_READ_COMPLETE = 5;

	localparam BURST_LENGTH = 16;	// 4 bytes per transfer, cache line is 64 bytes

	assign axi_awlen = BURST_LENGTH - 1;
	assign axi_arlen = BURST_LENGTH - 1;
	assign axi_bready = 1'b1;

	reg[2:0] state_ff = 0;
	reg[2:0] state_nxt = 0;
	reg[3:0] burst_offset_ff = 0;
	reg[3:0] burst_offset_nxt = 0;
	reg[31:0] smi_load_buffer[0:15];
	assign smi_load_buffer_vec = {
		smi_load_buffer[0],
		smi_load_buffer[1],
		smi_load_buffer[2],
		smi_load_buffer[3],
		smi_load_buffer[4],
		smi_load_buffer[5],
		smi_load_buffer[6],
		smi_load_buffer[7],
		smi_load_buffer[8],
		smi_load_buffer[9],
		smi_load_buffer[10],
		smi_load_buffer[11],
		smi_load_buffer[12],
		smi_load_buffer[13],
		smi_load_buffer[14],
		smi_load_buffer[15]
	};

	assign axi_awaddr = { smi_writeback_address, 6'd0 };
	assign axi_araddr = { smi_l2req_address, 6'd0 };	

	// Write response state machine
	reg wait_axi_write_response = 0;
	always @(posedge clk)
	begin
		if (state_ff == STATE_WRITE_ISSUE_ADDRESS)
			wait_axi_write_response <= #1 1;
		else if (axi_bvalid)
			wait_axi_write_response <= #1 0;
	end

	always @*
	begin
		state_nxt = state_ff;
		smi_data_ready = 0;
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
				// where we load stale data.  In the normal case, writebacks
				// can only be initiated as the side effect of a load, so they 
				// can't starve them.  The flush instruction introduces a bit of a
				// wrinkle here, because they *can* starve loads.
				if (writeback_pending)
				begin
					if (!wait_axi_write_response)
						state_nxt = STATE_WRITE_ISSUE_ADDRESS;
				end
				else if (load_request_pending)
				begin
					if (smi_duplicate_request)
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
				smi_data_ready = 1'b1;
			end
		endcase
	end

	always @(posedge clk)
	begin
		if (state_ff == STATE_READ_TRANSFER && axi_rvalid)
			smi_load_buffer[burst_offset_ff] <= #1 axi_rdata;
	end

	lane_select_mux #(1) data_output_mux(
		.value_i(smi_writeback_data),
		.lane_select_i(burst_offset_ff),
		.value_o(axi_wdata));

	always @(posedge clk)
	begin
		state_ff <= #1 state_nxt;
		burst_offset_ff <= #1 burst_offset_nxt;
	end
endmodule
