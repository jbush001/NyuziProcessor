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
// L2 cache data write stage.
// Sets signals to write data back into cache memory.
//
// For stores, combine the requested write data with the previous data in the line.  
// Otherwise just pass data through.
//

module l2_cache_write(
	input                                    clk,
	input                                    reset,
	
	// From l2_cache_read
	input l2req_packet_t                     rd_l2req_packet,
	input                                    rd_is_l2_fill,
	input [`CACHE_LINE_BITS - 1:0]           rd_data_from_memory,
	input [1:0]                              rd_hit_l2_way,
	input                                    rd_cache_hit,
	input [`NUM_CORES - 1:0]                 rd_l1_has_line,
	input [`NUM_CORES * 2 - 1:0]             rd_dir_l1_way,
	input [`CACHE_LINE_BITS - 1:0]           rd_cache_mem_result,
	input [1:0]                              rd_miss_fill_l2_way,
	input                                    rd_store_sync_success,
	input [`L2_CACHE_ADDR_WIDTH - 1:0]       rd_cache_index,

	// To l2_cache_rsp
	output l2req_packet_t                    wr_l2req_packet,
	output logic                             wr_cache_hit,
	output logic[`CACHE_LINE_BITS - 1:0]     wr_data,
	output logic[`NUM_CORES - 1:0]           wr_l1_has_line,
	output logic[`NUM_CORES * 2 - 1:0]       wr_dir_l1_way,
	output logic                             wr_is_l2_fill,
	output                                   wr_update_enable,
	output logic[`L2_CACHE_ADDR_WIDTH -1:0]  wr_cache_write_index,
	output [`CACHE_LINE_BITS - 1:0]          wr_update_data,
	output logic                             wr_store_sync_success);

	wire[`L2_SET_INDEX_WIDTH - 1:0] requested_l2_set = rd_l2req_packet.address[`L2_SET_INDEX_WIDTH - 1:0];

	// - If this is a cache hit, use the old data in the line.
	// - If it is a restarted cache miss, use the data that was returned by the system
	//   memory interface.
	wire[`CACHE_LINE_BITS - 1:0]  old_cache_data = rd_is_l2_fill 
		? rd_data_from_memory 
		: rd_cache_mem_result;

	// The mask determines which bytes are taken from the old cache line and
	// which are taken from the write (a 1 indicates the latter).  If this is a 
	// synchronized store, we must check if the transaction was successful and not 
	// update if not.  Note that we still must update memory even if a synchronized store
	// is not successful, because this may have been a cache fill.  If this is a load,
	// just set the mask to zero, since there is no store data.
	logic[`CACHE_LINE_BYTES - 1:0] store_mask;

	always_comb
	begin
		unique case (rd_l2req_packet.op)
			L2REQ_STORE_SYNC: store_mask = rd_l2req_packet.mask & {`CACHE_LINE_BYTES{rd_store_sync_success}};
			L2REQ_STORE: store_mask = rd_l2req_packet.mask;
			default: store_mask = {`CACHE_LINE_BYTES{1'b0}};
		endcase
	end

	// Combine store data here with the mask
	logic[`CACHE_LINE_BITS - 1:0] masked_write_data;

	mask_unit mask_unit[`CACHE_LINE_BYTES - 1:0] (
		.mask_i(store_mask), 
		.data0_i(old_cache_data), 
		.data1_i(rd_l2req_packet.data), 
		.result_o(masked_write_data));

	assign wr_update_data = masked_write_data;
	assign wr_update_enable = rd_l2req_packet.valid && (rd_is_l2_fill 
		|| ((rd_l2req_packet.op == L2REQ_STORE || rd_l2req_packet.op == L2REQ_STORE_SYNC) && rd_cache_hit));

	// In cases where we write back, it's always to the line that was just read.
	assign wr_cache_write_index = rd_cache_index;

	always_ff @(posedge clk, posedge reset)
	begin
		if (reset)
		begin
			/*AUTORESET*/
			// Beginning of autoreset for uninitialized flops
			wr_cache_hit <= 1'h0;
			wr_data <= {(1+(`CACHE_LINE_BITS-1)){1'b0}};
			wr_dir_l1_way <= {(1+(`NUM_CORES*2-1)){1'b0}};
			wr_is_l2_fill <= 1'h0;
			wr_l1_has_line <= {(1+(`NUM_CORES-1)){1'b0}};
			wr_l2req_packet <= 1'h0;
			wr_store_sync_success <= 1'h0;
			// End of automatics
		end
		else
		begin
			wr_l2req_packet <= rd_l2req_packet;
			wr_is_l2_fill <= rd_is_l2_fill;
			wr_l1_has_line <= rd_l1_has_line;
			wr_dir_l1_way <= rd_dir_l1_way;
			wr_cache_hit <= rd_cache_hit;
			wr_store_sync_success <= rd_store_sync_success;
			wr_data <= masked_write_data;
		end
	end
endmodule

// Local Variables:
// verilog-typedef-regexp:"_t$"
// End:
