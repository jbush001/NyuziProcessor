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
// L2 cache pipeline data read stage.
// This stage issues reads for cached data.  Since cache memory has one cycle of latency,
// the result will appear in the next pipeline stage.
//
//  - Track synchronized loads/stores
//  - Issue read data from L2 cache line 
//     Cache hit: requested line
//     Cache miss, dirty line: line that will be written back
//

module l2_cache_read(
	input						clk,
	input						reset,
	input						stall_pipeline,
	input [3:0]					dir_l2req_core,
	input						dir_l2req_valid,
	input [1:0]					dir_l2req_unit,
	input [1:0]					dir_l2req_strand,
	input [2:0]					dir_l2req_op,
	input [1:0]					dir_l2req_way,
	input [25:0]				dir_l2req_address,
	input [511:0]				dir_l2req_data,
	input [63:0]				dir_l2req_mask,
	input						dir_is_l2_fill,
	input [511:0]				dir_data_from_memory,
	input [1:0] 				dir_hit_l2_way,
	input  						dir_cache_hit,
	input [`L2_TAG_WIDTH - 1:0] dir_old_l2_tag,
	input [`NUM_CORES - 1:0]	dir_l1_has_line,
	input [`NUM_CORES * 2 - 1:0] dir_l1_way,
	input 						dir_l2_dirty0,	// Note: these imply that the dirty line is also valid
	input 						dir_l2_dirty1,
	input 						dir_l2_dirty2,
	input 						dir_l2_dirty3,
	input [1:0]					dir_miss_fill_l2_way,
	input 						wr_update_enable,
	input [`L2_CACHE_ADDR_WIDTH -1:0] wr_cache_write_index,
	input[511:0] 				wr_update_data,

	output reg					rd_l2req_valid,
	output reg[3:0]				rd_l2req_core,
	output reg[1:0]				rd_l2req_unit,
	output reg[1:0]				rd_l2req_strand,
	output reg[2:0]				rd_l2req_op,
	output reg[1:0]				rd_l2req_way,
	output reg[25:0]			rd_l2req_address,
	output reg[511:0]			rd_l2req_data,
	output reg[63:0]			rd_l2req_mask,
	output reg 					rd_is_l2_fill,
	output reg[511:0] 			rd_data_from_memory,
	output reg[1:0]				rd_miss_fill_l2_way,
	output reg[1:0] 			rd_hit_l2_way,
	output reg 					rd_cache_hit,
	output reg[`NUM_CORES - 1:0] rd_l1_has_line,
	output reg[`NUM_CORES * 2 - 1:0] rd_dir_l1_way,
	output [511:0] 				rd_cache_mem_result,
	output reg[`L2_TAG_WIDTH - 1:0] rd_old_l2_tag,
	output reg 					rd_line_is_dirty,
	output reg                  rd_store_sync_success);

	wire[`L2_SET_INDEX_WIDTH - 1:0] requested_l2_set = dir_l2req_address[`L2_SET_INDEX_WIDTH - 1:0];

	// Determine which line we should read.
	// - If this is a cache fill and we need to write back a dirty line, read the
	//   old value here, which will be sent to the SMI stage to store into main memory.
	// - If this is a cache hit, read the existing value of the line.  For stores,
	//    we wil use a mask to combine the new data with the old data.  For loads,
	//    we will return this value.
	wire[`L2_CACHE_ADDR_WIDTH - 1:0] cache_read_index = dir_cache_hit
		? { dir_hit_l2_way, requested_l2_set }
		: { dir_miss_fill_l2_way, requested_l2_set }; // Get data from a (potentially) dirty line that is about to be replaced.

	sram_1r1w #(512, `L2_NUM_SETS * `L2_NUM_WAYS) cache_mem(
		.clk(clk),
		.reset(reset),
		.rd_addr(cache_read_index),
		.rd_data(rd_cache_mem_result),
		.rd_enable(dir_l2req_valid && (dir_cache_hit || dir_is_l2_fill)),
		.wr_addr(wr_cache_write_index),
		.wr_data(wr_update_data),
		.wr_enable(wr_update_enable && !stall_pipeline));
		
	// Determine if the line is dirty and whether we need to do a writeback.
	// - If this is a flush, we check dirty bits on the way that was a cache hit.
	// - If we are replacing a line, we check dirty bits on the way that is being
	//   replaced.
	reg line_is_dirty_muxed;
	always @*
	begin
		case (dir_l2req_op == `L2REQ_FLUSH ? dir_hit_l2_way : dir_miss_fill_l2_way)
			0: line_is_dirty_muxed = dir_l2_dirty0;
			1: line_is_dirty_muxed = dir_l2_dirty1;
			2: line_is_dirty_muxed = dir_l2_dirty2;
			3: line_is_dirty_muxed = dir_l2_dirty3;
		endcase
	end
	
	// Track synchronized load/stores, and determine if a synchronized store
	// was successful.
	localparam TOTAL_STRANDS = `NUM_CORES * `STRANDS_PER_CORE;

	reg[25:0] sync_load_address[0:TOTAL_STRANDS - 1]; 
	reg sync_load_address_valid[0:TOTAL_STRANDS - 1];

	wire can_store_sync = sync_load_address[{ dir_l2req_core, dir_l2req_strand}] == dir_l2req_address
		&& sync_load_address_valid[{ dir_l2req_core, dir_l2req_strand}]
		&& dir_l2req_op == `L2REQ_STORE_SYNC;

	integer i;
	integer k;
	
	always @(posedge clk, posedge reset)
	begin
		if (reset)
		begin
			for (i = 0; i < TOTAL_STRANDS; i = i + 1)
			begin
				sync_load_address[i] <= 26'h0000000;	
				sync_load_address_valid[i] <= 0;
			end

			/*AUTORESET*/
			// Beginning of autoreset for uninitialized flops
			rd_cache_hit <= 1'h0;
			rd_data_from_memory <= 512'h0;
			rd_dir_l1_way <= {(1+(`NUM_CORES*2-1)){1'b0}};
			rd_hit_l2_way <= 2'h0;
			rd_is_l2_fill <= 1'h0;
			rd_l1_has_line <= {(1+(`NUM_CORES-1)){1'b0}};
			rd_l2req_address <= 26'h0;
			rd_l2req_core <= 4'h0;
			rd_l2req_data <= 512'h0;
			rd_l2req_mask <= 64'h0;
			rd_l2req_op <= 3'h0;
			rd_l2req_strand <= 2'h0;
			rd_l2req_unit <= 2'h0;
			rd_l2req_valid <= 1'h0;
			rd_l2req_way <= 2'h0;
			rd_line_is_dirty <= 1'h0;
			rd_miss_fill_l2_way <= 2'h0;
			rd_old_l2_tag <= {(1+(`L2_TAG_WIDTH-1)){1'b0}};
			rd_store_sync_success <= 1'h0;
			// End of automatics
		end
		else if (!stall_pipeline)
		begin
			rd_l2req_valid <= dir_l2req_valid;
			rd_l2req_unit <= dir_l2req_unit;
			rd_l2req_strand <= dir_l2req_strand;
			rd_l2req_op <= dir_l2req_op;
			rd_l2req_way <= dir_l2req_way;
			rd_l2req_address <= dir_l2req_address;
			rd_l2req_data <= dir_l2req_data;
			rd_l2req_mask <= dir_l2req_mask;
			rd_is_l2_fill <= dir_is_l2_fill;	
			rd_data_from_memory <= dir_data_from_memory;	
			rd_hit_l2_way <= dir_hit_l2_way;
			rd_cache_hit <= dir_cache_hit;
			rd_l1_has_line <= dir_l1_has_line;
			rd_dir_l1_way <= dir_l1_way;
			rd_old_l2_tag <= dir_old_l2_tag;
			rd_line_is_dirty <= line_is_dirty_muxed;
			rd_miss_fill_l2_way <= dir_miss_fill_l2_way;
			rd_l2req_core <= dir_l2req_core;

			if (dir_l2req_valid && (dir_cache_hit || dir_is_l2_fill))
			begin
				case (dir_l2req_op)
					`L2REQ_LOAD_SYNC:
					begin
						sync_load_address[{ dir_l2req_core, dir_l2req_strand}] <= dir_l2req_address;
						sync_load_address_valid[{ dir_l2req_core, dir_l2req_strand}] <= 1;
					end
		
					`L2REQ_STORE,
					`L2REQ_STORE_SYNC:
					begin
						// Note that we don't invalidate if the sync store is 
						// not successful.  Otherwise strands can livelock.
						if (dir_l2req_op == `L2REQ_STORE || can_store_sync)
						begin
							// Invalidate
							for (k = 0; k < TOTAL_STRANDS; k = k + 1)
							begin
								if (sync_load_address[k] == dir_l2req_address)
									sync_load_address_valid[k] <= 0;
							end
						end
					end

					default:
						;
				endcase

				rd_store_sync_success <= can_store_sync;
			end
			else
				rd_store_sync_success <= 0;
		end
	end	
endmodule
