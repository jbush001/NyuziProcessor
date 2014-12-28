//
// Copyright (C) 2014 Jeff Bush
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
// Instruction Pipeline - Instruction Fetch Data Stage
// - If the last fetched PC was determined to be in the instruction cache, 
//   fetch the contents of the corresponding cache line here.
// - Drive signals to update LRU in previous stage
//

module ifetch_data_stage(
	input                            clk,
	input                            reset,

	// From instruction fetch tag stage
	input                            ift_instruction_requested,
	input l1i_addr_t                 ift_pc,
	input thread_idx_t               ift_thread_idx,
	input l1i_tag_t                  ift_tag[`L1D_WAYS],
	input                            ift_valid[`L1D_WAYS],

	// To ifetch_tag_stage
	output logic                     ifd_update_lru_en,
	output l1i_way_idx_t             ifd_update_lru_way,
	output logic                     ifd_near_miss,

	// From l2_interface
	input                            l2i_idata_update_en,
	input l1i_way_idx_t              l2i_idata_update_way,
	input l1i_set_idx_t              l2i_idata_update_set,
	input cache_line_data_t          l2i_idata_update_data,
	input [`L1I_WAYS - 1:0]          l2i_itag_update_en_oh,
	input l1i_set_idx_t              l2i_itag_update_set,
	input l1i_tag_t                  l2i_itag_update_tag,

	// To l2_interface
	output logic                     ifd_cache_miss,
	output scalar_t                  ifd_cache_miss_addr,
	output thread_idx_t              ifd_cache_miss_thread_idx,	// also to ifetch_tag

	// To instruction decode stage
	output scalar_t                  ifd_instruction,
	output logic                     ifd_instruction_valid,
	output scalar_t                  ifd_pc,
	output thread_idx_t              ifd_thread_idx,
                                    
	// From writeback stage         
	input                            wb_rollback_en,
	input thread_idx_t               wb_rollback_thread_idx,

	// Performance counters
	output logic                     perf_icache_hit,
	output logic                     perf_icache_miss);

	logic cache_hit;
	logic[`L1I_WAYS - 1:0] way_hit_oh;
	l1i_way_idx_t way_hit_idx;
	logic[`CACHE_LINE_BITS - 1:0] fetched_cache_line;
	scalar_t fetched_word;
	thread_bitmap_t thread_oh;
	logic[$clog2(`CACHE_LINE_WORDS) - 1:0] cache_lane;

	// 
	// Check for cache hit
	//
	genvar way_idx;
	generate
		for (way_idx = 0; way_idx < `L1I_WAYS; way_idx++)
		begin : hit_check_gen
			always_comb
				way_hit_oh[way_idx] = ift_pc.tag == ift_tag[way_idx] && ift_valid[way_idx]; 
		end
	endgenerate

	assign cache_hit = |way_hit_oh;

	oh_to_idx #(.NUM_SIGNALS(`L1D_WAYS)) oh_to_idx_hit_way(
		.one_hot(way_hit_oh),
		.index(way_hit_idx));

	assign ifd_near_miss = !cache_hit && ift_instruction_requested && |l2i_itag_update_en_oh
		&& l2i_itag_update_set == ift_pc.set_idx && l2i_itag_update_tag == ift_pc.tag; 
	assign ifd_cache_miss = !cache_hit && ift_instruction_requested && !ifd_near_miss;
	assign ifd_cache_miss_addr = { ift_pc.tag, ift_pc.set_idx, {`CACHE_LINE_OFFSET_WIDTH{1'b0}} };
	assign ifd_cache_miss_thread_idx = ift_thread_idx;
	assign perf_icache_hit = cache_hit && ift_instruction_requested;
	assign perf_icache_miss = !cache_hit && ift_instruction_requested;

	//
	// Instruction cache data
	//
	sram_1r1w #(
		.DATA_WIDTH(`CACHE_LINE_BITS), 
		.SIZE(`L1I_WAYS * `L1I_SETS),
		.READ_DURING_WRITE("NEW_DATA")
	) sram_l1i_data(
		.read_en(cache_hit && ift_instruction_requested),
		.read_addr({ way_hit_idx, ift_pc.set_idx }),
		.read_data(fetched_cache_line),
		.write_en(l2i_idata_update_en),	
		.write_addr({ l2i_idata_update_way, l2i_idata_update_set }),
		.write_data(l2i_idata_update_data),
		.*);

	assign cache_lane = ~ifd_pc[`CACHE_LINE_OFFSET_WIDTH - 1:2];
	assign fetched_word = fetched_cache_line[32 * cache_lane+:32];
	assign ifd_instruction = { fetched_word[7:0], fetched_word[15:8], fetched_word[23:16], fetched_word[31:24] };

	assign ifd_update_lru_en = cache_hit && ift_instruction_requested;
	assign ifd_update_lru_way = way_hit_idx;

	always_ff @(posedge clk, posedge reset)
	begin
		if (reset)
		begin
			/*AUTORESET*/
			// Beginning of autoreset for uninitialized flops
			ifd_instruction_valid <= 1'h0;
			ifd_pc <= 1'h0;
			ifd_thread_idx <= 1'h0;
			// End of automatics
		end
		else
		begin
			// Ensure more than one way isn't a hit
			assert($onehot0(way_hit_oh));

			ifd_instruction_valid <= ift_instruction_requested && (!wb_rollback_en || wb_rollback_thread_idx 
				!= ift_thread_idx) && cache_hit;
			ifd_pc <= ift_pc;
			ifd_thread_idx <= ift_thread_idx;
		end
	end
endmodule

// Local Variables:
// verilog-typedef-regexp:"_t$"
// End:
