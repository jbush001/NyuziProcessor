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
// - Update cache data.
// - Wake up threads if necessary.
//

module ring_controller_stage3
	#(parameter NODE_ID = 0)
	(input                                         clk,
	input                                          reset,
	                                               
	// From stage 2                                
	input ring_packet_t                            rc2_packet,
	input                                          rc2_need_writeback,
	input scalar_t                                 rc2_evicted_line_addr,
	input l1d_way_idx_t                            rc2_fill_way_idx,
	input [$clog2(`THREADS_PER_CORE) - 1:0]        rc2_dcache_miss_entry,
	input [$clog2(`THREADS_PER_CORE) - 1:0]        rc2_icache_miss_entry,

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
	output [`CACHE_LINE_BITS - 1:0]                rc_idata_update_data,
	                                               
	// To stage 1                                  
	output logic                                   rc3_dcache_wake,
	output logic[$clog2(`THREADS_PER_CORE) - 1:0]  rc3_dcache_wake_entry,
	output logic                                   rc3_icache_wake,
	output logic[$clog2(`THREADS_PER_CORE) - 1:0]  rc3_icache_wake_entry);

	ring_packet_t packet_out_nxt;
	l1d_addr_t dcache_addr;
	l1i_addr_t icache_addr;
	logic is_ack_for_me;

	assign dcache_addr = rc2_packet.address;
	assign icache_addr = rc2_packet.address;
	assign is_ack_for_me = rc2_packet.valid && rc2_packet.ack && rc2_packet.dest_node == NODE_ID;

	//
	// Update cache line for data cache
	//
	assign rc_ddata_update_en = is_ack_for_me && rc2_packet.cache_type == CT_DCACHE;
	assign rc_ddata_update_way = rc2_fill_way_idx;	
	assign rc_ddata_update_set = dcache_addr.set_idx;
	assign rc_ddata_update_data = rc2_packet.data;

	//
	// Update cache line for instruction cache
	//
	assign rc_idata_update_en = is_ack_for_me && rc2_packet.cache_type == CT_ICACHE;
	assign rc_idata_update_way = rc2_fill_way_idx;	
	assign rc_idata_update_set = icache_addr.set_idx;
	assign rc_idata_update_data = rc2_packet.data;

	// To avoid starvation, a node that consumes a response from the ring
	// leaves that slot empty (unless an L2 writeback is necessary). 
	always_comb
	begin
		if (rc2_need_writeback)
		begin
			// Insert L2 writeback packet for evicted cache line (this replaces
			// the response packet)
			packet_out_nxt.valid = 1;
			packet_out_nxt.packet_type = PKT_L2_WRITEBACK;
			packet_out_nxt.address = rc2_evicted_line_addr;
			packet_out_nxt.data = dd_ddata_read_data;
		end
		else if (is_ack_for_me)
			packet_out_nxt = 0;	// Pull response out of ring
		else
			packet_out_nxt = rc2_packet;	
	end

	assign rc3_dcache_wake = is_ack_for_me && rc2_packet.cache_type == CT_DCACHE;
	assign rc3_icache_wake = is_ack_for_me && rc2_packet.cache_type == CT_ICACHE;
	assign rc3_dcache_wake_entry = rc2_dcache_miss_entry;
	assign rc3_icache_wake_entry = rc2_icache_miss_entry;

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


