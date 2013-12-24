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
	input                                    rd_l2req_valid,
	input [`CORE_INDEX_WIDTH - 1:0]          rd_l2req_core,
	input [1:0]                              rd_l2req_unit,
	input [`STRAND_INDEX_WIDTH - 1:0]        rd_l2req_strand,
	input [2:0]                              rd_l2req_op,
	input [1:0]                              rd_l2req_way,
	input [25:0]                             rd_l2req_address,
	input [`CACHE_LINE_BITS - 1:0]           rd_l2req_data,
	input [`CACHE_LINE_BYTES - 1:0]          rd_l2req_mask,
	input                                    rd_is_l2_fill,
	input [`CACHE_LINE_BITS - 1:0]           rd_data_from_memory,
	input [1:0]                              rd_hit_l2_way,
	input                                    rd_cache_hit,
	input [`NUM_CORES - 1:0]                 rd_l1_has_line,
	input [`NUM_CORES * 2 - 1:0]             rd_dir_l1_way,
	input [`CACHE_LINE_BITS - 1:0]           rd_cache_mem_result,
	input [1:0]                              rd_miss_fill_l2_way,
	input                                    rd_store_sync_success,

	// To l2_cache_rsp
	output reg                               wr_l2req_valid,
	output reg[`CORE_INDEX_WIDTH - 1:0]      wr_l2req_core,
	output reg[1:0]                          wr_l2req_unit,
	output reg[`STRAND_INDEX_WIDTH - 1:0]    wr_l2req_strand,
	output reg[2:0]                          wr_l2req_op,
	output reg[1:0]                          wr_l2req_way,
	output reg[25:0]                         wr_l2req_address,
	output reg                               wr_cache_hit,
	output reg[`CACHE_LINE_BITS - 1:0]       wr_data,
	output reg[`NUM_CORES - 1:0]             wr_l1_has_line,
	output reg[`NUM_CORES * 2 - 1:0]         wr_dir_l1_way,
	output reg                               wr_is_l2_fill,
	output reg                               wr_update_enable,
	output wire[`L2_CACHE_ADDR_WIDTH -1:0]   wr_cache_write_index,
	output reg[`CACHE_LINE_BITS - 1:0]       wr_update_data,
	output reg                               wr_store_sync_success);

	wire[`CACHE_LINE_BITS - 1:0] masked_write_data;
	reg[`CACHE_LINE_BITS - 1:0] old_cache_data;

	wire[`L2_SET_INDEX_WIDTH - 1:0] requested_l2_set = rd_l2req_address[`L2_SET_INDEX_WIDTH - 1:0];

	// - If this is a cache hit, use the old data in the line.
	// - If it is a restarted cache miss, use the data that was returned by the system
	//   memory interface.
	always @*
	begin
		if (rd_is_l2_fill)
			old_cache_data = rd_data_from_memory;
		else
			old_cache_data = rd_cache_mem_result;
	end

	// The mask determines which bytes are taken from the old cache line and
	// which are taken from the write.  If this is a synchronized store, we must
	// check if the transaction was successful and not update if not.  Note
	// that we still must update memory even if not successful, because this
	// may have been a cache fill.
	wire[`CACHE_LINE_BYTES - 1:0] update_mask = rd_l2req_op == `L2REQ_STORE_SYNC 
		? (rd_l2req_mask & {64{rd_store_sync_success}})
		: rd_l2req_mask;

	// Combine data here with the mask
	mask_unit mu[`CACHE_LINE_BYTES - 1:0] (
		.mask_i(update_mask), 
		.data0_i(old_cache_data), 
		.data1_i(rd_l2req_data), 
		.result_o(masked_write_data));

	// If this was a store cache hit, write back to the line that contains the data
	// If this is a cache miss, write back to the line we've chosen to contain the
	//  new data.
	assign wr_cache_write_index = rd_cache_hit
		? { rd_hit_l2_way, requested_l2_set }
		: { rd_miss_fill_l2_way, requested_l2_set };

	always @*
	begin
		if (rd_l2req_valid)
		begin
			if (rd_l2req_op == `L2REQ_STORE_SYNC && (rd_cache_hit || rd_is_l2_fill))
			begin
				// Synchronized store.  Note that we always update in this case,
				// but will clear the mask if the synchronized store was not successful,
				// we must update because this may be a cache miss fill.
				wr_update_data = masked_write_data;
				wr_update_enable = 1;
			end
			else if (rd_l2req_op == `L2REQ_STORE && (rd_cache_hit || rd_is_l2_fill))
			begin
				// Store hit or restart
				wr_update_data = masked_write_data;
				wr_update_enable = 1;
			end
			else if (rd_is_l2_fill)
			begin
				// This is a load.  This stashed the data from system memory into
				// the cache line.
				wr_update_data = rd_data_from_memory;
				wr_update_enable = 1;
			end
			else
			begin
				wr_update_data = 0;
				wr_update_enable = 0;
			end
		end
		else
		begin
			wr_update_data = 0;
			wr_update_enable = 0;
		end
	end

	always @(posedge clk, posedge reset)
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
			wr_l2req_address <= 26'h0;
			wr_l2req_core <= {(1+(`CORE_INDEX_WIDTH-1)){1'b0}};
			wr_l2req_op <= 3'h0;
			wr_l2req_strand <= {(1+(`STRAND_INDEX_WIDTH-1)){1'b0}};
			wr_l2req_unit <= 2'h0;
			wr_l2req_valid <= 1'h0;
			wr_l2req_way <= 2'h0;
			wr_store_sync_success <= 1'h0;
			// End of automatics
		end
		else
		begin
			wr_l2req_valid <= rd_l2req_valid;
			wr_l2req_core <= rd_l2req_core;
			wr_l2req_unit <= rd_l2req_unit;
			wr_l2req_strand <= rd_l2req_strand;
			wr_l2req_op <= rd_l2req_op;
			wr_l2req_way <= rd_l2req_way;
			wr_is_l2_fill <= rd_is_l2_fill;
			wr_l1_has_line <= rd_l1_has_line;
			wr_dir_l1_way <= rd_dir_l1_way;
			wr_cache_hit <= rd_cache_hit;
			wr_l2req_op <= rd_l2req_op;
			wr_l2req_address <= rd_l2req_address;
			wr_store_sync_success <= rd_store_sync_success;
			if (rd_l2req_op == `L2REQ_STORE || rd_l2req_op == `L2REQ_STORE_SYNC)
				wr_data <= masked_write_data;	// Store
			else
				wr_data <= old_cache_data;	// Load
		end
	end
endmodule
