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
// - Check miss queues for pending instruction and data cache requests.
// - Inject new requests into ring if there is an empty slot and one is pending
//

module ring_controller_stage1
	#(parameter CORE_ID = 0)
	(input                                        clk,
	input                                         reset,
	                                             
	// From ring interface                       
	input ring_packet_t                           packet_in,
	                                             
	// To instruction pipeline                   
	output [`THREADS_PER_CORE - 1:0]              rc_dcache_wake_oh,
	output [`THREADS_PER_CORE - 1:0]              rc_icache_wake_oh,
                                                 
	// To stage 2                                
	output ring_packet_t                          rc1_packet,
	output pending_miss_state_t                   rc1_pending_miss_state,
	output logic                                  rc1_dcache_miss_pending,
	output logic[$clog2(`THREADS_PER_CORE) - 1:0] rc1_dcache_miss_entry,
	output logic                                  rc1_icache_miss_pending,
	output logic[$clog2(`THREADS_PER_CORE) - 1:0] rc1_icache_miss_entry,
	
	// To/from data cache
	output logic                                  rc_snoop_en,
	output l1d_set_idx_t                          rc_snoop_set,
	input                                         dd_cache_miss,
	input scalar_t                                dd_cache_miss_addr,
	input                                         dd_cache_miss_store,
	input thread_idx_t                            dd_cache_miss_thread_idx,
	input logic[`CACHE_LINE_BITS - 1:0]           dd_ddata_read_data,
                                                  
	// To/from instruction cache                  
	input logic                                   ifd_cache_miss,
	input scalar_t                                ifd_cache_miss_addr,
	input thread_idx_t                            ifd_cache_miss_thread_idx,
	output                                        rc_ilru_read_en,
	output l1i_set_idx_t                          rc_ilru_read_set,

	// From stage 3
	input                                         rc3_dcache_wake,
	input [$clog2(`THREADS_PER_CORE) - 1:0]       rc3_dcache_wake_entry,
	input                                         rc3_icache_wake,
	input [$clog2(`THREADS_PER_CORE) - 1:0]       rc3_icache_wake_entry);

	ring_packet_t packet_out_nxt;
	logic dcache_miss_ready;
	scalar_t dcache_miss_address;
	logic dcache_miss_store;
	logic dcache_miss_ack;
	logic icache_miss_ready;
	scalar_t icache_miss_address;
	logic icache_miss_ack;
	l1d_addr_t dcache_addr;
	l1i_addr_t icache_addr;

	l1_miss_queue dcache_miss_queue(
		// Enqueue new requests
		.cache_miss(dd_cache_miss),
		.cache_miss_addr(dd_cache_miss_addr),
		.cache_miss_thread_idx(dd_cache_miss_thread_idx),
		.cache_miss_store(dd_cache_miss_store),

		// Check existing transactions
		.snoop_en(packet_in.valid),
		.snoop_addr(packet_in.address),
		.snoop_request_pending(rc1_dcache_miss_pending),
		.snoop_pending_entry(rc1_dcache_miss_entry),
		.snoop_state(),

		// Wake threads when a transaction is complete
		.wake_en(rc3_dcache_wake),	
		.wake_entry(rc3_dcache_wake_entry),
		.wake_oh(rc_dcache_wake_oh),

		// Insert new requests into ring
		.request_ready(dcache_miss_ready),
		.request_address(dcache_miss_address),
		.request_store(dcache_miss_store),      
		.request_ack(dcache_miss_ack),
		.*);

	l1_miss_queue icache_miss_queue(
		// Enqueue new requests
		.cache_miss(ifd_cache_miss),
		.cache_miss_addr(ifd_cache_miss_addr),
		.cache_miss_store(1'b0),
		.cache_miss_thread_idx(ifd_cache_miss_thread_idx),

		// Check existing transactions
		.snoop_en(packet_in.valid),
		.snoop_addr(packet_in.address),
		.snoop_request_pending(rc1_icache_miss_pending),
		.snoop_pending_entry(rc1_icache_miss_entry),
		.snoop_state(),	// Not used

		// Wake threads when a transaction is complete
		.wake_en(rc3_icache_wake),
		.wake_entry(rc3_icache_wake_entry),
		.wake_oh(rc_icache_wake_oh),

		// Insert new requests into ring
		.request_ready(icache_miss_ready),
		.request_address(icache_miss_address),
		.request_store(),
		.request_ack(icache_miss_ack),
		.*);

	assign dcache_addr = packet_in.address;
	assign icache_addr = packet_in.address;

	assign rc_snoop_en = packet_in.valid && packet_in.cache_type == CT_DCACHE;
	assign rc_snoop_set = dcache_addr.set_idx;
	
	assign rc_ilru_read_en = packet_in.valid && packet_in.cache_type == CT_ICACHE;
	assign rc_ilru_read_set = icache_addr.set_idx;

	// Request packets are inserted into empty slots at the beginning of the pipeline.
	// Since the ack field will be set to zero, these won't be treated as responses 
	// by the pipeline.  We insert requests here to simplify handling of flush and invalidate
	// requests.
	always_comb
	begin
		dcache_miss_ack = 0;
		icache_miss_ack = 0;
		packet_out_nxt = 0;
		if (packet_in.valid)
			packet_out_nxt = packet_in;	// Pass through packet
		else if (dcache_miss_ready)
		begin
			// Inject data cache request packet into ring (flush, invalidate, write invalidate, or read shared)
			dcache_miss_ack = 1;
			packet_out_nxt.valid = 1;
			packet_out_nxt.packet_type = dcache_miss_store ? PKT_WRITE_INVALIDATE : PKT_READ_SHARED;
			packet_out_nxt.dest_core = CORE_ID;
			packet_out_nxt.address = dcache_miss_address;
			packet_out_nxt.cache_type = CT_DCACHE;
		end
		else if (icache_miss_ready)
		begin
			// Inject instruction request packet into ring
			icache_miss_ack = 1;
			packet_out_nxt.valid = 1;
			packet_out_nxt.packet_type = PKT_READ_SHARED; 
			packet_out_nxt.dest_core = CORE_ID;
			packet_out_nxt.address = icache_miss_address;
			packet_out_nxt.cache_type = CT_ICACHE;
		end
	end

	always_ff @(posedge clk, posedge reset)
	begin
		if (reset)
			rc1_packet <= 0;
		else
			rc1_packet <= packet_out_nxt;
	end
endmodule

// Local Variables:
// verilog-typedef-regexp:"_t$"
// End:


