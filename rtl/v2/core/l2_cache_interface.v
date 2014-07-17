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
// Handles communications between L1 and L2 caches, abstracting details of the interconnect
// from the instruction pipeline.
// - Tracks pending read misses from L1 instruction and data caches
// - Tracks pending stores from L1 data cache
// - Arbitrates various miss sources and formats L2 cache requests.
// - Handles L2 responses, updating upper level caches.
//

module l2_cache_interface
	#(parameter CORE_ID = 0)
	(input                                        clk,
	input                                         reset,
	input                                         l2_ready,
	output l2req_packet_t                         l2i_request,
	input l2rsp_packet_t                          l2_response,
	
	// To instruction pipeline     
	output [`THREADS_PER_CORE - 1:0]              l2i_dcache_wake_oh,
	output [`THREADS_PER_CORE - 1:0]              l2i_icache_wake_oh,
	
	// To/from L1 data cache
	output logic                                  l2i_snoop_en,
	output l1d_set_idx_t                          l2i_snoop_set,
	output [`L1D_WAYS - 1:0]                      l2i_dtag_update_en_oh,
	output l1d_set_idx_t                          l2i_dtag_update_set,
	output l1d_tag_t                              l2i_dtag_update_tag,
	output logic                                  l2i_dtag_update_valid,
	input logic                                   dt_snoop_valid[`L1D_WAYS],
	input l1d_tag_t                               dt_snoop_tag[`L1D_WAYS],
	input l1d_way_idx_t                           dt_snoop_lru,
	input                                         dd_cache_miss,
	input scalar_t                                dd_cache_miss_addr,
	input thread_idx_t                            dd_cache_miss_thread_idx,
	input                                         dd_cache_miss_synchronized,
	input                                         dd_store_en,
	input [`CACHE_LINE_BYTES - 1:0]               dd_store_mask,
	input scalar_t                                dd_store_addr,
	input [`CACHE_LINE_BITS - 1:0]                dd_store_data,
	input thread_idx_t                            dd_store_thread_idx,
	input                                         dd_store_synchronized,
	input scalar_t                                dd_store_bypass_addr,
	input thread_idx_t                            dd_store_bypass_thread_idx,
	output                                        sb_store_bypass_mask,
	output [`CACHE_LINE_BITS - 1:0]               sb_store_bypass_data,
	output                                        sb_full_rollback,
	output                                        l2i_ddata_update_en,
	output l1d_way_idx_t                          l2i_ddata_update_way,
	output l1d_set_idx_t                          l2i_ddata_update_set,
	output [`CACHE_LINE_BITS - 1:0]               l2i_ddata_update_data,
                                                 
	// To/from instruction cache                 
	output                                        l2i_ilru_read_en,
	output l1i_set_idx_t                          l2i_ilru_read_set,
	output [`L1I_WAYS - 1:0]                      l2i_itag_update_en_oh,
	output l1i_set_idx_t                          l2i_itag_update_set,
	output l1i_tag_t                              l2i_itag_update_tag,
	output logic                                  l2i_itag_update_valid,
	input l1i_way_idx_t                           ift_lru,
	input logic                                   ifd_cache_miss,
	input scalar_t                                ifd_cache_miss_addr,
	input thread_idx_t                            ifd_cache_miss_thread_idx,
	output                                        l2i_idata_update_en,
	output l1i_way_idx_t                          l2i_idata_update_way,
	output l1i_set_idx_t                          l2i_idata_update_set,
	output [`CACHE_LINE_BITS - 1:0]               l2i_idata_update_data);	

	logic[`L1D_WAYS - 1:0] snoop_hit_way_oh;	// Only snoops dcache
	l1d_way_idx_t snoop_hit_way_idx;
	logic[`L1D_WAYS - 1:0] fill_way_oh;	
	l1d_way_idx_t fill_way_idx;
	logic is_ack_for_me;
	logic icache_update_en;
	logic dcache_update_en;
	logic dcache_wake_en;
	l1_miss_entry_idx_t dcache_wake_idx;
	logic icache_wake_en;
	l1_miss_entry_idx_t icache_wake_idx;
	logic storebuf_wake_en;
	l1_miss_entry_idx_t storebuf_wake_idx;
	logic [`THREADS_PER_CORE - 1:0] sb_wake_oh;
	logic [`THREADS_PER_CORE - 1:0] dcache_miss_wake_oh;
	l2req_packet_t request_nxt;
	logic sb_dequeue_ready;
	logic sb_dequeue_ack;
	scalar_t sb_dequeue_addr;
	l1_miss_entry_idx_t sb_dequeue_idx;
	logic [`CACHE_LINE_BYTES - 1:0] sb_dequeue_mask;
	logic [`CACHE_LINE_BITS - 1:0] sb_dequeue_data;
	logic icache_dequeue_ready;
	logic icache_dequeue_ack;
	logic dcache_dequeue_ready;
	logic dcache_dequeue_ack;
	scalar_t dcache_dequeue_addr;
	scalar_t icache_dequeue_addr;
	l1_miss_entry_idx_t dcache_dequeue_idx;
	l1_miss_entry_idx_t icache_dequeue_idx;
	l2rsp_packet_t response_stage2;
	l1d_addr_t dcache_addr_stage1;
	l1i_addr_t icache_addr_stage1;
	l1d_addr_t dcache_addr_stage2;
	l1i_addr_t icache_addr_stage2;

	l1_store_buffer store_buffer(.*);

	l1_miss_queue dcache_miss_queue(
		// Enqueue requests
		.cache_miss(dd_cache_miss),
		.cache_miss_addr(dd_cache_miss_addr),
		.cache_miss_thread_idx(dd_cache_miss_thread_idx),
		.cache_miss_synchronized(dd_cache_miss_synchronized),

		// Next request
		.dequeue_ready(dcache_dequeue_ready),
		.dequeue_ack(dcache_dequeue_ack),
		.dequeue_addr(dcache_dequeue_addr),
		.dequeue_idx(dcache_dequeue_idx),

		// Wake threads when a transaction is complete
		.wake_en(dcache_wake_en),	
		.wake_idx(dcache_wake_idx),
		.wake_oh(dcache_miss_wake_oh),
		.*);
		
	assign l2i_dcache_wake_oh = dcache_miss_wake_oh | sb_wake_oh;

	l1_miss_queue icache_miss_queue(
		// Enqueue requests
		.cache_miss(ifd_cache_miss),
		.cache_miss_addr(ifd_cache_miss_addr),
		.cache_miss_thread_idx(ifd_cache_miss_thread_idx),
		.cache_miss_synchronized(0),

		// Next request
		.dequeue_ready(icache_dequeue_ready),
		.dequeue_ack(icache_dequeue_ack),
		.dequeue_addr(icache_dequeue_addr),
		.dequeue_idx(icache_dequeue_idx),

		// Wake threads when a transaction is complete
		.wake_en(icache_wake_en),
		.wake_idx(icache_wake_idx),
		.wake_oh(l2i_icache_wake_oh),
		.*);
	
	/////////////////////////////////////////////////
	// Response pipeline stage 1
	/////////////////////////////////////////////////
	assign dcache_addr_stage1 = l2_response.address;
	assign icache_addr_stage1 = l2_response.address;
	assign l2i_snoop_en = l2_response.valid && l2_response.cache_type == CT_DCACHE;
	assign l2i_snoop_set = dcache_addr_stage1.set_idx;
	assign l2i_ilru_read_en = l2_response.valid && l2_response.cache_type == CT_ICACHE;
	assign l2i_ilru_read_set = icache_addr_stage1.set_idx;
		
	always_ff @(posedge clk, posedge reset)
	begin
		if (reset)
			response_stage2 <= 0;
		else
			response_stage2 <= l2_response;
	end
	
	/////////////////////////////////////////////////
	// Response pipeline stage 2
	/////////////////////////////////////////////////

	assign dcache_addr_stage2 = response_stage2.address;
	assign icache_addr_stage2 = response_stage2.address;	
	assign is_ack_for_me = response_stage2.valid && response_stage2.core == CORE_ID;

	//
	// Check snoop result
	//
	genvar way_idx;
	generate
		for (way_idx = 0; way_idx < `L1D_WAYS; way_idx++)
		begin
			assign snoop_hit_way_oh[way_idx] = dt_snoop_tag[way_idx] == dcache_addr_stage2.tag 
				&& dt_snoop_valid[way_idx];
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
		if (response_stage2.cache_type == CT_ICACHE)
			fill_way_idx = ift_lru;		      // Fill new icache line
		else if (|snoop_hit_way_oh)
			fill_way_idx = snoop_hit_way_idx; // Update existing dcache line
		else
			fill_way_idx = dt_snoop_lru;	 // Fill new dcache line
	end

	index_to_one_hot #(.NUM_SIGNALS(`L1D_WAYS)) convert_tag_update(
		.index(fill_way_idx),
		.one_hot(fill_way_oh));

	//
	// Update data cache tag
	//
	assign l2i_dtag_update_en_oh = fill_way_oh & {`L1D_WAYS{dcache_update_en}};
	assign l2i_dtag_update_tag = dcache_addr_stage2.tag;	
	assign l2i_dtag_update_set = dcache_addr_stage2.set_idx;

	//
	// Update instruction cache tag
	//
	assign icache_update_en = is_ack_for_me && response_stage2.cache_type == CT_ICACHE;
	assign l2i_itag_update_en_oh = fill_way_oh & {`L1I_WAYS{icache_update_en}};
	assign l2i_itag_update_tag = icache_addr_stage2.tag;	
	assign l2i_itag_update_set = icache_addr_stage2.set_idx;
	assign l2i_itag_update_valid = 1'b1;

	// Wake up entries that have had their miss satisfied.
	assign icache_wake_en = is_ack_for_me && response_stage2.cache_type == CT_ICACHE;

	assign dcache_wake_idx = response_stage2.id;
	assign icache_wake_idx = response_stage2.id;
	assign storebuf_wake_idx = response_stage2.id;	

	always_comb
	begin
		dcache_wake_en = 0;
		dcache_update_en = 0;
		storebuf_wake_en = 0;
		l2i_dtag_update_valid = 0;

		if (response_stage2.valid)
		begin
			// message handling
			case (response_stage2.packet_type)
				L2RSP_LOAD_ACK:
				begin
					if (response_stage2.cache_type == CT_ICACHE)
					begin
						icache_wake_en = 1;
						icache_update_en = 1;
					end
					else
					begin
						dcache_wake_en = 1;
						dcache_update_en = 1;
					end

					l2i_dtag_update_valid = 1;
				end
				
				L2RSP_STORE_ACK:
				begin
					dcache_update_en = 1;
					storebuf_wake_en = 1;
				end
			endcase
		end
	end

	always_ff @(posedge clk, posedge reset)
	begin
		if (reset)
		begin
			l2i_ddata_update_en <= 0;
			l2i_ddata_update_way <= 0;	
			l2i_ddata_update_set <= 0;
			l2i_ddata_update_data <= 0;
			l2i_idata_update_en <= 0;
			l2i_idata_update_way <= 0;	
			l2i_idata_update_set <= 0;
			l2i_idata_update_data <= 0;
		end
		else
		begin
			// These are latched to delay then one cycle from the tag updates
			// Update cache line for data cache
			l2i_ddata_update_en <= dcache_update_en;
			l2i_ddata_update_way <= fill_way_idx;	
			l2i_ddata_update_set <= dcache_addr_stage2.set_idx;
			l2i_ddata_update_data <= response_stage2.data;

			// Update cache line for instruction cache
			l2i_idata_update_en <= icache_update_en;
			l2i_idata_update_way <= fill_way_idx;	
			l2i_idata_update_set <= icache_addr_stage2.set_idx;
			l2i_idata_update_data <= response_stage2.data;
		end
	end

	/////////////////////////////////////////////////
	// Request logic
	/////////////////////////////////////////////////

	always_comb
	begin
		request_nxt = 0;	
		sb_dequeue_ack = 0;
		icache_dequeue_ack = 0;
		dcache_dequeue_ack = 0;

		if (l2_ready)
		begin
			if (dcache_dequeue_ready)
			begin
				// Send data cache request packet
				dcache_dequeue_ack = 1;
				request_nxt.valid = 1;
				request_nxt.core = CORE_ID;
				request_nxt.packet_type = L2REQ_LOAD; 
				request_nxt.id = dcache_dequeue_idx;
				request_nxt.address = dcache_dequeue_addr;
				request_nxt.cache_type = CT_DCACHE;
			end
			else if (icache_dequeue_ready)
			begin
				// Send instruction cache request packet
				icache_dequeue_ack = 1;
				request_nxt.valid = 1;
				request_nxt.packet_type = L2REQ_LOAD; 
				request_nxt.core = CORE_ID;
				request_nxt.id = icache_dequeue_idx;
				request_nxt.address = icache_dequeue_addr;
				request_nxt.cache_type = CT_ICACHE;
			end
			else if (sb_dequeue_ready)
			begin
				// Send store request 
				sb_dequeue_ack = 1;
				request_nxt.valid = 1;
				request_nxt.packet_type = L2REQ_STORE; 
				request_nxt.core = CORE_ID;
				request_nxt.id = sb_dequeue_idx;
				request_nxt.address = sb_dequeue_addr;
				request_nxt.data = sb_dequeue_data;
				request_nxt.store_mask = sb_dequeue_mask;
				request_nxt.cache_type = CT_DCACHE;
			end
		end
	end
	
	always_ff @(posedge clk, posedge reset)
	begin
		if (reset)
		begin
			l2i_request <= 0;
		end
		else
		begin
			l2i_request <= request_nxt;
		end
	end
endmodule

// Local Variables:
// verilog-typedef-regexp:"_t$"
// End:
