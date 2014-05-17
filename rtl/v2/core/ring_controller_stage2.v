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
// Ring controller pipeline stage 2  
// The ring bus connects each core to the shared L2 cache and support cache coherence.
// - Update the tags
// - Read an old line from data cache if one is to be evicted
//

module ring_controller_stage2
	#(parameter CORE_ID = 0)
	(input                                        clk,
	input                                         reset,
                                                  
	// From stage 1                               
	input ring_packet_t                           rc1_packet,
	input pending_miss_state_t                    rc1_pending_miss_state,
	input logic                                   rc1_dcache_miss_pending,
	input [$clog2(`THREADS_PER_CORE) - 1:0]       rc1_dcache_miss_entry,
	input logic                                   rc1_icache_miss_pending,
	input [$clog2(`THREADS_PER_CORE) - 1:0]       rc1_icache_miss_entry,
                                                  
	// To stage 3                                 
	output ring_packet_t                          rc2_packet,
	output logic                                  rc2_need_writeback,
	output scalar_t                               rc2_evicted_line_addr,
	output l1d_way_idx_t                          rc2_fill_way_idx,
	output logic[$clog2(`THREADS_PER_CORE) - 1:0] rc2_dcache_miss_entry,
	output logic[$clog2(`THREADS_PER_CORE) - 1:0] rc2_icache_miss_entry,
	
	// To/from data cache
	output [`L1D_WAYS - 1:0]                      rc_dtag_update_en_oh,
	output l1d_set_idx_t                          rc_dtag_update_set,
	output l1d_tag_t                              rc_dtag_update_tag,
	output cache_line_state_t                     rc_dtag_update_state,
	output                                        rc_ddata_read_en,
	output l1d_set_idx_t                          rc_ddata_read_set,
 	output l1d_way_idx_t                          rc_ddata_read_way,
	input cache_line_state_t                      dt_snoop_state[`L1D_WAYS],
	input l1d_tag_t                               dt_snoop_tag[`L1D_WAYS],
	input l1d_way_idx_t                           dt_snoop_lru,
                                                 
	// To/from instruction cache                 
	output [`L1I_WAYS - 1:0]                      rc_itag_update_en_oh,
	output l1i_set_idx_t                          rc_itag_update_set,
	output l1i_tag_t                              rc_itag_update_tag,
	output logic                                  rc_itag_update_valid,
	input l1i_way_idx_t                           ift_lru);

	logic[`L1D_WAYS - 1:0] snoop_hit_way_oh;	// Only snoops dcache
	l1d_way_idx_t snoop_hit_way_idx;
	logic[`L1D_WAYS - 1:0] fill_way_oh;	
	l1d_way_idx_t fill_way_idx;
	l1d_addr_t dcache_addr;
	l1i_addr_t icache_addr;
	logic is_ack_for_me;

	assign dcache_addr = rc1_packet.address;
	assign icache_addr = rc1_packet.address;	
	assign is_ack_for_me = rc1_packet.valid && rc1_packet.ack && rc1_packet.dest_core == CORE_ID;

	//
	// Check snoop result
	//
	genvar way_idx;
	generate
		for (way_idx = 0; way_idx < `L1D_WAYS; way_idx++)
		begin
			assign snoop_hit_way_oh[way_idx] = dt_snoop_tag[way_idx] == dcache_addr.tag 
				&& dt_snoop_state[way_idx] != CL_STATE_INVALID;
		end
	endgenerate

	one_hot_to_index #(.NUM_SIGNALS(`L1D_WAYS)) convert_snoop_request_pending(
		.index(snoop_hit_way_idx),
		.one_hot(snoop_hit_way_oh));

	//
	// Determine fill way
	//
	always_comb
	begin
		if (packet_in.cache_type == CT_ICACHE)
			fill_way_idx = ift_lru;		      // Fill new icache line
		else if (|snoop_hit_way_oh)
			fill_way_idx = snoop_hit_way_idx; // Fill existing dcache line
		else
			fill_way_idx = dt_snoop_lru;	 // Fill new dcache line
	end

	index_to_one_hot #(.NUM_SIGNALS(`L1D_WAYS)) convert_tag_update(
		.index(fill_way_idx),
		.one_hot(fill_way_oh));

	//
	// Update data cache tag
	//
	assign rc_dtag_update_en_oh = fill_way_oh 
		& {`L1D_WAYS{is_ack_for_me && rc1_packet.cache_type == CT_DCACHE}};
	assign rc_dtag_update_tag = dcache_addr.tag;	
	assign rc_dtag_update_set = dcache_addr.set_idx;
	assign rc_dtag_update_state = rc1_pending_miss_state == PM_READ_PENDING ? CL_STATE_SHARED
		: CL_STATE_MODIFIED;

	//
	// Update instruction cache tag
	//
	assign rc_itag_update_en_oh = fill_way_oh
		& {`L1I_WAYS{is_ack_for_me && rc1_packet.cache_type == CT_ICACHE}};
	assign rc_itag_update_tag = icache_addr.tag;	
	assign rc_itag_update_set = icache_addr.set_idx;
	assign rc_itag_update_valid = 1'b1;

	//
	// Request old data for evicted cache line
	//
	assign rc_ddata_read_en = rc1_packet.valid && rc1_packet.cache_type == CT_DCACHE;
	assign rc_ddata_read_set = dcache_addr.set_idx;
	assign rc_ddata_read_way = fill_way_idx;
	
	always_ff @(posedge clk, posedge reset)
	begin
		if (reset)
		begin
			/*AUTORESET*/
			// Beginning of autoreset for uninitialized flops
			rc2_dcache_miss_entry <= {(1+($clog2(`THREADS_PER_CORE)-1)){1'b0}};
			rc2_evicted_line_addr <= 1'h0;
			rc2_fill_way_idx <= 1'h0;
			rc2_icache_miss_entry <= {(1+($clog2(`THREADS_PER_CORE)-1)){1'b0}};
			rc2_need_writeback <= 1'h0;
			rc2_packet <= 1'h0;
			// End of automatics
		end
		else
		begin
			rc2_fill_way_idx <= fill_way_idx;
			rc2_packet <= rc1_packet;
			rc2_need_writeback <= dt_snoop_state[snoop_hit_way_idx] == CL_STATE_MODIFIED
				&& is_ack_for_me && rc1_packet.cache_type == CT_DCACHE;
			rc2_evicted_line_addr <= { dt_snoop_tag[snoop_hit_way_idx], dcache_addr.set_idx, 
				{`CACHE_LINE_OFFSET_WIDTH{1'b0}} };
			rc2_dcache_miss_entry <= rc1_dcache_miss_entry;
			rc2_icache_miss_entry <= rc1_icache_miss_entry;

			// Ensure we don't receive a response for something we don't know about.
			assert(!is_ack_for_me || rc1_icache_miss_pending || rc1_dcache_miss_pending);
		end
	end
endmodule

// Local Variables:
// verilog-typedef-regexp:"_t$"
// End:


