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

module gpgpu(
	input                        clk,
	input                        reset,
	axi_interface                axi_bus,
	output                       processor_halt);

	l2req_packet_t l2i_request[`NUM_CORES];
	l2rsp_packet_t l2_response;
	logic l2_ready[`NUM_CORES];
	logic[`NUM_CORES - 1:0] core_halt;

	assign processor_halt = |core_halt;

	genvar core_idx;
	generate
		for (core_idx = 0; core_idx < `NUM_CORES; core_idx++)
		begin : core
			core #(.CORE_ID(core_idx)) core(
				.l2i_request(l2i_request[core_idx]),
				.l2_ready(l2_ready[core_idx]),
				.processor_halt(core_halt[core_idx]),
				.*);
		end
	endgenerate
	
	l2_cache l2_cache(.*);
endmodule

// Local Variables:
// verilog-typedef-regexp:"_t$"
// End:
