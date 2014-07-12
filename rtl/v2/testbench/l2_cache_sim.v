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

`include "../core/defines.v"

//
// Simulates the L2 cache, processing ring bus messages
//

module l2_cache_sim
	#(parameter MEM_SIZE = 'h1000)
	(input                   clk, 
	input                    reset,
	output                   request_can_send,
	input l2req_packet_t     l2_request,
	output l2rsp_packet_t    l2_response);

	scalar_t memory[MEM_SIZE];
	logic [`CACHE_LINE_BITS - 1:0] cache_read_data;
	l1d_addr_t cache_addr;

	initial
	begin
		for (int i = 0; i < MEM_SIZE; i++)
			memory[i] = 0;
	end

	assign cache_addr = l2_request.address;

	always_comb
	begin
		// Read data from main memory 
		if (l2_request.valid)
		begin
			for (int i = 0; i < `CACHE_LINE_WORDS; i++)
			begin
				cache_read_data[32 * (`CACHE_LINE_WORDS - 1 - i)+:32] = memory[{cache_addr.tag, 
					cache_addr.set_idx, 4'd0} + i];
			end
		end
	end

	always_ff @(posedge clk)
	begin
		if (reset)
		begin
			l2_response <= 0;
		end
		else
		begin
			if (l2_request.valid)
			begin
				unique case (l2_request.packet_type)
					L2REQ_LOAD:
					begin
						l2_response.packet_type <= L2RSP_LOAD_ACK;
						l2_response.data <= cache_read_data;
					end
				
					L2REQ_STORE:
					begin
						l2_response.packet_type <= L2RSP_STORE_ACK;

						for (int i = 0; i < `CACHE_LINE_BYTES; i++)
						begin
							if (l2_request.store_mask[i])
							begin
								// Update memory
								memory[{cache_addr.tag, cache_addr.set_idx, 4'd0} + i][(i & 3) * 8+:8] <=
									l2_request.data[8 * (`CACHE_LINE_BYTES - 1 - i)+:8];
							end
							else
							begin
								// Update unmasked lanes with memory contents for L1 update
								l2_response.data[32 * (`CACHE_LINE_WORDS - 1 - i)+:32][(i & 3) * 8+:8] <= 
									memory[{cache_addr.tag, cache_addr.set_idx, 4'd0} + i][(i & 3) * 8+:8];
							end
						end
					end
					
					default: l2_response <= 0;	// Eat unknown packets
				endcase
			end
			else
				l2_response <= 0;
		end
	end
endmodule

// Local Variables:
// verilog-library-flags:("-y ../core")
// End:
