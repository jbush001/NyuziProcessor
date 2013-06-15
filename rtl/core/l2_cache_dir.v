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
// L2 cache pipeline directory stage.  The name is a bit of a holdover
// from a previous implementation.  It may be able to merge with the read stage,
// but need to understand how that would affect timing.
// 
// This interprets the results from the tag stage and forwards them on to the read 
// stage (for example, which way was a hit).  It sets control signals
// to update results. 
//

module l2_cache_dir(
	input                            clk,
	input							 reset,
	input                            stall_pipeline,
	input                            tag_l2req_valid,
	input [`CORE_INDEX_WIDTH - 1:0]  tag_l2req_core,
	input [1:0]                      tag_l2req_unit,
	input [`STRAND_INDEX_WIDTH - 1:0] tag_l2req_strand,
	input [2:0]                      tag_l2req_op,
	input [1:0]                      tag_l2req_way,
	input [25:0]                     tag_l2req_address,
	input [511:0]                    tag_l2req_data,
	input [63:0]                     tag_l2req_mask,
	input                            tag_is_restarted_request,
	input [511:0]                    tag_data_from_memory,
	input [1:0]                      tag_miss_fill_l2_way,
	input [`L2_TAG_WIDTH * `L2_NUM_WAYS - 1:0] tag_l2_tag,
	input  [`L2_NUM_WAYS - 1:0]      tag_l2_valid,
	input [`L2_NUM_WAYS - 1:0]		 tag_l2_dirty,
	input [`NUM_CORES - 1:0]         tag_l1_has_line,
	input [`NUM_CORES * 2 - 1:0]     tag_l1_way,
	output reg                       dir_l2req_valid,
	output reg[`CORE_INDEX_WIDTH - 1:0] dir_l2req_core,  
	output reg[1:0]                  dir_l2req_unit,
	output reg[`STRAND_INDEX_WIDTH - 1:0] dir_l2req_strand,
	output reg[2:0]                  dir_l2req_op,
	output reg[1:0]                  dir_l2req_way,
	output reg[25:0]                 dir_l2req_address,
	output reg[511:0]                dir_l2req_data,
	output reg[63:0]                 dir_l2req_mask,
	output reg                       dir_is_l2_fill,
	output reg[511:0]                dir_data_from_memory,
	output reg[1:0]                  dir_miss_fill_l2_way,
	output reg[1:0]                  dir_hit_l2_way,
	output reg                       dir_cache_hit,
	output reg[`L2_TAG_WIDTH - 1:0]  dir_old_l2_tag,
	output reg[`NUM_CORES - 1:0]     dir_l1_has_line,
	output reg[`NUM_CORES * 2 - 1:0] dir_l1_way,
	output reg[`STRANDS_PER_CORE - 1:0] dir_l2_dirty,
	output						 	 dir_update_tag_enable,
	output                           dir_update_tag_valid,
	output [`L2_TAG_WIDTH - 1:0]	 dir_update_tag_tag,
	output [`L2_SET_INDEX_WIDTH - 1:0] dir_update_tag_set,
	output [1:0] 					 dir_update_tag_way,
	output [`L2_SET_INDEX_WIDTH - 1:0] dir_update_dirty_set,
	output reg						 dir_new_dirty,
	output [`L2_NUM_WAYS - 1:0]		 dir_update_dirty,
	output                           dir_update_directory,
	output [1:0]                     dir_update_dir_way,
	output [`L1_TAG_WIDTH - 1:0]     dir_update_dir_tag, 
	output                           dir_update_dir_valid,
	output [`CORE_INDEX_WIDTH - 1:0] dir_update_dir_core,
	output [`L1_SET_INDEX_WIDTH - 1:0] dir_update_dir_set,
	output reg                       pc_event_l2_hit,
	output reg                       pc_event_l2_miss);

	wire[`L1_TAG_WIDTH - 1:0] requested_l1_tag = tag_l2req_address[25:`L1_SET_INDEX_WIDTH];
	wire[`L1_SET_INDEX_WIDTH - 1:0] requested_l1_set = tag_l2req_address[`L1_SET_INDEX_WIDTH - 1:0];
	wire[`L2_TAG_WIDTH - 1:0] requested_l2_tag = tag_l2req_address[25:`L2_SET_INDEX_WIDTH];
	wire[`L2_SET_INDEX_WIDTH - 1:0] requested_l2_set = tag_l2req_address[`L2_SET_INDEX_WIDTH - 1:0];

	wire is_store = tag_l2req_op == `L2REQ_STORE || tag_l2req_op == `L2REQ_STORE_SYNC;
	wire is_flush = tag_l2req_op == `L2REQ_FLUSH;

	// Determine if there was a cache hit and which way contains the data
	wire l2_hit0 = tag_l2_tag[`L2_TAG_WIDTH - 1:0] == requested_l2_tag && tag_l2_valid[0];
	wire l2_hit1 = tag_l2_tag[`L2_TAG_WIDTH * 2 - 1:`L2_TAG_WIDTH] == requested_l2_tag && tag_l2_valid[1];
	wire l2_hit2 = tag_l2_tag[`L2_TAG_WIDTH * 3 - 1:`L2_TAG_WIDTH * 2] == requested_l2_tag && tag_l2_valid[2];
	wire l2_hit3 = tag_l2_tag[`L2_TAG_WIDTH * 4 - 1:`L2_TAG_WIDTH * 3] == requested_l2_tag && tag_l2_valid[3];
	wire cache_hit = l2_hit0 || l2_hit1 || l2_hit2 || l2_hit3;
	wire[1:0] hit_l2_way = { l2_hit2 | l2_hit3, l2_hit1 | l2_hit3 }; // convert one-hot to index

	assert_false #("more than one way was a hit") a(.clk(clk), 
		.test(l2_hit0 + l2_hit1 + l2_hit2 + l2_hit3 > 1));

	// Note here: a restarted request is a fill, but also, if we get a cache
	// miss on a store with all the mask bits, also treat this as a fill.
	// There is no reason to fetch this data from system memory since we're just
	// going to overwrite it anyway.
	wire is_l2_fill = tag_is_restarted_request || (tag_l2req_op == `L2REQ_STORE
		&& tag_l2req_mask == 64'hffffffffffffffff && !cache_hit);

	// If we have replaced a line, record the address of the old line that 
	// we need to write back.
	reg[`L2_TAG_WIDTH - 1:0] old_l2_tag_muxed;

	always @*
	begin
		case (is_l2_fill ? tag_miss_fill_l2_way : hit_l2_way)
			0: old_l2_tag_muxed = tag_l2_tag[`L2_TAG_WIDTH - 1:0];
			1: old_l2_tag_muxed = tag_l2_tag[`L2_TAG_WIDTH * 2 - 1:`L2_TAG_WIDTH];
			2: old_l2_tag_muxed = tag_l2_tag[`L2_TAG_WIDTH * 3 - 1:`L2_TAG_WIDTH * 2];
			3: old_l2_tag_muxed = tag_l2_tag[`L2_TAG_WIDTH * 4 - 1:`L2_TAG_WIDTH * 3];
		endcase
	end

	// These signals go back to the tag stage to update L2 tag/valid bits.
	// We update when:
	//  - There is an invalidate command and the lookup in the last cycle
	//    showed the data is in the L2 cache.  We want to clear the valid
	//    bit for the appropriate line.
	//  - This is a restarted L2 cache miss.  We update the tag to show
	//    that there is now valid data in the cache.
	wire invalidate = tag_l2req_op == `L2REQ_DINVALIDATE;
	assign dir_update_tag_enable = tag_l2req_valid && !stall_pipeline 
		&& (is_l2_fill || (invalidate && cache_hit));
	assign dir_update_tag_way = invalidate ? hit_l2_way : tag_miss_fill_l2_way;
	assign dir_update_tag_set = requested_l2_set;
	assign dir_update_tag_tag = requested_l2_tag;
	assign dir_update_tag_valid = !invalidate;

	assert_false #("invalidate and refill in same cycle") a0(.clk(clk),
		.test(is_l2_fill && invalidate));

	// These signals go back to the tag stage to update the directory of L1
	// data cache lines.  We update when:
	//  - If there an invalidate command and the lookup in the last cycle
	//    showed the data is in the L1 data cache.
	//  - This was an L1 data cache *load* miss.  Since we will be pushing a new
	//    line to the L1 cache track that now. Note that we don't do this
	//    for store misses because we do not write allocate for the L1 data
	//    cache.
	assign dir_update_directory = !stall_pipeline
		&& tag_l2req_valid
		&& ((tag_l2req_op == `L2REQ_LOAD || tag_l2req_op == `L2REQ_LOAD_SYNC) 
		&& (cache_hit || is_l2_fill)
		&& tag_l2req_unit == `UNIT_DCACHE)
		|| (invalidate && tag_l1_has_line[tag_l2req_core]);

	assign dir_update_dir_way = invalidate ? tag_l1_way : tag_l2req_way;
	assign dir_update_dir_tag = requested_l1_tag;
	assign dir_update_dir_set = requested_l1_set;
	assign dir_update_dir_valid = !invalidate;
	assign dir_update_dir_core = tag_l2req_core;

	// These signals go back to the tag stage to update dirty bits
	wire update_dirty = !stall_pipeline && tag_l2req_valid &&
		(is_l2_fill || (cache_hit && (is_store || is_flush)));
	assign dir_update_dirty[0] = update_dirty && (is_l2_fill 
		? tag_miss_fill_l2_way == 0 : l2_hit0);
	assign dir_update_dirty[1] = update_dirty && (is_l2_fill 
		? tag_miss_fill_l2_way == 1 : l2_hit1);
	assign dir_update_dirty[2] = update_dirty && (is_l2_fill 
		? tag_miss_fill_l2_way == 2 : l2_hit2);
	assign dir_update_dirty[3] = update_dirty && (is_l2_fill 
		? tag_miss_fill_l2_way == 3 : l2_hit3);

	always @*
	begin
		if (is_l2_fill)
			dir_new_dirty = is_store; // Line fill, mark dirty if a store is occurring.
		else if (is_flush)
			dir_new_dirty = 1'b0; // Clear dirty bit
		else
			dir_new_dirty = 1'b1; // Store, cache hit.  Set dirty.
	end
	
	assign dir_update_dirty_set = requested_l2_set;

	// Performance counte revents
	always @*
	begin
		pc_event_l2_hit = 0;
		pc_event_l2_miss = 0;
	
		// Update statistics on first pass of a packet through the pipeline.
		// Note that a block store miss that fills the entire line is still
		// treated as a cache miss, even though it does not need to load
		// data from main memory.  It may be useful to count this separately
		// at some point.
		if (tag_l2req_valid && !tag_is_restarted_request 
			&& (tag_l2req_op == `L2REQ_LOAD
			|| tag_l2req_op == `L2REQ_STORE || tag_l2req_op == `L2REQ_LOAD_SYNC
			|| tag_l2req_op == `L2REQ_STORE_SYNC) && !stall_pipeline)
		begin
			if (cache_hit)		
				pc_event_l2_hit = 1;
			else
				pc_event_l2_miss = 1;
		end
	end

	always @(posedge clk, posedge reset)
	begin
		if (reset)
		begin
			/*AUTORESET*/
			// Beginning of autoreset for uninitialized flops
			dir_cache_hit <= 1'h0;
			dir_data_from_memory <= 512'h0;
			dir_hit_l2_way <= 2'h0;
			dir_is_l2_fill <= 1'h0;
			dir_l1_has_line <= {(1+(`NUM_CORES-1)){1'b0}};
			dir_l1_way <= {(1+(`NUM_CORES*2-1)){1'b0}};
			dir_l2_dirty <= {(1+(`STRANDS_PER_CORE-1)){1'b0}};
			dir_l2req_address <= 26'h0;
			dir_l2req_core <= {(1+(`CORE_INDEX_WIDTH-1)){1'b0}};
			dir_l2req_data <= 512'h0;
			dir_l2req_mask <= 64'h0;
			dir_l2req_op <= 3'h0;
			dir_l2req_strand <= {(1+(`STRAND_INDEX_WIDTH-1)){1'b0}};
			dir_l2req_unit <= 2'h0;
			dir_l2req_valid <= 1'h0;
			dir_l2req_way <= 2'h0;
			dir_miss_fill_l2_way <= 2'h0;
			dir_old_l2_tag <= {(1+(`L2_TAG_WIDTH-1)){1'b0}};
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
			dir_is_l2_fill <= is_l2_fill;	
			dir_data_from_memory <= tag_data_from_memory;		
			dir_hit_l2_way <= hit_l2_way;
			dir_cache_hit <= cache_hit;
			dir_old_l2_tag <= old_l2_tag_muxed;
			dir_miss_fill_l2_way <= tag_miss_fill_l2_way;
			dir_l2_dirty <= tag_l2_dirty & tag_l2_valid;
			dir_l1_has_line <= tag_l1_has_line;
			dir_l1_way <= tag_l1_way;
		end
	end
endmodule
