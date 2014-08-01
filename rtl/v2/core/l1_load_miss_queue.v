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
// Track pending L1 misses.  Detect and consolidate multiple faults for the same address.
// Wake threads when loads are satisfied.
//

module l1_load_miss_queue(
	input                                   clk,
	input                                   reset,

	// Enqueue request
	input                                   cache_miss,
	input scalar_t                          cache_miss_addr,
	input thread_idx_t                      cache_miss_thread_idx,
	input                                   cache_miss_synchronized,

	// Dequeue request
	output logic                            dequeue_ready,
	input                                   dequeue_ack,
	output scalar_t                         dequeue_addr,
	output l1_miss_entry_idx_t              dequeue_idx,
	output logic                            dequeue_synchronized,

	// Wake
	input                                   l2_response_valid,
	input l1_miss_entry_idx_t               l2_response_idx,
	output logic [`THREADS_PER_CORE - 1:0]  wake_bitmap);

	struct packed {
		logic valid;
		logic request_sent;
		logic[`THREADS_PER_CORE - 1:0] waiting_threads;
		scalar_t address;
		logic synchronized;
	} pending_entries[`THREADS_PER_CORE];
	
	logic[`THREADS_PER_CORE - 1:0] collided_miss_oh;
	logic[`THREADS_PER_CORE - 1:0] miss_thread_oh;
	logic request_unique;
	logic[`THREADS_PER_CORE - 1:0] send_grant_oh;
	logic[`THREADS_PER_CORE - 1:0] arbiter_request;
	thread_idx_t send_grant_idx;
	
	idx_to_oh #(.NUM_SIGNALS(`THREADS_PER_CORE)) idx_to_oh_miss_thread(
		.index(cache_miss_thread_idx),
		.one_hot(miss_thread_oh));
		
	arbiter #(.NUM_ENTRIES(`THREADS_PER_CORE)) arbiter_send(
		.request(arbiter_request),
		.update_lru(1'b1),
		.grant_oh(send_grant_oh),
		.*);

	oh_to_idx #(.NUM_SIGNALS(`THREADS_PER_CORE)) oh_to_idx_send_grant(
		.index(send_grant_idx),
		.one_hot(send_grant_oh));

	// Request out
	// XXX may want to register this to reduce latency.
	assign dequeue_ready = |arbiter_request;
	assign dequeue_addr = pending_entries[send_grant_idx].address;
	assign dequeue_idx = send_grant_idx;
	assign dequeue_synchronized = pending_entries[send_grant_idx].synchronized;
	
	assign request_unique = !(|collided_miss_oh);
	
	assign wake_bitmap = l2_response_valid ? pending_entries[l2_response_idx].waiting_threads : 0;

	genvar wait_entry;
	generate
		for (wait_entry = 0; wait_entry < `THREADS_PER_CORE; wait_entry++)
		begin : wait_logic_gen
			// Note that synchronized requests cannot be combined with
			// other requests.
			assign collided_miss_oh[wait_entry] = pending_entries[wait_entry].valid 
				&& pending_entries[wait_entry].address == cache_miss_addr
				&& !pending_entries[wait_entry].synchronized
				&& !cache_miss_synchronized;
			assign arbiter_request[wait_entry] = pending_entries[wait_entry].valid
				&& !pending_entries[wait_entry].request_sent;

			always_ff @(posedge clk, posedge reset)
			begin
				if (reset)
					pending_entries[wait_entry] <= 0;
				else
				begin
					if (dequeue_ack && send_grant_oh[wait_entry])
					begin
						assert(pending_entries[wait_entry].valid);
						assert(!pending_entries[wait_entry].request_sent);

						pending_entries[wait_entry].request_sent <= 1;
					end
					else if (cache_miss && miss_thread_oh[wait_entry] && request_unique)
					begin
						// Record a new miss
						assert(!pending_entries[wait_entry].valid);
						assert(!(l2_response_valid && l2_response_idx == wait_entry));
					
						pending_entries[wait_entry].waiting_threads <= miss_thread_oh;
						pending_entries[wait_entry].valid <= 1;
						pending_entries[wait_entry].address <= cache_miss_addr;
						pending_entries[wait_entry].request_sent <= 0;
						pending_entries[wait_entry].synchronized <= cache_miss_synchronized;
					end
					else if (l2_response_valid && l2_response_idx == wait_entry)
					begin
						assert(pending_entries[wait_entry].valid);
						pending_entries[wait_entry].valid <= 0;
					end

					if (cache_miss && collided_miss_oh[wait_entry])
					begin
						// Miss is already pending, add waiting thread
						pending_entries[wait_entry].waiting_threads <= pending_entries[wait_entry].waiting_threads
							| miss_thread_oh;
	
						// Upper level 'almost_miss' logic prevents triggering a miss in the same
						// cycle it is satisfied.
						assert(!(l2_response_valid && l2_response_idx == wait_entry));
					end
				end
			end
		end
	endgenerate
endmodule

// Local Variables:
// verilog-typedef-regexp:"_t$"
// End:


