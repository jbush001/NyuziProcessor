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
// Ring controller pipeline stage 3
// The ring bus connects each core to the shared L2 cache and support cache coherence.
//
// Update cache data. The data for the L1 cache must always be updated a cycle after
// the tags because:
// - They are accessed in this order in the instruction pipeline. They must be updated
//   the same way here to avoid a race condition.
// - When a cache line is replaced, the old data must be read in stage 2 so it can be
//   pushed back to memory. This forces us to wait until this stage to write the new data.
// This stage also inserts a writeback packet with the old cache line data if necessary.
//

module ring_controller_stage3
	#(parameter CORE_ID = 0)
	(input                                         clk,
	input                                          reset,
	                                               
	// From stage 2                                
	input ring_packet_t                            rc2_packet,
	input                                          rc2_update_pkt_data,
	input l1d_way_idx_t                            rc2_fill_way_idx,
	input                                          rc2_icache_update_en,
	input                                          rc2_dcache_update_en,

	// To ring
	output ring_packet_t                           packet_out,
	                                               
	// To/from data cache                          
	input logic[`CACHE_LINE_BITS - 1:0]            dd_ddata_read_data,
	output                                         rc_ddata_update_en,
	output l1d_way_idx_t                           rc_ddata_update_way,
	output l1d_set_idx_t                           rc_ddata_update_set,
	output [`CACHE_LINE_BITS - 1:0]                rc_ddata_update_data,
                                                   
	// To/from instruction cache                   
	output                                         rc_idata_update_en,
	output l1i_way_idx_t                           rc_idata_update_way,
	output l1i_set_idx_t                           rc_idata_update_set,
	output [`CACHE_LINE_BITS - 1:0]                rc_idata_update_data);

	ring_packet_t packet_out_nxt;
	l1d_addr_t dcache_addr;
	l1i_addr_t icache_addr;
	logic is_ack_for_me;

	assign dcache_addr = rc2_packet.address;
	assign icache_addr = rc2_packet.address;
	assign is_ack_for_me = rc2_packet.valid && rc2_packet.ack && rc2_packet.dest_core == CORE_ID;

	//
	// Update cache line for data cache
	//
	assign rc_ddata_update_en = rc2_dcache_update_en;
	assign rc_ddata_update_way = rc2_fill_way_idx;	
	assign rc_ddata_update_set = dcache_addr.set_idx;
	assign rc_ddata_update_data = rc2_packet.data;

	//
	// Update cache line for instruction cache
	//
	assign rc_idata_update_en = rc2_icache_update_en;
	assign rc_idata_update_way = rc2_fill_way_idx;	
	assign rc_idata_update_set = icache_addr.set_idx;
	assign rc_idata_update_data = rc2_packet.data;

	// To avoid starvation, a node that consumes a response from the ring
	// leaves that slot empty (unless an L2 writeback is necessary). 
	always_comb
	begin
		packet_out_nxt = rc2_packet;	
		if (rc2_update_pkt_data)
			packet_out_nxt.data = dd_ddata_read_data;	// Insert data into packet
		else if (is_ack_for_me)
			packet_out_nxt = 0;
	end

	always_ff @(posedge clk, posedge reset)
	begin
		if (reset)
			packet_out <= 0;
		else
			packet_out <= packet_out_nxt;
	end
endmodule

// Local Variables:
// verilog-typedef-regexp:"_t$"
// End:


