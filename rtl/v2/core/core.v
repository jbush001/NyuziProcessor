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

`include "defines.v"

//
// An independent CPU, including instruction pipeline and L2 interconnect logic.
// 

module core
	#(parameter CORE_ID = 0)
	(input                                 clk,
	input                                  reset,
	output logic                           processor_halt,

	// L2 interface
	input                                  l2_ready,
	output l2req_packet_t                  l2i_request,
	input l2rsp_packet_t                   l2_response);

	/*AUTOWIRE*/
	// Beginning of automatic wires (for undeclared instantiated-module outputs)
	wire		dd_cache_miss;		// From instruction_pipeline of instruction_pipeline.v
	scalar_t	dd_cache_miss_addr;	// From instruction_pipeline of instruction_pipeline.v
	wire		dd_cache_miss_store;	// From instruction_pipeline of instruction_pipeline.v
	wire		dd_cache_miss_synchronized;// From instruction_pipeline of instruction_pipeline.v
	thread_idx_t	dd_cache_miss_thread_idx;// From instruction_pipeline of instruction_pipeline.v
	scalar_t	dd_store_addr;		// From instruction_pipeline of instruction_pipeline.v
	scalar_t	dd_store_bypass_addr;	// From instruction_pipeline of instruction_pipeline.v
	thread_idx_t	dd_store_bypass_thread_idx;// From instruction_pipeline of instruction_pipeline.v
	wire [`CACHE_LINE_BITS-1:0] dd_store_data;// From instruction_pipeline of instruction_pipeline.v
	wire		dd_store_en;		// From instruction_pipeline of instruction_pipeline.v
	wire [`CACHE_LINE_BYTES-1:0] dd_store_mask;// From instruction_pipeline of instruction_pipeline.v
	logic		dd_store_synchronized;	// From instruction_pipeline of instruction_pipeline.v
	thread_idx_t	dd_store_thread_idx;	// From instruction_pipeline of instruction_pipeline.v
	l1d_way_idx_t	dt_fill_lru;		// From instruction_pipeline of instruction_pipeline.v
	l1d_tag_t	dt_snoop_tag [`L1D_WAYS];// From instruction_pipeline of instruction_pipeline.v
	logic		dt_snoop_valid [`L1D_WAYS];// From instruction_pipeline of instruction_pipeline.v
	logic		ifd_cache_miss;		// From instruction_pipeline of instruction_pipeline.v
	scalar_t	ifd_cache_miss_addr;	// From instruction_pipeline of instruction_pipeline.v
	thread_idx_t	ifd_cache_miss_thread_idx;// From instruction_pipeline of instruction_pipeline.v
	l1i_way_idx_t	ift_fill_lru;		// From instruction_pipeline of instruction_pipeline.v
	wire		l2i_dcache_lru_fill_en;	// From l2_cache_interface of l2_cache_interface.v
	l1d_set_idx_t	l2i_dcache_lru_fill_set;// From l2_cache_interface of l2_cache_interface.v
	wire [`THREADS_PER_CORE-1:0] l2i_dcache_wake_bitmap;// From l2_cache_interface of l2_cache_interface.v
	wire [`CACHE_LINE_BITS-1:0] l2i_ddata_update_data;// From l2_cache_interface of l2_cache_interface.v
	wire		l2i_ddata_update_en;	// From l2_cache_interface of l2_cache_interface.v
	l1d_set_idx_t	l2i_ddata_update_set;	// From l2_cache_interface of l2_cache_interface.v
	l1d_way_idx_t	l2i_ddata_update_way;	// From l2_cache_interface of l2_cache_interface.v
	wire [`L1D_WAYS-1:0] l2i_dtag_update_en_oh;// From l2_cache_interface of l2_cache_interface.v
	l1d_set_idx_t	l2i_dtag_update_set;	// From l2_cache_interface of l2_cache_interface.v
	l1d_tag_t	l2i_dtag_update_tag;	// From l2_cache_interface of l2_cache_interface.v
	logic		l2i_dtag_update_valid;	// From l2_cache_interface of l2_cache_interface.v
	wire		l2i_icache_lru_fill_en;	// From l2_cache_interface of l2_cache_interface.v
	l1i_set_idx_t	l2i_icache_lru_fill_set;// From l2_cache_interface of l2_cache_interface.v
	wire [`THREADS_PER_CORE-1:0] l2i_icache_wake_bitmap;// From l2_cache_interface of l2_cache_interface.v
	wire [`CACHE_LINE_BITS-1:0] l2i_idata_update_data;// From l2_cache_interface of l2_cache_interface.v
	wire		l2i_idata_update_en;	// From l2_cache_interface of l2_cache_interface.v
	l1i_set_idx_t	l2i_idata_update_set;	// From l2_cache_interface of l2_cache_interface.v
	l1i_way_idx_t	l2i_idata_update_way;	// From l2_cache_interface of l2_cache_interface.v
	wire [`L1I_WAYS-1:0] l2i_itag_update_en_oh;// From l2_cache_interface of l2_cache_interface.v
	l1i_set_idx_t	l2i_itag_update_set;	// From l2_cache_interface of l2_cache_interface.v
	l1i_tag_t	l2i_itag_update_tag;	// From l2_cache_interface of l2_cache_interface.v
	logic		l2i_itag_update_valid;	// From l2_cache_interface of l2_cache_interface.v
	logic		l2i_snoop_en;		// From l2_cache_interface of l2_cache_interface.v
	l1d_set_idx_t	l2i_snoop_set;		// From l2_cache_interface of l2_cache_interface.v
	wire		perf_dcache_hit;	// From instruction_pipeline of instruction_pipeline.v
	wire		perf_dcache_miss;	// From instruction_pipeline of instruction_pipeline.v
	wire		perf_icache_hit;	// From instruction_pipeline of instruction_pipeline.v
	wire		perf_icache_miss;	// From instruction_pipeline of instruction_pipeline.v
	wire		perf_instruction_issue;	// From instruction_pipeline of instruction_pipeline.v
	wire		perf_instruction_retire;// From instruction_pipeline of instruction_pipeline.v
	wire		sb_full_rollback;	// From l2_cache_interface of l2_cache_interface.v
	wire [`CACHE_LINE_BITS-1:0] sb_store_bypass_data;// From l2_cache_interface of l2_cache_interface.v
	wire		sb_store_bypass_mask;	// From l2_cache_interface of l2_cache_interface.v
	logic		sb_store_sync_success;	// From l2_cache_interface of l2_cache_interface.v
	// End of automatics

	instruction_pipeline instruction_pipeline(.*);
	l2_cache_interface #(.CORE_ID(CORE_ID)) l2_cache_interface(.*);
	
	performance_counters #(.NUM_COUNTERS(6)) performance_counters(
		.perf_event({	
			perf_instruction_retire,
			perf_instruction_issue,
			perf_icache_hit,
			perf_icache_miss,
			perf_dcache_hit,
			perf_dcache_miss 
		}),
		.*);
endmodule

// Local Variables:
// verilog-typedef-regexp:"_t$"
// End:

