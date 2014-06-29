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
// An independent CPU, including instruction pipeline and L2 ring interconnect logic.
// 

module core
	#(parameter CORE_ID = 0)
	(input                                 clk,
	input                                  reset,
	output logic                           processor_halt,

	// Ring interface
	input ring_packet_t                    packet_in,
	output ring_packet_t                   packet_out);

	/*AUTOWIRE*/
	// Beginning of automatic wires (for undeclared instantiated-module outputs)
	wire		dd_cache_miss;		// From instruction_pipeline of instruction_pipeline.v
	scalar_t	dd_cache_miss_addr;	// From instruction_pipeline of instruction_pipeline.v
	wire		dd_cache_miss_store;	// From instruction_pipeline of instruction_pipeline.v
	thread_idx_t	dd_cache_miss_thread_idx;// From instruction_pipeline of instruction_pipeline.v
	scalar_t	dd_store_addr;		// From instruction_pipeline of instruction_pipeline.v
	scalar_t	dd_store_bypass_addr;	// From instruction_pipeline of instruction_pipeline.v
	thread_idx_t	dd_store_bypass_thread_idx;// From instruction_pipeline of instruction_pipeline.v
	wire [`CACHE_LINE_BITS-1:0] dd_store_data;// From instruction_pipeline of instruction_pipeline.v
	wire		dd_store_en;		// From instruction_pipeline of instruction_pipeline.v
	wire [`CACHE_LINE_BYTES-1:0] dd_store_mask;// From instruction_pipeline of instruction_pipeline.v
	logic		dd_store_synchronized;	// From instruction_pipeline of instruction_pipeline.v
	thread_idx_t	dd_store_thread_idx;	// From instruction_pipeline of instruction_pipeline.v
	l1d_way_idx_t	dt_snoop_lru;		// From instruction_pipeline of instruction_pipeline.v
	l1d_tag_t	dt_snoop_tag [`L1D_WAYS];// From instruction_pipeline of instruction_pipeline.v
	logic		dt_snoop_valid [`L1D_WAYS];// From instruction_pipeline of instruction_pipeline.v
	logic		ifd_cache_miss;		// From instruction_pipeline of instruction_pipeline.v
	scalar_t	ifd_cache_miss_addr;	// From instruction_pipeline of instruction_pipeline.v
	thread_idx_t	ifd_cache_miss_thread_idx;// From instruction_pipeline of instruction_pipeline.v
	l1i_way_idx_t	ift_lru;		// From instruction_pipeline of instruction_pipeline.v
	wire		perf_dcache_hit;	// From instruction_pipeline of instruction_pipeline.v
	wire		perf_dcache_miss;	// From instruction_pipeline of instruction_pipeline.v
	wire		perf_icache_hit;	// From instruction_pipeline of instruction_pipeline.v
	wire		perf_icache_miss;	// From instruction_pipeline of instruction_pipeline.v
	wire		perf_instruction_issue;	// From instruction_pipeline of instruction_pipeline.v
	wire		perf_instruction_retire;// From instruction_pipeline of instruction_pipeline.v
	ring_packet_t	rc1_packet;		// From ring_controller_stage1 of ring_controller_stage1.v
	wire [`THREADS_PER_CORE-1:0] rc_dcache_wake_oh;// From ring_controller_stage2 of ring_controller_stage2.v
	wire [`CACHE_LINE_BITS-1:0] rc_ddata_update_data;// From ring_controller_stage2 of ring_controller_stage2.v
	wire		rc_ddata_update_en;	// From ring_controller_stage2 of ring_controller_stage2.v
	l1d_set_idx_t	rc_ddata_update_set;	// From ring_controller_stage2 of ring_controller_stage2.v
	l1d_way_idx_t	rc_ddata_update_way;	// From ring_controller_stage2 of ring_controller_stage2.v
	wire [`L1D_WAYS-1:0] rc_dtag_update_en_oh;// From ring_controller_stage2 of ring_controller_stage2.v
	l1d_set_idx_t	rc_dtag_update_set;	// From ring_controller_stage2 of ring_controller_stage2.v
	l1d_tag_t	rc_dtag_update_tag;	// From ring_controller_stage2 of ring_controller_stage2.v
	logic		rc_dtag_update_valid;	// From ring_controller_stage2 of ring_controller_stage2.v
	wire [`THREADS_PER_CORE-1:0] rc_icache_wake_oh;// From ring_controller_stage2 of ring_controller_stage2.v
	wire [`CACHE_LINE_BITS-1:0] rc_idata_update_data;// From ring_controller_stage2 of ring_controller_stage2.v
	wire		rc_idata_update_en;	// From ring_controller_stage2 of ring_controller_stage2.v
	l1i_set_idx_t	rc_idata_update_set;	// From ring_controller_stage2 of ring_controller_stage2.v
	l1i_way_idx_t	rc_idata_update_way;	// From ring_controller_stage2 of ring_controller_stage2.v
	wire		rc_ilru_read_en;	// From ring_controller_stage1 of ring_controller_stage1.v
	l1i_set_idx_t	rc_ilru_read_set;	// From ring_controller_stage1 of ring_controller_stage1.v
	wire [`L1I_WAYS-1:0] rc_itag_update_en_oh;// From ring_controller_stage2 of ring_controller_stage2.v
	l1i_set_idx_t	rc_itag_update_set;	// From ring_controller_stage2 of ring_controller_stage2.v
	l1i_tag_t	rc_itag_update_tag;	// From ring_controller_stage2 of ring_controller_stage2.v
	logic		rc_itag_update_valid;	// From ring_controller_stage2 of ring_controller_stage2.v
	logic		rc_snoop_en;		// From ring_controller_stage1 of ring_controller_stage1.v
	l1d_set_idx_t	rc_snoop_set;		// From ring_controller_stage1 of ring_controller_stage1.v
	wire		sb_full_rollback;	// From ring_controller_stage2 of ring_controller_stage2.v
	wire [`CACHE_LINE_BITS-1:0] sb_store_bypass_data;// From ring_controller_stage2 of ring_controller_stage2.v
	wire		sb_store_bypass_mask;	// From ring_controller_stage2 of ring_controller_stage2.v
	// End of automatics

	instruction_pipeline instruction_pipeline(.*);
	ring_controller_stage1 #(.CORE_ID(CORE_ID)) ring_controller_stage1(.*);
	ring_controller_stage2 #(.CORE_ID(CORE_ID)) ring_controller_stage2(.*);
	
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

