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
	input                                   clk,
	input                                   reset,
	input l2req_packet_t                    dir_l2req_packet,
	input                                   dir_is_l2_fill,
	input [`CACHE_LINE_BITS - 1:0]          dir_data_from_memory,
	input [1:0]                             dir_hit_l2_way,
	input                                   dir_cache_hit,
	input [`L2_TAG_WIDTH - 1:0]             dir_old_l2_tag,
	input [`NUM_CORES - 1:0]                dir_l1_has_line,
	input [`NUM_CORES * 2 - 1:0]            dir_l1_way,
	input [`STRANDS_PER_CORE - 1:0]         dir_l2_dirty,	// Note: these imply that the dirty line is also valid
	input [1:0]                             dir_miss_fill_l2_way,
	input                                   wr_update_enable,
	input [`L2_CACHE_ADDR_WIDTH -1:0]       wr_cache_write_index,
	input[`CACHE_LINE_BITS - 1:0]           wr_update_data,

	output l2req_packet_t                   rd_l2req_packet,
	output logic                            rd_is_l2_fill,
	output logic[`CACHE_LINE_BITS - 1:0]    rd_data_from_memory,
	output logic[1:0]                       rd_miss_fill_l2_way,
	output logic[1:0]                       rd_hit_l2_way,
	output logic                            rd_cache_hit,
	output logic[`NUM_CORES - 1:0]          rd_l1_has_line,
	output logic[`NUM_CORES * 2 - 1:0]      rd_dir_l1_way,
	output [`CACHE_LINE_BITS - 1:0]         rd_cache_mem_result,
	output logic[`L2_TAG_WIDTH - 1:0]       rd_old_l2_tag,
	output logic                            rd_line_is_dirty,
	output logic                            rd_store_sync_success);

	wire[`L2_SET_INDEX_WIDTH - 1:0] requested_l2_set = dir_l2req_packet.address[`L2_SET_INDEX_WIDTH - 1:0];

	// Determine which line we should read.
	// - If this is a cache fill and we need to write back a dirty line, read the
	//   old value here, which will be sent to the SMI stage to store into main memory.
	// - If this is a cache hit, read the existing value of the line. For stores,
	//    we wil use a mask to combine the new data with the old data. For loads,
	//    we will return this value.
	wire[`L2_CACHE_ADDR_WIDTH - 1:0] cache_read_index = dir_is_l2_fill
		? { dir_miss_fill_l2_way, requested_l2_set } // Get data from a (potentially) dirty line that is about to be replaced.
		: { dir_hit_l2_way, requested_l2_set }; 

	sram_1r1w #(.DATA_WIDTH(512), .SIZE(`L2_NUM_SETS * `L2_NUM_WAYS)) cache_mem(
		.clk(clk),
		.rd_addr(cache_read_index),
		.rd_data(rd_cache_mem_result),
		.rd_enable(dir_l2req_packet.valid && (dir_cache_hit || dir_is_l2_fill)),
		.wr_addr(wr_cache_write_index),
		.wr_data(wr_update_data),
		.wr_enable(wr_update_enable));
		
	// Determine if the line is dirty and whether we need to do a writeback.
	// - If this is a flush, we check dirty bits on the way that was a cache hit.
	// - If we are replacing a line, we check dirty bits on the way that is being
	//   replaced.
	wire line_is_dirty_muxed = dir_l2_dirty[dir_l2req_packet.op == L2REQ_FLUSH 
		? dir_hit_l2_way : dir_miss_fill_l2_way];

	// Track synchronized load/stores, and determine if a synchronized store
	// was successful.
	localparam TOTAL_STRANDS = `NUM_CORES * `STRANDS_PER_CORE;

	logic[25:0] sync_load_address[0:TOTAL_STRANDS - 1]; 
	logic sync_load_address_valid[0:TOTAL_STRANDS - 1];

	wire can_store_sync = sync_load_address[{ dir_l2req_packet.core, dir_l2req_packet.strand}] 
		== dir_l2req_packet.address 
		&& sync_load_address_valid[{ dir_l2req_packet.core, dir_l2req_packet.strand}]
		&& dir_l2req_packet.op == L2REQ_STORE_SYNC;
	
	always_ff @(posedge clk, posedge reset)
	begin : update

		if (reset)
		begin
			for (int i = 0; i < TOTAL_STRANDS; i++)
			begin
				sync_load_address[i] <= 26'h0000000;	
				sync_load_address_valid[i] <= 0;
			end

			/*AUTORESET*/
			// Beginning of autoreset for uninitialized flops
			rd_cache_hit <= 1'h0;
			rd_data_from_memory <= {(1+(`CACHE_LINE_BITS-1)){1'b0}};
			rd_dir_l1_way <= {(1+(`NUM_CORES*2-1)){1'b0}};
			rd_hit_l2_way <= 2'h0;
			rd_is_l2_fill <= 1'h0;
			rd_l1_has_line <= {(1+(`NUM_CORES-1)){1'b0}};
			rd_l2req_packet <= 1'h0;
			rd_line_is_dirty <= 1'h0;
			rd_miss_fill_l2_way <= 2'h0;
			rd_old_l2_tag <= {(1+(`L2_TAG_WIDTH-1)){1'b0}};
			rd_store_sync_success <= 1'h0;
			// End of automatics
		end
		else
		begin
			assert(!(dir_is_l2_fill && dir_cache_hit && dir_l2req_packet.valid));

			rd_l2req_packet <= dir_l2req_packet;
			rd_is_l2_fill <= dir_is_l2_fill;	
			rd_data_from_memory <= dir_data_from_memory;	
			rd_hit_l2_way <= dir_hit_l2_way;
			rd_cache_hit <= dir_cache_hit;
			rd_l1_has_line <= dir_l1_has_line;
			rd_dir_l1_way <= dir_l1_way;
			rd_old_l2_tag <= dir_old_l2_tag;
			rd_line_is_dirty <= line_is_dirty_muxed;
			rd_miss_fill_l2_way <= dir_miss_fill_l2_way;

			if (dir_l2req_packet.valid && (dir_cache_hit || dir_is_l2_fill))
			begin
				unique case (dir_l2req_packet.op)
					L2REQ_LOAD_SYNC:
					begin
						sync_load_address[{ dir_l2req_packet.core, dir_l2req_packet.strand}] 
							<= dir_l2req_packet.address;
						sync_load_address_valid[{ dir_l2req_packet.core, dir_l2req_packet.strand}] <= 1;
					end
		
					L2REQ_STORE,
					L2REQ_STORE_SYNC:
					begin
						// Note that we don't invalidate if the sync store is 
						// not successful.  Otherwise strands can livelock.
						if (dir_l2req_packet.op == L2REQ_STORE || can_store_sync)
						begin
							// Invalidate
							for (int k = 0; k < TOTAL_STRANDS; k++)
							begin
								if (sync_load_address[k] == dir_l2req_packet.address)
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

// Local Variables:
// verilog-typedef-regexp:"_t$"
// End:
