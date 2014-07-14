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

module l1_store_buffer(
	input                                  clk,
	input                                  reset,
                                           
	// From dache data stage               
	input                                  dd_store_en,
	input scalar_t                         dd_store_addr,
	input [`CACHE_LINE_BYTES - 1:0]        dd_store_mask,
	input [`CACHE_LINE_BITS - 1:0]         dd_store_data,
	input                                  dd_store_synchronized,
	input thread_idx_t                     dd_store_thread_idx,
                                           
	// To/From L2 interface           
	output logic                           sb_dequeue_ready,
	input                                  sb_dequeue_ack,
	output scalar_t                        sb_dequeue_addr,
	output l1_miss_entry_idx_t             sb_dequeue_idx,
	output [`CACHE_LINE_BYTES - 1:0]       sb_dequeue_mask,
	output [`CACHE_LINE_BITS - 1:0]        sb_dequeue_data,
	input scalar_t                         dd_store_bypass_addr,
	input thread_idx_t                     dd_store_bypass_thread_idx,
	output                                 sb_store_bypass_mask,
	output [`CACHE_LINE_BITS - 1:0]        sb_store_bypass_data,
	output                                 sb_full_rollback,
	input                                  storebuf_wake_en,
	input l1_miss_entry_idx_t              storebuf_wake_idx,
	output logic[`THREADS_PER_CORE - 1:0]  sb_wake_oh);

	typedef struct packed {
		logic valid;
		scalar_t pad;	// XXX HACK: verilator clobbers data when this isn't here.
		logic[`CACHE_LINE_BITS - 1:0] data;
		logic[`CACHE_LINE_BYTES - 1:0] mask;
		scalar_t address;
		logic synchronized;
		logic request_sent;
		logic thread_waiting;
	} store_buffer_entry_t;

	store_buffer_entry_t pending_stores[`THREADS_PER_CORE];
	logic[`THREADS_PER_CORE - 1:0] rollback;
	logic[`THREADS_PER_CORE - 1:0] arbiter_request;
	thread_idx_t send_grant_idx;
	logic[`THREADS_PER_CORE - 1:0] send_grant_oh;
	logic[`THREADS_PER_CORE - 1:0] wake_oh;

	arbiter #(.NUM_ENTRIES(`THREADS_PER_CORE)) send_arbiter(
		.request(arbiter_request),
		.update_lru(1'b1),
		.grant_oh(send_grant_oh),
		.*);

	one_hot_to_index #(.NUM_SIGNALS(`THREADS_PER_CORE)) convert_send_idx(
		.index(send_grant_idx),
		.one_hot(send_grant_oh));

	index_to_one_hot #(.NUM_SIGNALS(`THREADS_PER_CORE)) convert_wake_idx(
		.index(storebuf_wake_idx),
		.one_hot(wake_oh));

	assign sb_wake_oh = (storebuf_wake_en && pending_stores[storebuf_wake_idx].thread_waiting)
		? wake_oh
		: 0;

	genvar thread_idx;
	generate
		for (thread_idx = 0; thread_idx < `THREADS_PER_CORE; thread_idx++)
		begin : store_buffer_thread
			logic update_store_data;
			logic can_write_combine;
			logic store_buffer_full;
			logic store_this_entry;

			assign arbiter_request[thread_idx] = pending_stores[thread_idx].valid
				&& !pending_stores[thread_idx].request_sent;
			assign store_this_entry = dd_store_en && dd_store_thread_idx == thread_idx;
			assign can_write_combine = pending_stores[thread_idx].valid 
				&& pending_stores[thread_idx].address == dd_store_addr
				&& !pending_stores[thread_idx].synchronized 
				&& !dd_store_synchronized
				&& !pending_stores[thread_idx].request_sent
				&& send_grant_oh[thread_idx];
			assign store_buffer_full = pending_stores[thread_idx].valid;
			assign update_store_data = store_this_entry && !store_buffer_full;
			assign rollback[thread_idx] = store_this_entry 
				&& (store_buffer_full
				|| (pending_stores[thread_idx].synchronized && pending_stores[thread_idx].valid)
				|| (dd_store_synchronized && pending_stores[thread_idx].valid));

			always_ff @(posedge clk, posedge reset)
			begin
				if (reset)
				begin
					pending_stores[thread_idx] <= 0;
				end
				else 
				begin
					if (send_grant_oh[thread_idx] && sb_dequeue_ack)
						pending_stores[thread_idx].request_sent <= 1;

					if (update_store_data)
					begin
						for (int byte_lane = 0; byte_lane < `CACHE_LINE_BYTES; byte_lane++)
						begin
							if (dd_store_mask[byte_lane])
								pending_stores[thread_idx].data[byte_lane * 8+:8] <= dd_store_data[byte_lane * 8+:8];
						end
							
						if (can_write_combine)
							pending_stores[thread_idx].mask <= pending_stores[thread_idx].mask | dd_store_mask;
						else
							pending_stores[thread_idx].mask <= dd_store_mask;
					end

					if (rollback[thread_idx])
						pending_stores[thread_idx].thread_waiting <= 1;
					else if (store_this_entry && !can_write_combine)
					begin
						// New store
						pending_stores[thread_idx].valid <= 1;
						pending_stores[thread_idx].address <= { dd_store_addr[31:`CACHE_LINE_OFFSET_WIDTH], 
							{`CACHE_LINE_OFFSET_WIDTH{1'b0}} };
						pending_stores[thread_idx].synchronized <= dd_store_synchronized;
						pending_stores[thread_idx].request_sent <= 0;
						pending_stores[thread_idx].thread_waiting <= 0;
					end
					else if (storebuf_wake_en && storebuf_wake_idx == thread_idx)
						pending_stores[thread_idx].valid <= 0;
				end
			end
		end
	endgenerate
	
	assign sb_dequeue_ready = |send_grant_oh;
	assign sb_dequeue_idx = send_grant_idx;
	assign sb_dequeue_addr = pending_stores[send_grant_idx].address;
	assign sb_dequeue_mask = pending_stores[send_grant_idx].mask;
	assign sb_dequeue_data = pending_stores[send_grant_idx].data;
	
	always_ff @(posedge clk, posedge reset)
	begin
		if (reset)
		begin
			sb_store_bypass_mask <= 0;
			sb_store_bypass_data <= 0;
		end
		else
		begin
			// Must wake a valid storebuffer entry
			assert(!storebuf_wake_en || pending_stores[storebuf_wake_idx].valid);
		
			if (dd_store_bypass_addr == pending_stores[dd_store_bypass_thread_idx].address
				&& pending_stores[dd_store_bypass_thread_idx].valid)
			begin
				sb_store_bypass_mask <= pending_stores[dd_store_bypass_thread_idx].mask;
				sb_store_bypass_data <= pending_stores[dd_store_bypass_thread_idx].data;
			end
			else
				sb_store_bypass_mask <= 0;
		
			sb_full_rollback <= |rollback;
		end
	end
endmodule
