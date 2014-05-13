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

module core
	#(parameter NODE_ID = 0)
	(input                                 clk,
	input                                  reset,
	output logic                           processor_halt,

	// Ring interface
	input ring_packet_t                    packet_in,
	output ring_packet_t                   packet_out,

	// Cache placeholder
 	output scalar_t                        SIM_icache_request_addr,
	input scalar_t                         SIM_icache_data);

	/*AUTOWIRE*/
	// Beginning of automatic wires (for undeclared instantiated-module outputs)
	wire		dd_cache_miss;		// From instruction_pipeline of instruction_pipeline.v
	scalar_t	dd_cache_miss_addr;	// From instruction_pipeline of instruction_pipeline.v
	wire		dd_cache_miss_store;	// From instruction_pipeline of instruction_pipeline.v
	thread_idx_t	dd_cache_miss_thread_idx;// From instruction_pipeline of instruction_pipeline.v
	logic [`CACHE_LINE_BITS-1:0] dd_ddata_read_data;// From instruction_pipeline of instruction_pipeline.v
	l1d_way_idx_t	dt_snoop_lru;		// From instruction_pipeline of instruction_pipeline.v
	cache_line_state_t dt_snoop_state [`L1D_WAYS];// From instruction_pipeline of instruction_pipeline.v
	l1d_tag_t	dt_snoop_tag [`L1D_WAYS];// From instruction_pipeline of instruction_pipeline.v
	wire [`THREADS_PER_CORE-1:0] rc_dcache_wake_oh;// From ring_controller of ring_controller.v
	wire		rc_ddata_read_en;	// From ring_controller of ring_controller.v
	l1d_set_idx_t	rc_ddata_read_set;	// From ring_controller of ring_controller.v
	l1d_way_idx_t	rc_ddata_read_way;	// From ring_controller of ring_controller.v
	wire [`CACHE_LINE_BITS-1:0] rc_ddata_update_data;// From ring_controller of ring_controller.v
	wire		rc_ddata_update_en;	// From ring_controller of ring_controller.v
	l1d_set_idx_t	rc_ddata_update_set;	// From ring_controller of ring_controller.v
	l1d_way_idx_t	rc_ddata_update_way;	// From ring_controller of ring_controller.v
	wire [`L1D_WAYS-1:0] rc_dtag_update_en_oh;// From ring_controller of ring_controller.v
	l1d_set_idx_t	rc_dtag_update_set;	// From ring_controller of ring_controller.v
	cache_line_state_t rc_dtag_update_state;// From ring_controller of ring_controller.v
	l1d_tag_t	rc_dtag_update_tag;	// From ring_controller of ring_controller.v
	logic		rc_snoop_en;		// From ring_controller of ring_controller.v
	l1d_set_idx_t	rc_snoop_set;		// From ring_controller of ring_controller.v
	// End of automatics

	instruction_pipeline instruction_pipeline(.*);
	ring_controller #(.NODE_ID(NODE_ID)) ring_controller(.*);
endmodule

// Local Variables:
// verilog-typedef-regexp:"_t$"
// End:

