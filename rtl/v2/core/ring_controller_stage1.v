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
	output pending_miss_state_t                   rc1_dcache_miss_state,
	output logic                                  rc1_dcache_miss_pending,
	output l1_miss_entry_idx_t                    rc1_dcache_miss_entry,
	output logic                                  rc1_icache_miss_pending,
	output l1_miss_entry_idx_t                    rc1_icache_miss_entry,
	output logic                                  rc1_dcache_dequeue_ready,
	output scalar_t                               rc1_dcache_dequeue_addr,
	output pending_miss_state_t                   rc1_dcache_dequeue_state,
	output l1_miss_entry_idx_t                    rc1_dcache_dequeue_entry,
	output logic                                  rc1_icache_dequeue_ready,
	output scalar_t                               rc1_icache_dequeue_addr,
	output l1_miss_entry_idx_t                    rc1_icache_dequeue_entry,
	
	// From stage 2
	input                                         rc2_dcache_update_state_en,
	input pending_miss_state_t                    rc2_dcache_update_state,
	input l1_miss_entry_idx_t                     rc2_dcache_update_entry,
	input                                         rc2_icache_update_state_en,
	input pending_miss_state_t                    rc2_icache_update_state,
	input l1_miss_entry_idx_t                     rc2_icache_update_entry,
	
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
	input                                         rc2_dcache_wake,
	input l1_miss_entry_idx_t                     rc2_dcache_wake_entry,
	input                                         rc2_icache_wake,
	input l1_miss_entry_idx_t                     rc2_icache_wake_entry);

	l1d_addr_t dcache_addr;
	l1i_addr_t icache_addr;

	l1_miss_queue dcache_miss_queue(
		// Enqueue requests
		.enqueue_en(dd_cache_miss),
		.enqueue_addr(dd_cache_miss_addr),
		.enqueue_thread_idx(dd_cache_miss_thread_idx),
		.enqueue_state(dd_cache_miss_store ? PM_WRITE_PENDING : PM_READ_PENDING),

		// Next request
		.dequeue_ready(rc1_dcache_dequeue_ready),
		.dequeue_addr(rc1_dcache_dequeue_addr),
		.dequeue_state(rc1_dcache_dequeue_state),
		.dequeue_entry(rc1_dcache_dequeue_entry),

		// Check existing transactions
		.snoop_en(packet_in.valid),
		.snoop_addr(packet_in.address),
		.snoop_request_pending(rc1_dcache_miss_pending),
		.snoop_pending_entry(rc1_dcache_miss_entry),
		.snoop_state(rc1_dcache_miss_state),
		
		// Update state
		.update_state_en(rc2_dcache_update_state_en),
		.update_state(rc2_dcache_update_state),
		.update_entry(rc2_dcache_update_entry),

		// Wake threads when a transaction is complete
		.wake_en(rc2_dcache_wake),	
		.wake_entry(rc2_dcache_wake_entry),
		.wake_oh(rc_dcache_wake_oh),
		.*);

	l1_miss_queue icache_miss_queue(
		// Enqueue requests
		.enqueue_en(ifd_cache_miss),
		.enqueue_addr(ifd_cache_miss_addr),
		.enqueue_state(PM_READ_PENDING),
		.enqueue_thread_idx(ifd_cache_miss_thread_idx),

		// Next request
		.dequeue_ready(rc1_icache_dequeue_ready),
		.dequeue_addr(rc1_icache_dequeue_addr),
		.dequeue_state(),      
		.dequeue_entry(rc1_icache_dequeue_entry),

		// Check existing transactions
		.snoop_en(packet_in.valid),
		.snoop_addr(packet_in.address),
		.snoop_request_pending(rc1_icache_miss_pending),
		.snoop_pending_entry(rc1_icache_miss_entry),
		.snoop_state(),	// Not used

		// Update state
		.update_state_en(rc2_icache_update_state_en),
		.update_state(rc2_icache_update_state),
		.update_entry(rc2_icache_update_entry),

		// Wake threads when a transaction is complete
		.wake_en(rc2_icache_wake),
		.wake_entry(rc2_icache_wake_entry),
		.wake_oh(rc_icache_wake_oh),
		.*);

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


