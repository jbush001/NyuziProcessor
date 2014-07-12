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

`include "../core/defines.v"

//
// Simulates ring controller and underlying memory hierarchy
//

module ring_controller_sim(
	input                                  clk,
	input                                  reset,
	
	output logic[`L1D_WAYS - 1:0]          l2i_dtag_update_en_oh,
	output l1d_set_idx_t                   l2i_dtag_update_set,
	output l1d_tag_t                       l2i_dtag_update_tag,
	output cache_line_state_t              l2i_dtag_update_state,
	output logic                           l2i_ddata_update_en,
	output l1d_way_idx_t                   l2i_ddata_update_way,
	output l1d_set_idx_t                   l2i_ddata_update_set,
	output [`CACHE_LINE_BITS - 1:0]        l2i_ddata_update_data,
	output [`THREADS_PER_CORE - 1:0]       l2i_dcache_wake_oh,
	output logic                           l2i_ddata_read_en,
	output l1d_set_idx_t                   l2i_ddata_read_set,
 	output l1d_way_idx_t                   l2i_ddata_read_way,
	output logic                           l2i_snoop_en,
	output l1d_set_idx_t                   l2i_snoop_set,

	input cache_line_state_t               dt_snoop_state[`L1D_WAYS],
	input l1d_tag_t                        dt_snoop_tag[`L1D_WAYS],
	input l1d_way_idx_t                    dt_snoop_lru,
	input                                  dd_cache_miss,
	input l1d_addr_t                       dd_cache_miss_addr,
	input                                  dd_cache_miss_store,
	input thread_idx_t                     dd_cache_miss_thread_idx,
	input logic[`CACHE_LINE_BITS - 1:0]    dd_ddata_read_data,

	output [`L1I_WAYS - 1:0]               l2i_itag_update_en_oh,
	output l1i_set_idx_t                   l2i_itag_update_set,
	output l1i_tag_t                       l2i_itag_update_tag,
	output logic                           l2i_itag_update_valid,
	output logic                           l2i_idata_update_en,
	output l1i_way_idx_t                   l2i_idata_update_way,
	output l1i_set_idx_t                   l2i_idata_update_set,
	output [`CACHE_LINE_BITS - 1:0]        l2i_idata_update_data,
	output [`THREADS_PER_CORE - 1:0]       l2i_icache_wake_oh,
	output logic                           l2i_ilru_read_en,
	output l1i_set_idx_t                   l2i_ilru_read_set,

	input                                  ifd_cache_miss,
	input l1i_addr_t                       ifd_cache_miss_addr,
	input thread_idx_t                     ifd_cache_miss_thread_idx,
	input l1i_way_idx_t                    ift_lru);

	localparam MEM_SIZE = 'h500000;

	typedef struct packed {
		logic valid;
		l1d_tag_t old_tag;
		l1d_tag_t new_tag;
		l1d_set_idx_t set_idx;
		l1d_way_idx_t way_idx;
		cache_line_state_t new_state;
		thread_idx_t thread_idx;
		logic do_writeback;
	} dcache_request_t;

	typedef struct packed {
		logic valid;
		l1i_tag_t new_tag;
		l1i_set_idx_t set_idx;
		l1i_way_idx_t way_idx;
		thread_idx_t thread_idx;
	} icache_request_t;
	
	icache_request_t icache_request[3];
	dcache_request_t dcache_request[3];
	int dcache_snoop_hit_way;
	int dcache_load_way;
	int icache_load_way;
	scalar_t memory[MEM_SIZE];
	
	initial
	begin
		for (int i = 0; i < MEM_SIZE; i++)
			memory[i] = 0;
	end

	// Stage 1: Request existing tag
	assign l2i_snoop_en = dcache_request[0].valid;
	assign l2i_snoop_set = dcache_request[0].set_idx;
	assign l2i_ilru_read_en = icache_request[0].valid;
	assign l2i_ilru_read_set = icache_request[0].set_idx;

	// Stage 2: Update tag memory
	always_comb
	begin
		dcache_snoop_hit_way = -1;
		for (int way = 0; way < `L1D_WAYS; way++)
		begin
			if (dt_snoop_tag[way] == dcache_request[1].new_tag && dt_snoop_state[way] != CL_STATE_INVALID)
			begin
				dcache_snoop_hit_way = way;
				break;
			end
		end

		if (dcache_snoop_hit_way != -1)
			dcache_load_way = dcache_snoop_hit_way;
		else
			dcache_load_way = dt_snoop_lru;
	end

	always_comb
	begin
		for (int i = 0; i < `L1D_WAYS; i++)
			l2i_dtag_update_en_oh[i] = dcache_request[1].valid && dcache_load_way == i;
	end

	assign l2i_dtag_update_set = dcache_request[1].set_idx;
	assign l2i_dtag_update_tag = dcache_request[1].new_tag;
	assign l2i_dtag_update_state = (dcache_snoop_hit_way != -1 
		&& dt_snoop_state[dcache_snoop_hit_way] == CL_STATE_MODIFIED)
		? CL_STATE_MODIFIED	// Don't clear modified state
		: dcache_request[1].new_state;

	always_comb
	begin
		for (int i = 0; i < `L1D_WAYS; i++)
			l2i_itag_update_en_oh[i] = icache_request[1].valid && i == ift_lru;
	end

	assign l2i_itag_update_set = icache_request[1].set_idx;
	assign l2i_itag_update_tag = icache_request[1].new_tag;
	assign l2i_itag_update_valid = 1;

	// Request old cache line (for writeback)
	assign l2i_ddata_read_en = dcache_request[1].valid;
	assign l2i_ddata_read_set = dcache_request[1].set_idx;
	assign l2i_ddata_read_way = dcache_load_way;

	// Stage 3: Update L1 cache line
	assign l2i_ddata_update_en = dcache_request[2].valid;
	assign l2i_ddata_update_way = dcache_request[2].way_idx;
	assign l2i_ddata_update_set = dcache_request[2].set_idx;

	assign l2i_idata_update_en = icache_request[2].valid;
	assign l2i_idata_update_way = icache_request[2].way_idx;
	assign l2i_idata_update_set = icache_request[2].set_idx;

	always_comb
	begin
		// Read data from main memory and push to L1 cache
		if (l2i_ddata_update_en)
		begin
			for (int i = 0; i < `CACHE_LINE_WORDS; i++)
			begin
				l2i_ddata_update_data[32 * (`CACHE_LINE_WORDS - 1 - i)+:32] = memory[{dcache_request[2].new_tag, 
					dcache_request[2].set_idx, 4'd0} + i];
			end
		end

		if (l2i_idata_update_en)
		begin
			for (int i = 0; i < `CACHE_LINE_WORDS; i++)
			begin
				l2i_idata_update_data[32 * (`CACHE_LINE_WORDS - 1 - i)+:32] = memory[{icache_request[2].new_tag, 
					icache_request[2].set_idx, 4'd0} + i];
			end
		end
	end
	
	always_ff @(posedge clk, posedge reset)
	begin : update
		int mem_index;
	
		if (reset)
		begin
			for (int i = 0; i < 3; i++)
			begin
				icache_request[i] <= 0;
				dcache_request[i] <= 0;
			end
		end
		else
		begin
			icache_request[0].valid <= ifd_cache_miss;
			icache_request[0].set_idx <= ifd_cache_miss_addr.set_idx;
			icache_request[0].new_tag <= ifd_cache_miss_addr.tag;
			icache_request[0].thread_idx <= ifd_cache_miss_thread_idx;
			icache_request[1] <= icache_request[0];
			icache_request[2] <= icache_request[1];
			icache_request[2].way_idx <= ift_lru;
			l2i_icache_wake_oh <= icache_request[2].valid ? (1 << icache_request[2].thread_idx) : 0;

			dcache_request[0].valid <= dd_cache_miss;
			dcache_request[0].set_idx <= dd_cache_miss_addr.set_idx;
			dcache_request[0].new_tag <= dd_cache_miss_addr.tag;
			dcache_request[0].new_state <= dd_cache_miss_store ? CL_STATE_MODIFIED : CL_STATE_SHARED;
			dcache_request[0].thread_idx <= dd_cache_miss_thread_idx;
			dcache_request[1] <= dcache_request[0];
			dcache_request[2] <= dcache_request[1];
			dcache_request[2].way_idx <= dcache_load_way;
			if (dcache_snoop_hit_way != -1)
				dcache_request[2].do_writeback <= 0;
			else
			begin
				// Find a line to replace
				dcache_request[2].old_tag <= dt_snoop_tag[dcache_load_way];
				dcache_request[2].do_writeback <= dt_snoop_state[dcache_load_way] == CL_STATE_MODIFIED;
			end

			l2i_dcache_wake_oh <= dcache_request[2].valid ? (1 << dcache_request[2].thread_idx) : 0;

			// Writeback old data to memory
			if (dcache_request[2].valid && dcache_request[2].do_writeback)
			begin
				for (int i = 0; i < `CACHE_LINE_WORDS; i++)
				begin
					memory[{dcache_request[2].old_tag, dcache_request[2].set_idx, 4'd0} + i] = 
						dd_ddata_read_data[(`CACHE_LINE_WORDS - 1 - i) * 32+:32];
				end
			end
		end
	end
endmodule
