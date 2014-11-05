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

`include "defines.sv"

//
// This is a component of each core that handles communications between L1 and L2 caches. 
// - Tracks pending read misses from L1 instruction and data caches
// - Tracks pending stores from L1 data cache
// - Arbitrates various miss sources and sends L2 cache requests.
// - Processes L2 responses, updating upper level caches.
//
// l2_request is asserted regardless of the state of l2_ready.
//
// Processing an L2 response takes three cycles
// 1. The address in the response is sent to the L1D tag memory (which has one cycle of latency)
//    to snoop it.
// 2. The snoop response is checked.  If the data is in the cache, the way is selected for update.
//    Tag memory is updated.
// 3. L1D data memory is updated.  This must be done a cycle after the tags are updated to avoid
//    a race condition because they are checked in this order by the instruction pipeline.
//

module l2_cache_interface
	#(parameter CORE_ID = 0)
	(input                                        clk,
	input                                         reset,

	// To l2_cache
	output l2req_packet_t                         l2i_request,

	// From l2_cache
	input                                         l2_ready,
	input l2rsp_packet_t                          l2_response,
	
	// To ifetch_tag_stage
	output                                        l2i_icache_lru_fill_en,
	output l1i_set_idx_t                          l2i_icache_lru_fill_set,
	output [`L1I_WAYS - 1:0]                      l2i_itag_update_en_oh,
	output l1i_set_idx_t                          l2i_itag_update_set,
	output l1i_tag_t                              l2i_itag_update_tag,
	output logic                                  l2i_itag_update_valid,
	
	// From ifetch_tag_stage
	input l1i_way_idx_t                           ift_fill_lru,
	
	// To ifetch_data_stage
	output                                        l2i_idata_update_en,
	output l1i_way_idx_t                          l2i_idata_update_way,
	output l1i_set_idx_t                          l2i_idata_update_set,
	output cache_line_data_t                      l2i_idata_update_data,
		
	// From ifetch_data_stage
	input logic                                   ifd_cache_miss,
	input scalar_t                                ifd_cache_miss_addr,
	input thread_idx_t                            ifd_cache_miss_thread_idx,

	// To thread_select_stage  
	output thread_bitmap_t                        l2i_dcache_wake_bitmap,
	output thread_bitmap_t                        l2i_icache_wake_bitmap,
	
	// To dcache_tag_stage
	output logic                                  l2i_snoop_en,
	output l1d_set_idx_t                          l2i_snoop_set,
	output [`L1D_WAYS - 1:0]                      l2i_dtag_update_en_oh,
	output l1d_set_idx_t                          l2i_dtag_update_set,
	output l1d_tag_t                              l2i_dtag_update_tag,
	output logic                                  l2i_dtag_update_valid,
	output                                        l2i_dcache_lru_fill_en,
	output l1d_set_idx_t                          l2i_dcache_lru_fill_set,

	// From dcache_tag_stage
	input logic                                   dt_snoop_valid[`L1D_WAYS],
	input l1d_tag_t                               dt_snoop_tag[`L1D_WAYS],
	input l1d_way_idx_t                           dt_fill_lru,
	
	// To dcache_data_stage
	output                                        l2i_ddata_update_en,
	output l1d_way_idx_t                          l2i_ddata_update_way,
	output l1d_set_idx_t                          l2i_ddata_update_set,
	output cache_line_data_t                      l2i_ddata_update_data,

	// From dcache_data_stage
	input                                         dd_cache_miss,
	input scalar_t                                dd_cache_miss_addr,
	input thread_idx_t                            dd_cache_miss_thread_idx,
	input                                         dd_cache_miss_synchronized,
	input                                         dd_store_en,
	input                                         dd_flush_en,
	input                                         dd_membar_en,
	input [`CACHE_LINE_BYTES - 1:0]               dd_store_mask,
	input scalar_t                                dd_store_addr,
	input cache_line_data_t                       dd_store_data,
	input thread_idx_t                            dd_store_thread_idx,
	input                                         dd_store_synchronized,
	input scalar_t                                dd_store_bypass_addr,
	input thread_idx_t                            dd_store_bypass_thread_idx,

	// To writeback stage
	output [`CACHE_LINE_BYTES - 1:0]              sq_store_bypass_mask,
	output logic                                  sq_store_sync_success,
	output cache_line_data_t                      sq_store_bypass_data,
	output                                        sq_rollback_en);	

	logic[`L1D_WAYS - 1:0] snoop_hit_way_oh;	// Only snoops dcache
	l1d_way_idx_t snoop_hit_way_idx;
	logic[`L1I_WAYS - 1:0] ifill_way_oh;	
	logic[`L1D_WAYS - 1:0] dfill_way_oh;	
	l1d_way_idx_t dfill_way_idx;
	logic is_ack_for_me;
	logic icache_update_en;
	logic dcache_update_en;
	logic dcache_l2_response_valid;
	l1_miss_entry_idx_t dcache_l2_response_idx;
	logic icache_l2_response_valid;
	l1_miss_entry_idx_t icache_l2_response_idx;
	logic storebuf_l2_response_valid;
	l1_miss_entry_idx_t storebuf_l2_response_idx;
	thread_bitmap_t sq_wake_bitmap;
	thread_bitmap_t dcache_miss_wake_bitmap;
	logic sq_dequeue_ready;
	logic sq_dequeue_ack;
	scalar_t sq_dequeue_addr;
	l1_miss_entry_idx_t sq_dequeue_idx;
	logic [`CACHE_LINE_BYTES - 1:0] sq_dequeue_mask;
	cache_line_data_t sq_dequeue_data;
	logic sq_dequeue_synchronized;
	logic icache_dequeue_ready;
	logic icache_dequeue_ack;
	logic dcache_dequeue_ready;
	logic dcache_dequeue_ack;
	scalar_t dcache_dequeue_addr;
	logic dcache_dequeue_synchronized;
	scalar_t icache_dequeue_addr;
	l1_miss_entry_idx_t dcache_dequeue_idx;
	l1_miss_entry_idx_t icache_dequeue_idx;
	l2rsp_packet_t response_stage2;
	l1d_addr_t dcache_addr_stage1;
	l1i_addr_t icache_addr_stage1;
	l1d_addr_t dcache_addr_stage2;
	l1i_addr_t icache_addr_stage2;
	logic storebuf_l2_sync_success;
	logic sq_dequeue_flush;

	l1_store_queue l1_store_queue(.*);

	l1_load_miss_queue l1_load_miss_queue_dcache(
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
		.dequeue_synchronized(dcache_dequeue_synchronized),

		// Wake threads when a transaction is complete
		.l2_response_valid(dcache_l2_response_valid),	
		.l2_response_idx(dcache_l2_response_idx),
		.wake_bitmap(dcache_miss_wake_bitmap),
		.*);
		
	assign l2i_dcache_wake_bitmap = dcache_miss_wake_bitmap | sq_wake_bitmap;

	l1_load_miss_queue l1_load_miss_queue_icache(
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
		.dequeue_synchronized(),

		// Wake threads when a transaction is complete
		.l2_response_valid(icache_l2_response_valid),
		.l2_response_idx(icache_l2_response_idx),
		.wake_bitmap(l2i_icache_wake_bitmap),
		.*);
	
	/////////////////////////////////////////////////
	// Response pipeline stage 1
	/////////////////////////////////////////////////
	assign dcache_addr_stage1 = l2_response.address;
	assign icache_addr_stage1 = l2_response.address;
	assign l2i_snoop_en = l2_response.valid && l2_response.cache_type == CT_DCACHE;
	assign l2i_snoop_set = dcache_addr_stage1.set_idx;
	assign l2i_dcache_lru_fill_en = l2_response.valid && l2_response.cache_type == CT_DCACHE
		&& l2_response.packet_type == L2RSP_LOAD_ACK && l2_response.core == CORE_ID;
	assign l2i_dcache_lru_fill_set = dcache_addr_stage1.set_idx;
	assign l2i_icache_lru_fill_en = l2_response.valid && l2_response.cache_type == CT_ICACHE
		&& l2_response.packet_type == L2RSP_LOAD_ACK && l2_response.core == CORE_ID;
	assign l2i_icache_lru_fill_set = icache_addr_stage1.set_idx;
		
	always_ff @(posedge clk, posedge reset)
	begin
		if (reset)
			response_stage2 <= 0;
		else
		begin
			// Should not get a wake from miss queue and store queue in the same cycle.
			assert(!(dcache_miss_wake_bitmap & sq_wake_bitmap));
			
			response_stage2 <= l2_response;
		end
	end
	
	/////////////////////////////////////////////////
	// Response pipeline stage 2
	/////////////////////////////////////////////////

	assign dcache_addr_stage2 = response_stage2.address;
	assign icache_addr_stage2 = response_stage2.address;	

	//
	// Check snoop result
	//
	genvar way_idx;
	generate
		for (way_idx = 0; way_idx < `L1D_WAYS; way_idx++)
		begin : snoop_hit_check_gen
			assign snoop_hit_way_oh[way_idx] = dt_snoop_tag[way_idx] == dcache_addr_stage2.tag 
				&& dt_snoop_valid[way_idx];
		end
	endgenerate

	oh_to_idx #(.NUM_SIGNALS(`L1D_WAYS)) convert_snoop_request_pending(
		.index(snoop_hit_way_idx),
		.one_hot(snoop_hit_way_oh));

	//
	// Determine fill way
	//
	always_comb
	begin
		if (|snoop_hit_way_oh)
			dfill_way_idx = snoop_hit_way_idx; // Update existing dcache line
		else
			dfill_way_idx = dt_fill_lru;	 // Fill new dcache line
	end

	idx_to_oh #(.NUM_SIGNALS(`L1D_WAYS)) idx_to_oh_dfill_way(
		.index(dfill_way_idx),
		.one_hot(dfill_way_oh));

	idx_to_oh #(.NUM_SIGNALS(`L1D_WAYS)) idx_to_oh_ifill_way(
		.index(ift_fill_lru),
		.one_hot(ifill_way_oh));

	assign is_ack_for_me = response_stage2.valid && response_stage2.core == CORE_ID;

	//
	// Update data cache tag
	//
	assign dcache_update_en = is_ack_for_me && ((response_stage2.packet_type == L2RSP_LOAD_ACK
		&& response_stage2.cache_type == CT_DCACHE) || response_stage2.packet_type == L2RSP_STORE_ACK);
	assign l2i_dtag_update_en_oh = dfill_way_oh & {`L1D_WAYS{dcache_update_en}};
	assign l2i_dtag_update_tag = dcache_addr_stage2.tag;	
	assign l2i_dtag_update_set = dcache_addr_stage2.set_idx;
	assign l2i_dtag_update_valid = 1'b1;

	//
	// Update instruction cache tag
	//
	assign icache_update_en = is_ack_for_me && response_stage2.cache_type == CT_ICACHE;
	assign l2i_itag_update_en_oh = ifill_way_oh & {`L1I_WAYS{icache_update_en}};
	assign l2i_itag_update_tag = icache_addr_stage2.tag;	
	assign l2i_itag_update_set = icache_addr_stage2.set_idx;
	assign l2i_itag_update_valid = 1'b1;

	// Wake up entries that have had their miss satisfied.
	assign icache_l2_response_valid = is_ack_for_me && response_stage2.cache_type == CT_ICACHE;
	assign dcache_l2_response_valid = is_ack_for_me && response_stage2.packet_type == L2RSP_LOAD_ACK
		&& response_stage2.cache_type == CT_DCACHE;
	assign storebuf_l2_response_valid = is_ack_for_me && (response_stage2.packet_type == L2RSP_STORE_ACK
		|| response_stage2.packet_type == L2RSP_FLUSH_ACK);
	assign dcache_l2_response_idx = response_stage2.id;
	assign icache_l2_response_idx = response_stage2.id;
	assign storebuf_l2_response_idx = response_stage2.id;	
	assign storebuf_l2_sync_success = response_stage2.status;

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
			l2i_ddata_update_en <= dcache_update_en || (|snoop_hit_way_oh && response_stage2.valid
				&& response_stage2.packet_type == L2RSP_STORE_ACK);
			l2i_ddata_update_way <= dfill_way_idx;	
			l2i_ddata_update_set <= dcache_addr_stage2.set_idx;
			l2i_ddata_update_data <= response_stage2.data;

			// Update cache line for instruction cache
			l2i_idata_update_en <= icache_update_en;
			l2i_idata_update_way <= ift_fill_lru;	
			l2i_idata_update_set <= icache_addr_stage2.set_idx;
			l2i_idata_update_data <= response_stage2.data;
		end
	end

	/////////////////////////////////////////////////
	// Request logic
	/////////////////////////////////////////////////

	always_comb
	begin
		l2i_request = 0;	
		sq_dequeue_ack = 0;
		icache_dequeue_ack = 0;
		dcache_dequeue_ack = 0;

		l2i_request.core = CORE_ID;

		// Assert the request
		if (dcache_dequeue_ready)
		begin
			// Send data cache request packet
			l2i_request.valid = 1;
			l2i_request.packet_type = dcache_dequeue_synchronized ? L2REQ_LOAD_SYNC : L2REQ_LOAD; 
			l2i_request.id = dcache_dequeue_idx;
			l2i_request.address = dcache_dequeue_addr;
			l2i_request.cache_type = CT_DCACHE;
		end
		else if (icache_dequeue_ready)
		begin
			// Send instruction cache request packet
			l2i_request.valid = 1;
			l2i_request.packet_type = L2REQ_LOAD; 
			l2i_request.id = icache_dequeue_idx;
			l2i_request.address = icache_dequeue_addr;
			l2i_request.cache_type = CT_ICACHE;
		end
		else if (sq_dequeue_ready)
		begin
			// Send store request 
			l2i_request.valid = 1;
			if (sq_dequeue_flush)
				l2i_request.packet_type = L2REQ_FLUSH; 
			else if (sq_dequeue_synchronized)
				l2i_request.packet_type = L2REQ_STORE_SYNC; 
			else
				l2i_request.packet_type = L2REQ_STORE; 
			
			l2i_request.id = sq_dequeue_idx;
			l2i_request.address = sq_dequeue_addr;
			l2i_request.data = sq_dequeue_data;
			l2i_request.store_mask = sq_dequeue_mask;
			l2i_request.cache_type = CT_DCACHE;
		end
	
		if (l2_ready)
		begin
			// Request acknowledged, mark it as sent
			if (dcache_dequeue_ready)
				dcache_dequeue_ack = 1;
			else if (icache_dequeue_ready)
				icache_dequeue_ack = 1;
			else if (sq_dequeue_ready)
				sq_dequeue_ack = 1;
		end
	end
endmodule

// Local Variables:
// verilog-typedef-regexp:"_t$"
// End:
