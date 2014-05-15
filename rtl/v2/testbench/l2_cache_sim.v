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

module l2_cache_sim
	#(parameter MEM_SIZE = 'h1000)
	(input                   clk, 
	input                    reset,
	input ring_packet_t      packet_in,
	output ring_packet_t     packet_out);

	scalar_t memory[MEM_SIZE];
	logic [`CACHE_LINE_BITS - 1:0] cache_read_data;
	l1d_addr_t cache_addr;

	initial
	begin
		for (int i = 0; i < MEM_SIZE; i++)
			memory[i] = 0;
	end

	assign cache_addr = packet_in.address;

	always_comb
	begin
		// Read data from main memory and push to L1 cache
		if (packet_in.valid)
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
		if (packet_in.valid)
		begin
			unique case (packet_in.packet_type)
				PKT_READ_SHARED,
				PKT_WRITE_INVALIDATE:
				begin
					packet_out.valid <= 1;
					packet_out.packet_type <= packet_in.packet_type;
					packet_out.ack <= 1;
					packet_out.l2_miss <= 0;
					packet_out.dest_node <= packet_in.dest_node;
					packet_out.address <= packet_in.address;
					packet_out.data <= cache_read_data;
					packet_out.cache_type <= packet_in.cache_type;
				end
				
				PKT_L2_WRITEBACK:
				begin
					packet_out <= 0;
					for (int i = 0; i < `CACHE_LINE_WORDS; i++)
					begin
						memory[{cache_addr.tag, cache_addr.set_idx, 4'd0} + i] =
							packet_in.data[32 * (`CACHE_LINE_WORDS - 1 - i)+:32];
					end
				end
			endcase
		end
		else
			packet_out <= 0;
	end
endmodule

// Local Variables:
// verilog-library-flags:("-y ../core")
// End:
