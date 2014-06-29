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
// Ring controller pipeline stage 1  
// The ring bus connects each core to the shared L2 cache and support cache coherence.
// - Issue snoop request to L1 tags for data cache.
//

module ring_controller_stage1
	#(parameter CORE_ID = 0)
	(input                                        clk,
	input                                         reset,
	                                             
	// From ring interface                       
	input ring_packet_t                           packet_in,
                                                 
	// To stage 2                                
	output ring_packet_t                          rc1_packet,
	
	// To/from data cache
	output logic                                  rc_snoop_en,
	output l1d_set_idx_t                          rc_snoop_set,
                                                  
	// To instruction cache                  
	output                                        rc_ilru_read_en,
	output l1i_set_idx_t                          rc_ilru_read_set);

	l1d_addr_t dcache_addr;
	l1i_addr_t icache_addr;

	assign dcache_addr = packet_in.address;
	assign icache_addr = packet_in.address;
	assign rc_snoop_en = packet_in.valid && packet_in.cache_type == CT_DCACHE;
	assign rc_snoop_set = dcache_addr.set_idx;
	assign rc_ilru_read_en = packet_in.valid && packet_in.cache_type == CT_ICACHE;
	assign rc_ilru_read_set = icache_addr.set_idx;

	always_ff @(posedge clk, posedge reset)
	begin
		if (reset)
			rc1_packet <= 0;
		else
			rc1_packet <= packet_in;
	end
endmodule

// Local Variables:
// verilog-typedef-regexp:"_t$"
// End:


