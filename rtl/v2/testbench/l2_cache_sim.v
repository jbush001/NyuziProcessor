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
	output                   l2_ready,
	input l2req_packet_t     l2i_request,
	output l2rsp_packet_t    l2_response);

	scalar_t memory[MEM_SIZE];
	logic [`CACHE_LINE_BITS - 1:0] cache_read_data;
	scalar_t cache_line_base_word = (l2i_request.address / `CACHE_LINE_BYTES) * `CACHE_LINE_WORDS;

	initial
	begin
		for (int i = 0; i < MEM_SIZE; i++)
			memory[i] = 0;
	end

	assign l2_ready = 1;

	always_comb
	begin
		// Read data from main memory 
		if (l2i_request.valid)
		begin
			for (int i = 0; i < `CACHE_LINE_WORDS; i++)
			begin
				cache_read_data[32 * (`CACHE_LINE_WORDS - 1 - i)+:32] = memory[cache_line_base_word + i];
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
			if (l2i_request.valid)
			begin
				unique case (l2i_request.packet_type)
					L2REQ_LOAD:
					begin
						l2_response.valid <= 1;
						l2_response.status <= 0;
						l2_response.core <= l2i_request.core;
						l2_response.id <= l2i_request.id;
						l2_response.packet_type <= L2RSP_LOAD_ACK;
						l2_response.cache_type <= l2i_request.cache_type;
						l2_response.address <= l2i_request.address;
						l2_response.data <= cache_read_data;
					end
				
					L2REQ_STORE:
					begin
						l2_response.valid <= 1;
						l2_response.status <= 0;
						l2_response.core <= l2i_request.core;
						l2_response.id <= l2i_request.id;
						l2_response.packet_type <= L2RSP_STORE_ACK;
						l2_response.cache_type <= l2i_request.cache_type;
						l2_response.address <= l2i_request.address;
						for (int i = 0; i < `CACHE_LINE_BYTES; i++)
						begin
							int mem_word_offs = `CACHE_LINE_WORDS - 1 - (i / 4);
							
							if (l2i_request.store_mask[i])
							begin
								// Update memory
								memory[cache_line_base_word + mem_word_offs][(i & 3) * 8+:8] <=
									l2i_request.data[8 * i+:8];
							end
							else
							begin
								// Update unmasked lanes with memory contents for L1 update
								l2_response.data[8 * i+:8] <= 
									memory[cache_line_base_word + mem_word_offs][(i & 3) * 8+:8];
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
