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
// L2 cache data write issue stage.
//
// For stores, combine the requested write data with the previous data in the line.  
// Otherwise just pass data through.
//

module l2_cache_write(
	input                      clk,
	input                      stall_pipeline,
	input 			           rd_l2req_valid,
	input [1:0]	               rd_l2req_unit,
	input [1:0]	               rd_l2req_strand,
	input [2:0]	               rd_l2req_op,
	input [1:0]	               rd_l2req_way,
	input [25:0]               rd_l2req_address,
	input [511:0]              rd_l2req_data,
	input [63:0]               rd_l2req_mask,
	input                      rd_has_sm_data,
	input [511:0]              rd_sm_data,
	input [1:0]                rd_hit_l2_way,
	input                      rd_cache_hit,
	input [`NUM_CORES - 1:0]   rd_l1_has_line,
	input [`NUM_CORES * 2 - 1:0] rd_dir_l1_way,
	input [511:0]              rd_cache_mem_result,
	input [1:0]                rd_sm_fill_l2_way,
	input                      rd_store_sync_success,
	output reg                 wr_l2req_valid = 0,
	output reg[1:0]	           wr_l2req_unit = 0,
	output reg[1:0]	           wr_l2req_strand = 0,
	output reg[2:0]	           wr_l2req_op = 0,
	output reg[1:0]	           wr_l2req_way = 0,
	output reg                 wr_cache_hit = 0,
	output reg[511:0]          wr_data = 0,
	output reg[`NUM_CORES - 1:0] wr_l1_has_line = 0,
	output reg[`NUM_CORES * 2 - 1:0] wr_dir_l1_way = 0,
	output reg                 wr_has_sm_data = 0,
	output reg                 wr_update_l2_data = 0,
	output wire[`L2_CACHE_ADDR_WIDTH -1:0] wr_cache_write_index,
	output reg[511:0]          wr_update_data = 0,
	output reg                 wr_store_sync_success = 0);

	wire[511:0] masked_write_data;
	reg[511:0] old_cache_data = 0;

	wire[`L2_SET_INDEX_WIDTH - 1:0] requested_l2_set = rd_l2req_address[`L2_SET_INDEX_WIDTH - 1:0];

	always @*
	begin
		if (rd_has_sm_data)
			old_cache_data = rd_sm_data;
		else
			old_cache_data = rd_cache_mem_result;
	end

	mask_unit mu(
		.mask_i(rd_l2req_mask), 
		.data0_i(old_cache_data), 
		.data1_i(rd_l2req_data), 
		.result_o(masked_write_data));

	always @(posedge clk)
	begin
		if (!stall_pipeline)
		begin
			wr_l2req_valid <= #1 rd_l2req_valid;
			wr_l2req_unit <= #1 rd_l2req_unit;
			wr_l2req_strand <= #1 rd_l2req_strand;
			wr_l2req_op <= #1 rd_l2req_op;
			wr_l2req_way <= #1 rd_l2req_way;
			wr_has_sm_data <= #1 rd_has_sm_data;
			wr_l1_has_line <= #1 rd_l1_has_line;
			wr_dir_l1_way <= #1 rd_dir_l1_way;
			wr_cache_hit <= #1 rd_cache_hit;
			wr_l2req_op <= #1 rd_l2req_op;
			wr_store_sync_success <= #1 rd_store_sync_success;
			if (rd_l2req_op == `L2REQ_STORE || rd_l2req_op == `L2REQ_STORE_SYNC)
				wr_data <= #1 masked_write_data;	// Store
			else
				wr_data <= #1 old_cache_data;	// Load
		end
	end
	
	assign wr_cache_write_index = rd_cache_hit
		? { rd_hit_l2_way, requested_l2_set }
		: { rd_sm_fill_l2_way, requested_l2_set };

	always @*
	begin
		if (rd_l2req_valid)
		begin
			if (rd_l2req_op == `L2REQ_STORE_SYNC && (rd_cache_hit || rd_has_sm_data))
			begin
				if (rd_store_sync_success)
				begin
					// Synchronized store.  rd_store_sync_success indicates the 
					// line has not been updated since the last synchronized load.
					wr_update_data = masked_write_data;
					wr_update_l2_data = 1;
				end
				else
				begin
					// Don't store anything.
					wr_update_data = 0;
					wr_update_l2_data = 0;
				end
			end
			else if (rd_l2req_op == `L2REQ_STORE && (rd_cache_hit || rd_has_sm_data))
			begin
				// Store hit or restart
				wr_update_data = masked_write_data;
				wr_update_l2_data = 1;
			end
			else if (rd_has_sm_data)
			begin
				// This is a load.  This stashed the data from system memory into
				// the cache line.
				wr_update_data = rd_sm_data;
				wr_update_l2_data = 1;
			end
			else
			begin
				wr_update_data = 0;
				wr_update_l2_data = 0;
			end
		end
		else
		begin
			wr_update_data = 0;
			wr_update_l2_data = 0;
		end
	end
endmodule
