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
// L2 cache pipeline directory stage.
//
//

module l2_cache_dir(
	input                            clk,
	input							 reset,
	input                            stall_pipeline,
	input                            tag_l2req_valid,
	input [3:0]                      tag_l2req_core,
	input [1:0]                      tag_l2req_unit,
	input [1:0]                      tag_l2req_strand,
	input [2:0]                      tag_l2req_op,
	input [1:0]                      tag_l2req_way,
	input [25:0]                     tag_l2req_address,
	input [511:0]                    tag_l2req_data,
	input [63:0]                     tag_l2req_mask,
	input                            tag_has_sm_data,
	input [511:0]                    tag_sm_data,
	input [1:0]                      tag_sm_fill_l2_way,
	input [1:0]                      tag_replace_l2_way,
	input [`L2_TAG_WIDTH - 1:0]      tag_l2_tag0,
	input [`L2_TAG_WIDTH - 1:0]      tag_l2_tag1,
	input [`L2_TAG_WIDTH - 1:0]      tag_l2_tag2,
	input [`L2_TAG_WIDTH - 1:0]      tag_l2_tag3,
	input                            tag_l2_valid0,
	input                            tag_l2_valid1,
	input                            tag_l2_valid2,
	input                            tag_l2_valid3,
	input                            tag_l1_has_line,
	input [`NUM_CORES * 2 - 1:0]     tag_l1_way,
	output reg                       dir_l2req_valid,
	output reg[3:0]                  dir_l2req_core,  
	output reg[1:0]                  dir_l2req_unit,
	output reg[1:0]                  dir_l2req_strand,
	output reg[2:0]                  dir_l2req_op,
	output reg[1:0]                  dir_l2req_way,
	output reg[25:0]                 dir_l2req_address,
	output reg[511:0]                dir_l2req_data,
	output reg[63:0]                 dir_l2req_mask,
	output reg                       dir_has_sm_data,
	output reg[511:0]                dir_sm_data,
	output reg[1:0]                  dir_sm_fill_way,
	output reg[1:0]                  dir_hit_l2_way,
	output reg[1:0]                  dir_replace_l2_way,
	output reg                       dir_cache_hit,
	output reg[`L2_TAG_WIDTH - 1:0]  dir_old_l2_tag,
	output reg                       dir_l1_has_line,
	output reg[`NUM_CORES * 2 - 1:0] dir_l1_way,
	output reg                       dir_l2_dirty0,
	output reg                       dir_l2_dirty1,
	output reg                       dir_l2_dirty2,
	output reg                       dir_l2_dirty3,
	output						 	 dir_update_tag_enable,
	output                           dir_update_tag_valid,
	output [`L2_TAG_WIDTH - 1:0]	 dir_update_tag_tag,
	output [`L2_SET_INDEX_WIDTH - 1:0] dir_update_tag_set,
	output [1:0] 					 dir_update_tag_way,
	output [`L2_SET_INDEX_WIDTH - 1:0] dir_update_dirty_set,
	output reg						 dir_new_dirty,
	input							 tag_l2_dirty0,
	input							 tag_l2_dirty1,
	input							 tag_l2_dirty2,
	input							 tag_l2_dirty3,
	output 							 dir_update_dirty0,
	output 							 dir_update_dirty1,
	output 							 dir_update_dirty2,
	output 							 dir_update_dirty3,
	output                           dir_update_directory0,
	output [1:0]                     dir_update_dir_way,
	output [`L1_TAG_WIDTH - 1:0]     dir_update_dir_tag, 
	output                           dir_update_dir_valid,
	output [`L1_SET_INDEX_WIDTH - 1:0] dir_update_dir_set);

	wire[`L1_TAG_WIDTH - 1:0] requested_l1_tag = tag_l2req_address[25:`L1_SET_INDEX_WIDTH];
	wire[`L1_SET_INDEX_WIDTH - 1:0] requested_l1_set = tag_l2req_address[`L1_SET_INDEX_WIDTH - 1:0];
	wire[`L2_TAG_WIDTH - 1:0] requested_l2_tag = tag_l2req_address[25:`L2_SET_INDEX_WIDTH];
	wire[`L2_SET_INDEX_WIDTH - 1:0] requested_l2_set = tag_l2req_address[`L2_SET_INDEX_WIDTH - 1:0];

	wire is_store = tag_l2req_op == `L2REQ_STORE || tag_l2req_op == `L2REQ_STORE_SYNC;
	wire is_flush = tag_l2req_op == `L2REQ_FLUSH;

	// Determine if there was a cache hit
	wire l2_hit0 = tag_l2_tag0 == requested_l2_tag && tag_l2_valid0;
	wire l2_hit1 = tag_l2_tag1 == requested_l2_tag && tag_l2_valid1;
	wire l2_hit2 = tag_l2_tag2 == requested_l2_tag && tag_l2_valid2;
	wire l2_hit3 = tag_l2_tag3 == requested_l2_tag && tag_l2_valid3;
	wire cache_hit = l2_hit0 || l2_hit1 || l2_hit2 || l2_hit3;
	wire[1:0] hit_l2_way = { l2_hit2 | l2_hit3, l2_hit1 | l2_hit3 }; // convert one-hot to index

	assert_false #("more than one way was a hit") a(.clk(clk), 
		.test(l2_hit0 + l2_hit1 + l2_hit2 + l2_hit3 > 1));

	reg[`L2_TAG_WIDTH - 1:0] old_l2_tag_muxed;

	always @*
	begin
		case (tag_has_sm_data ? tag_sm_fill_l2_way : hit_l2_way)
			0: old_l2_tag_muxed = tag_l2_tag0;
			1: old_l2_tag_muxed = tag_l2_tag1;
			2: old_l2_tag_muxed = tag_l2_tag2;
			3: old_l2_tag_muxed = tag_l2_tag3;
		endcase
	end

	// These signals go back to the tag stage to update L2 tag/valid bits.
	// We update when:
	//  - There is an invalidate command and the lookup in the last cycle
	//    showed the data is in the L2 cache.  We want to clear the valid
	//    bit for the appropriate line.
	//  - This is a restarted L2 cache miss.  We update the tag to show
	//    that there is now valid data in the cache.
	wire invalidate = tag_l2req_op == `L2REQ_INVALIDATE;
	assign dir_update_tag_enable = !stall_pipeline 
		&& (tag_has_sm_data || (invalidate && cache_hit));
	assign dir_update_tag_way = invalidate ? hit_l2_way : tag_sm_fill_l2_way;
	assign dir_update_tag_set = requested_l2_set;
	assign dir_update_tag_tag = requested_l2_tag;
	assign dir_update_tag_valid = !invalidate;

	assert_false #("invalidate and refill in same cycle") a0(.clk(clk),
		.test(tag_has_sm_data && invalidate));

	// These signals go back to the tag stage to update the directory of L1
	// data cache lines.  We update when:
	//  - If there an invalidate command and the lookup in the last cycle
	//    showed the data is in the L1 data cache.
	//  - This was an L1 data cache *load* miss.  Since we will be pushing a new
	//    line to the L1 cache track that now. Note that we don't do this
	//    for store misses because we do not write allocate.
	wire update_directory = !stall_pipeline
		&& tag_l2req_valid
		&& ((tag_l2req_op == `L2REQ_LOAD || tag_l2req_op == `L2REQ_LOAD_SYNC) 
		&& (cache_hit || tag_has_sm_data)
		&& tag_l2req_unit == `UNIT_DCACHE)
		|| (invalidate && tag_l1_has_line);
	assign dir_update_directory0 = update_directory && tag_l2req_core == 4'd0;
	assign dir_update_dir_way = tag_l2req_way;
	assign dir_update_dir_tag = requested_l1_tag;
	assign dir_update_dir_set = requested_l1_set;
	assign dir_update_dir_valid = !invalidate;

	// These signals go back to the tag stage to update dirty bits
	wire update_dirty = !stall_pipeline && tag_l2req_valid &&
		(tag_has_sm_data || (cache_hit && (is_store || is_flush)));
	assign dir_update_dirty0 = update_dirty && (tag_has_sm_data 
		? tag_sm_fill_l2_way == 0 : l2_hit0);
	assign dir_update_dirty1 = update_dirty && (tag_has_sm_data 
		? tag_sm_fill_l2_way == 1 : l2_hit1);
	assign dir_update_dirty2 = update_dirty && (tag_has_sm_data 
		? tag_sm_fill_l2_way == 2 : l2_hit2);
	assign dir_update_dirty3 = update_dirty && (tag_has_sm_data 
		? tag_sm_fill_l2_way == 3 : l2_hit3);

	always @*
	begin
		if (tag_has_sm_data)
			dir_new_dirty = is_store; // Line fill, mark dirty if a store is occurring.
		else if (is_flush)
			dir_new_dirty = 1'b0; // Clear dirty bit
		else
			dir_new_dirty = 1'b1; // Store, cache hit.  Set dirty.
	end
	
	assign dir_update_dirty_set = requested_l2_set;

	always @(posedge clk, posedge reset)
	begin
		if (reset)
		begin
			/*AUTORESET*/
			// Beginning of autoreset for uninitialized flops
			dir_cache_hit <= 1'h0;
			dir_has_sm_data <= 1'h0;
			dir_hit_l2_way <= 2'h0;
			dir_l1_has_line <= 1'h0;
			dir_l1_way <= {(1+(`NUM_CORES*2-1)){1'b0}};
			dir_l2_dirty0 <= 1'h0;
			dir_l2_dirty1 <= 1'h0;
			dir_l2_dirty2 <= 1'h0;
			dir_l2_dirty3 <= 1'h0;
			dir_l2req_address <= 26'h0;
			dir_l2req_core <= 4'h0;
			dir_l2req_data <= 512'h0;
			dir_l2req_mask <= 64'h0;
			dir_l2req_op <= 3'h0;
			dir_l2req_strand <= 2'h0;
			dir_l2req_unit <= 2'h0;
			dir_l2req_valid <= 1'h0;
			dir_l2req_way <= 2'h0;
			dir_old_l2_tag <= {(1+(`L2_TAG_WIDTH-1)){1'b0}};
			dir_replace_l2_way <= 2'h0;
			dir_sm_data <= 512'h0;
			dir_sm_fill_way <= 2'h0;
			// End of automatics
		end
		else if (!stall_pipeline)
		begin
			dir_l2req_valid <= tag_l2req_valid;
			dir_l2req_core <= tag_l2req_core;
			dir_l2req_unit <= tag_l2req_unit;
			dir_l2req_strand <= tag_l2req_strand;
			dir_l2req_op <= tag_l2req_op;
			dir_l2req_way <= tag_l2req_way;
			dir_l2req_address <= tag_l2req_address;
			dir_l2req_data <= tag_l2req_data;
			dir_l2req_mask <= tag_l2req_mask;
			dir_has_sm_data <= tag_has_sm_data;	
			dir_sm_data <= tag_sm_data;		
			dir_hit_l2_way <= hit_l2_way;
			dir_replace_l2_way <= tag_replace_l2_way;
			dir_cache_hit <= cache_hit;
			dir_old_l2_tag <= old_l2_tag_muxed;
			dir_sm_fill_way <= tag_sm_fill_l2_way;
			dir_l2_dirty0 <= tag_l2_dirty0 && tag_l2_valid0;
			dir_l2_dirty1 <= tag_l2_dirty1 && tag_l2_valid1;
			dir_l2_dirty2 <= tag_l2_dirty2 && tag_l2_valid2;
			dir_l2_dirty3 <= tag_l2_dirty3 && tag_l2_valid3;
			dir_l1_has_line <= tag_l1_has_line;
			dir_l1_way <= tag_l1_way;
		end
	end
endmodule
