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
// - Update pending entry state
//

module ring_controller_stage2
	#(parameter CORE_ID = 0)
	(input                                        clk,
	input                                         reset,
                                                  
	// From stage 1                               
	input ring_packet_t                           rc1_packet,
	input pending_miss_state_t                    rc1_dcache_miss_state,
	input logic                                   rc1_dcache_miss_pending,
	input l1_miss_entry_idx_t                     rc1_dcache_miss_entry,
	input logic                                   rc1_icache_miss_pending,
	input l1_miss_entry_idx_t                     rc1_icache_miss_entry,
	input                                         rc1_dcache_dequeue_ready,
	input scalar_t                                rc1_dcache_dequeue_addr,
	input pending_miss_state_t                    rc1_dcache_dequeue_state,
	input l1_miss_entry_idx_t                     rc1_dcache_dequeue_entry,
	input                                         rc1_icache_dequeue_ready,
	input scalar_t                                rc1_icache_dequeue_addr,
	input l1_miss_entry_idx_t                     rc1_icache_dequeue_entry,

	// To stage 1
	output logic                                  rc2_dcache_update_state_en,
	output pending_miss_state_t                   rc2_dcache_update_state,
	output l1_miss_entry_idx_t                    rc2_dcache_update_entry,
	output logic                                  rc2_icache_update_state_en,
	output pending_miss_state_t                   rc2_icache_update_state,
	output l1_miss_entry_idx_t                    rc2_icache_update_entry,
                                                  
	// To stage 3                                 
	output ring_packet_t                          rc2_packet,
	output logic                                  rc2_need_writeback,
	output scalar_t                               rc2_evicted_line_addr,
	output l1d_way_idx_t                          rc2_fill_way_idx,
	output logic                                  rc2_dcache_wake,
	output l1_miss_entry_idx_t                    rc2_dcache_wake_entry,
	output logic                                  rc2_icache_wake,
	output l1_miss_entry_idx_t                    rc2_icache_wake_entry,
	output logic                                  rc2_icache_update_en,
	output logic                                  rc2_dcache_update_en,
	
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
	logic icache_update_en;
	ring_packet_t packet_out_nxt;
	logic dcache_update_en;

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
		if (rc1_packet.cache_type == CT_ICACHE)
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
	assign rc_dtag_update_en_oh = fill_way_oh & {`L1D_WAYS{dcache_update_en}};
	assign rc_dtag_update_tag = dcache_addr.tag;	
	assign rc_dtag_update_set = dcache_addr.set_idx;

	//
	// Update instruction cache tag
	//
	assign icache_update_en = is_ack_for_me && rc1_packet.cache_type == CT_ICACHE;
	assign rc_itag_update_en_oh = fill_way_oh & {`L1I_WAYS{icache_update_en}};
	assign rc_itag_update_tag = icache_addr.tag;	
	assign rc_itag_update_set = icache_addr.set_idx;
	assign rc_itag_update_valid = 1'b1;

	//
	// Request old data for evicted cache line
	//
	assign rc_ddata_read_en = rc1_packet.valid && rc1_packet.cache_type == CT_DCACHE;
	assign rc_ddata_read_set = dcache_addr.set_idx;
	assign rc_ddata_read_way = fill_way_idx;

	// Wake up entries that have had their miss satisfied. It's safe to wake them here
	// (as opposed to stage 3) because tags are always checked a cycle before data.
	assign rc2_icache_wake = is_ack_for_me && rc1_packet.cache_type == CT_ICACHE;
	assign rc2_dcache_wake_entry = rc1_dcache_miss_entry;
	assign rc2_icache_wake_entry = rc1_icache_miss_entry;

	always_comb
	begin
		packet_out_nxt = 0;	
		rc2_dcache_update_state_en = 0;
		rc2_dcache_update_state = 0;
		rc2_icache_update_state_en = 0;
		rc2_icache_update_state = 0;
		rc2_dcache_update_entry = 0;
		rc2_icache_update_entry = 0;
		rc2_dcache_wake = 0;
		dcache_update_en = 0;
		rc_dtag_update_state = CL_STATE_INVALID;

		if (rc1_packet.valid)
		begin
			packet_out_nxt = rc1_packet;	// Pass through
			if (rc1_packet.packet_type == PKT_READ_SHARED && rc1_packet.dest_core == CORE_ID
				&& rc1_packet.ack && rc1_packet.cache_type == CT_DCACHE)
			begin
				// Response to dcache READ_SHARED request
				if (rc1_dcache_miss_state == PM_READ_SENT)
				begin
					rc2_dcache_wake = 1;	// Wake
					dcache_update_en = 1;
					rc_dtag_update_state = CL_STATE_SHARED;
				end
					
				// Note: if there isn't a read pending, it is probably because we upgraded a read
				// to a write.  Ignore this request.
			end
			else if (rc1_packet.packet_type == PKT_READ_SHARED && rc1_packet.dest_core != CORE_ID
				&& rc1_packet.cache_type == CT_DCACHE)
			begin
				// READ_SHARED request from another node.  If I am the owner for this node, I need
				// to update my state and respond.
				$display("unhandled READ_SHARED");
				$finish;
			end
			else if (rc1_packet.packet_type == PKT_WRITE_INVALIDATE && rc1_packet.dest_core == CORE_ID
				&& rc1_packet.ack)
			begin
				// Response to WRITE_INVALIDATE request
				rc2_dcache_wake = 1;	// Wake
				dcache_update_en = 1;
				rc_dtag_update_state = CL_STATE_MODIFIED;
			end
			else if (rc1_packet.packet_type == PKT_WRITE_INVALIDATE && rc1_packet.dest_core != CORE_ID)
			begin
				// WRITE_INVALIDATE request from another node. If I have this line cached, need to remove it.
				// If I'm the owner, I need to relenquish ownership.
				$display("unhandled WRITE_INVALIDATE");
				$finish;
			end
		end
		else if (rc1_dcache_dequeue_ready)
		begin
			// Inject data cache request packet into ring (flush, invalidate, write invalidate, or read shared)
			packet_out_nxt.valid = 1;
			packet_out_nxt.dest_core = CORE_ID;
			packet_out_nxt.address = rc1_dcache_dequeue_addr;
			packet_out_nxt.cache_type = CT_DCACHE;
			rc2_dcache_update_state_en = 1;
			if (rc1_dcache_dequeue_state == PM_WRITE_PENDING)
			begin
				packet_out_nxt.packet_type = PKT_WRITE_INVALIDATE;
				rc2_dcache_update_state = PM_WRITE_SENT;
			end
			else
			begin
				packet_out_nxt.packet_type = PKT_READ_SHARED;
				rc2_dcache_update_state = PM_READ_SENT;
			end
			
			rc2_dcache_update_entry = rc1_dcache_dequeue_entry;
		end
		else if (rc1_icache_dequeue_ready)
		begin
			// Inject instruction request packet into ring
			packet_out_nxt.valid = 1;
			packet_out_nxt.packet_type = PKT_READ_SHARED; 
			packet_out_nxt.dest_core = CORE_ID;
			packet_out_nxt.address = rc1_icache_dequeue_addr;
			packet_out_nxt.cache_type = CT_ICACHE;
			packet_out_nxt.packet_type = PKT_READ_SHARED;
			rc2_icache_update_state_en = 1;
			rc2_icache_update_state = PM_READ_SENT;
			rc2_icache_update_entry = rc1_icache_dequeue_entry;
		end
	end
	
	always_ff @(posedge clk, posedge reset)
	begin
		if (reset)
		begin
			/*AUTORESET*/
			// Beginning of autoreset for uninitialized flops
			rc2_dcache_update_en <= 1'h0;
			rc2_evicted_line_addr <= 1'h0;
			rc2_fill_way_idx <= 1'h0;
			rc2_icache_update_en <= 1'h0;
			rc2_need_writeback <= 1'h0;
			rc2_packet <= 1'h0;
			// End of automatics
		end
		else
		begin
			assert(!(is_ack_for_me && rc1_packet.cache_type == CT_ICACHE) || rc1_icache_miss_pending);
			assert(!(is_ack_for_me && rc1_packet.cache_type == CT_DCACHE) || rc1_dcache_miss_pending);

			rc2_fill_way_idx <= fill_way_idx;
			rc2_packet <= packet_out_nxt;
			rc2_need_writeback <= dt_snoop_state[snoop_hit_way_idx] == CL_STATE_MODIFIED
				&& is_ack_for_me && rc1_packet.cache_type == CT_DCACHE;
			rc2_evicted_line_addr <= { dt_snoop_tag[snoop_hit_way_idx], dcache_addr.set_idx, 
				{`CACHE_LINE_OFFSET_WIDTH{1'b0}} };
			rc2_icache_update_en <= icache_update_en;
			rc2_dcache_update_en <= dcache_update_en; 
		end
	end
endmodule

// Local Variables:
// verilog-typedef-regexp:"_t$"
// End:


