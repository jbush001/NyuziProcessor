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
// The ring controller processes packets passing through the ring and
// inserts messages where appropriate.  It sets control signals to update L1
// caches. Packets flow through a three stage pipeline.
//

module ring_controller
	#(parameter NODE_ID = 0)
	(input                                  clk,
	input                                  reset,
	
	// Ring interface
	input ring_packet_t                    packet_in,
	output ring_packet_t                   packet_out,
	
	// To instruction pipeline
	output [`L1D_WAYS - 1:0]               rc_dtag_update_en_oh,
	output l1d_set_idx_t                   rc_dtag_update_set,
	output l1d_tag_t                       rc_dtag_update_tag,
	output cache_line_state_t              rc_dtag_update_state,
	output                                 rc_ddata_update_en,
	output l1d_way_idx_t                   rc_ddata_update_way,
	output l1d_set_idx_t                   rc_ddata_update_set,
	output [`CACHE_LINE_BITS - 1:0]        rc_ddata_update_data,
	output [`THREADS_PER_CORE - 1:0]       rc_dcache_wake_oh,
	output                                 rc_ddata_read_en,
	output l1d_set_idx_t                   rc_ddata_read_set,
 	output l1d_way_idx_t                   rc_ddata_read_way,
	output logic                           rc_snoop_en,
	output l1d_set_idx_t                   rc_snoop_set,
	input cache_line_state_t               dt_snoop_state[`L1D_WAYS],
	input l1d_tag_t                        dt_snoop_tag[`L1D_WAYS],
	input l1d_way_idx_t                    dt_snoop_lru,
	input                                  dd_cache_miss,
	input scalar_t                         dd_cache_miss_addr,
	input                                  dd_cache_miss_store,
	input thread_idx_t                     dd_cache_miss_thread_idx,
	input logic[`CACHE_LINE_BITS - 1:0]    dd_ddata_read_data);

	ring_packet_t packet1;
	ring_packet_t packet2;
	ring_packet_t packet_out_nxt;
	logic request_ready;
	scalar_t request_address;
	logic request_ack;
	logic dcache_miss_pending1;
	logic dcache_miss_pending2;
	logic[`THREADS_PER_CORE - 1:0] dcache_miss_entry1;
	logic[`THREADS_PER_CORE - 1:0] dcache_miss_entry2;
	logic[`L1D_WAYS - 1:0] snoop_hit_way_oh;
	pending_miss_state_t pending_miss_state1;
	logic dcache_request_ready;
	scalar_t dcache_request_address;
	logic dcache_request_store;
	logic dcache_request_ack;
	l1d_addr_t cache_addr1;
	l1d_addr_t cache_addr2;
	l1d_way_idx_t snoop_hit_way_idx;
	logic dcache_snoop_hit;
	l1d_way_idx_t fill_way_idx1;
	l1d_way_idx_t fill_way_idx2;
	logic[`L1D_WAYS - 1:0] fill_way_oh1;	
	logic need_writeback2;
	scalar_t evicted_line_addr2;
		
	l1_miss_queue dcache_miss_queue(
		// Enqueue new requests
		.cache_miss(dd_cache_miss),
		.cache_miss_addr(dd_cache_miss_addr),
		.cache_miss_store(dd_cache_miss_store),
		.cache_miss_thread_idx(dd_cache_miss_thread_idx),

		// Check existing transactions
		.snoop_en(packet_in.valid),
		.snoop_addr(packet_in.address),
		.snoop_hit(dcache_snoop_hit),
		.snoop_hit_entry(dcache_miss_entry1),
		.snoop_state(pending_miss_state1),

		// Wake threads when a transaction is complete
		.wake_en(packet2.valid && dcache_miss_pending2),
		.wake_entry(dcache_miss_entry2),

		// Insert new requests into ring
		.request_ready(dcache_request_ready),
		.request_address(dcache_request_address),
		.request_store(dcache_request_store),      
		.request_ack(dcache_request_ack),
		.*);
	
	//////////////////////////////////////////////////////////////////////////////
	// Stage 1.  Issue snoop request to L1 tags and check miss queue.
	//////////////////////////////////////////////////////////////////////////////
	assign rc_snoop_en = packet_in.valid;
	assign rc_snoop_set = packet_in[`CACHE_LINE_OFFSET_WIDTH+:$clog2(`L1D_SETS)];
	
	always_ff @(posedge clk, posedge reset)
	begin
		if (reset)
			packet1 <= 0;
		else
			packet1 <= packet_in;
	end
	
	//////////////////////////////////////////////////////////////////////////////
	// Stage 2. Update the tag and read an old line if one is to be evicted
	//////////////////////////////////////////////////////////////////////////////
	assign cache_addr1 = packet1.address;
	assign dcache_miss_pending1 = dcache_snoop_hit && packet1.valid;

	genvar way_idx;
	generate
		for (way_idx = 0; way_idx < `L1D_WAYS; way_idx++)
		begin
			assign snoop_hit_way_oh[way_idx] = dt_snoop_tag[way_idx] == cache_addr1.tag 
				&& dt_snoop_state[way_idx] != CL_STATE_INVALID;
		end
	endgenerate

	one_hot_to_index #(.NUM_SIGNALS(`L1D_WAYS)) convert_snoop_hit(
		.index(snoop_hit_way_idx),
		.one_hot(snoop_hit_way_oh));

	assign fill_way_idx1 = |snoop_hit_way_oh ? snoop_hit_way_idx : dt_snoop_lru;

	index_to_one_hot #(.NUM_SIGNALS(`L1D_WAYS)) convert_tag_update(
		.index(fill_way_idx1),
		.one_hot(fill_way_oh1));

	assign rc_dtag_update_en_oh = fill_way_oh1 && {`L1D_WAYS{packet1.valid}};
	assign rc_dtag_update_tag = cache_addr1.tag;	
	assign rc_dtag_update_set = cache_addr1.set_idx;
	assign rc_dtag_update_state = pending_miss_state1 == PM_READ_PENDING ? CL_STATE_SHARED
		: CL_STATE_MODIFIED;

	assign rc_ddata_read_en = packet1.valid && dcache_miss_pending1;
	assign rc_ddata_read_set = cache_addr1.set_idx;
	assign rc_ddata_read_way = fill_way_idx1;
	
	always_ff @(posedge clk, posedge reset)
	begin
		if (reset)
		begin
			fill_way_idx2 <= 0;
			packet2 <= 0;
			dcache_miss_entry2 <= 0;
			dcache_miss_pending2 <= 0;
		end
		else
		begin
			fill_way_idx2 <= fill_way_idx1;
			packet2 <= packet1;
			dcache_miss_entry2 <= dcache_miss_entry1;
			dcache_miss_pending2 <= dcache_miss_pending1;
			need_writeback2 <= dt_snoop_state[snoop_hit_way_idx] == CL_STATE_MODIFIED;
			evicted_line_addr2 <= {dt_snoop_tag[snoop_hit_way_idx], cache_addr1.set_idx, {`CACHE_LINE_OFFSET_WIDTH{1'b0}}};
		end
	end
	
	//////////////////////////////////////////////////////////////////////////////
	// Stage 3. Update cache data.
	// If there is an empty ring slot and a request is pending, issue it now.
	// Wake up threads if necessary.
	//////////////////////////////////////////////////////////////////////////////
	always_comb
	begin
		dcache_request_ack = 0;
		if (packet2.valid && (packet2.dest_node != NODE_ID || !packet2.ack))
			packet_out_nxt = packet2;	// Forward packet on (or retry nacked packet)
		else if (need_writeback2)
		begin
			// Insert L2 write ack packet
			packet_out_nxt.valid = 1;
			packet_out_nxt.packet_type = PKT_L2_WRITEBACK;
			packet_out_nxt.ack = 0;
			packet_out_nxt.l2_miss = 0;
			packet_out_nxt.dest_node = 0;	// XXX L2 node ID
			packet_out_nxt.address = evicted_line_addr2;
			packet_out_nxt.data = dd_ddata_read_data;
		end
		else if (dcache_request_ready)
		begin
			// Inject request packet into ring
			dcache_request_ack = 1;
			packet_out_nxt.valid = 1;
			packet_out_nxt.packet_type = dcache_request_store ? PKT_WRITE_INVALIDATE : PKT_READ_SHARED;
			packet_out_nxt.ack = 0;
			packet_out_nxt.l2_miss = 0;
			packet_out_nxt.dest_node = NODE_ID;
			packet_out_nxt.address = dcache_request_address;
		end
		else
			packet_out_nxt = 0;	// Empty packet
	end

	assign cache_addr2 = packet2.address;
	assign rc_ddata_update_en = packet2.valid && dcache_miss_pending2 && packet2.ack;
	assign rc_ddata_update_way = fill_way_idx2;	
	assign rc_ddata_update_set = cache_addr2.set_idx;
	assign rc_ddata_update_data = packet2.data;
	
	// XXX need to cancel entry in miss queue (probably should wake threads as side effect)
	// XXX should there be an identifier for the miss queue entry?
	
	always_ff @(posedge clk, posedge reset)
	begin
		if (reset)
		begin
			packet_out <= 0;
		end
		else
		begin
			packet_out <= packet_out_nxt;
		end
	end
endmodule

// Local Variables:
// verilog-typedef-regexp:"_t$"
// End:


