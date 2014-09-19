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
// Handles non-cacheable memory operations to memory mapped registers
// These always block the thread until the transaction is complete.
//

module io_request_queue
	#(parameter CORE_ID = 0)

	(input                                 clk,
	input                                  reset,
                                           
	// From dcache_data_stage              
	input                                  dd_io_write_en,
	input                                  dd_io_read_en,
	input thread_idx_t                     dd_io_thread_idx,
	input scalar_t                         dd_io_addr,
	input scalar_t                         dd_io_write_value,
	                                       
	// To writeback stage                  
	output scalar_t                        ior_read_value,
	output logic                           ior_rollback_en,
	
	// To thread select stage
	output thread_bitmap_t                 ior_wake_bitmap,
	
	// To io_arbiter
	output ioreq_packet_t                  ior_request,
	
	// From io_arbiter
	input                                  ia_ready,
	input iorsp_packet_t                   ia_response);

	struct packed {
		logic valid;
		logic request_sent;
		logic is_store;
		scalar_t address;
		scalar_t value;
	} pending_request[`THREADS_PER_CORE];
	thread_bitmap_t wake_thread_oh;
	thread_bitmap_t send_request;
	thread_bitmap_t send_grant_oh;
	thread_idx_t send_grant_idx;

	genvar thread_idx;
	generate
		for (thread_idx = 0; thread_idx < `THREADS_PER_CORE; thread_idx++)
		begin : io_request_gen
			assign send_request[thread_idx] = pending_request[thread_idx].valid 
				&& !pending_request[thread_idx].request_sent;
				
			always_ff @(posedge clk, posedge reset)
			begin
				if (reset)
					pending_request[thread_idx] <= 0;
				else 
				begin
					if ((dd_io_write_en | dd_io_read_en) && dd_io_thread_idx == thread_idx)
					begin
						if (pending_request[thread_idx].valid)
						begin
							// Request completed
							pending_request[thread_idx].valid <= 0;
						end
						else
						begin
							// Request initiated
							pending_request[thread_idx].valid <= 1;
							pending_request[thread_idx].is_store <= dd_io_write_en;
							pending_request[thread_idx].address <= dd_io_addr;
							pending_request[thread_idx].value <= dd_io_write_value;
							pending_request[thread_idx].request_sent <= 0;
						end
					end

					if (ia_response.valid && ia_response.core == CORE_ID && ia_response.thread_idx == thread_idx)
					begin
						// Ensure there isn't a response for an entry that isn't pending
						assert(pending_request[thread_idx].valid);

						pending_request[thread_idx].value <= ia_response.read_value;
					end

					if (ia_ready && |send_grant_oh && send_grant_idx == thread_idx)
						pending_request[thread_idx].request_sent <= 1;				
				end
			end
		end
	endgenerate

	arbiter #(.NUM_ENTRIES(`THREADS_PER_CORE)) arbiter_send(
		.request(send_request),
		.update_lru(1'b1),
		.grant_oh(send_grant_oh),
		.*);
		
	oh_to_idx #(.NUM_SIGNALS(`THREADS_PER_CORE)) oh_to_idx_send_thread(
		.one_hot(send_grant_oh),
		.index(send_grant_idx));

	idx_to_oh #(.NUM_SIGNALS(`THREADS_PER_CORE)) idx_to_oh_wake_thread(
		.index(ia_response.thread_idx),
		.one_hot(wake_thread_oh));

	assign ior_wake_bitmap = (ia_response.valid && ia_response.core == CORE_ID)
		? wake_thread_oh : 0;

	// Send request
	assign ior_request.valid = |send_grant_oh;
	assign ior_request.is_store = pending_request[send_grant_idx].is_store;
	assign ior_request.address = pending_request[send_grant_idx].address;
	assign ior_request.value = pending_request[send_grant_idx].value;
	assign ior_request.thread_idx = send_grant_idx;
	
	always_ff @(posedge clk, posedge reset)
	begin
		if (reset)
		begin
			ior_rollback_en <= 0;
			ior_read_value <= 0;
		end
		else
		begin
			if ((dd_io_write_en | dd_io_read_en) && !pending_request[dd_io_thread_idx].valid)
				ior_rollback_en <= 1;	// Start request
			else
				ior_rollback_en <= 0;	// Complete request

			ior_read_value <= pending_request[dd_io_thread_idx].value;
		end
	end
endmodule

// Local Variables:
// verilog-typedef-regexp:"_t$"
// End:
