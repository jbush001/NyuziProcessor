// 
// Copyright (C) 2011-2014 Jeff Bush
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
// Block SRAM with 1 read port and 1 write port. Reads and writes are performed 
// synchronously, with the value for a read appearing on the next clock edge after 
// the address is asserted. If a read and a write are performed to the same address 
// in the same cycle, the newly written data will be returned ("read-after-write").
// Memory contents are not cleared on reset.
//

module sram_1r1w
	#(parameter DATA_WIDTH = 32,
	parameter SIZE = 1024,
	parameter ADDR_WIDTH = $clog2(SIZE))

	(input                         clk,
	input                          read_en,
	input [ADDR_WIDTH - 1:0]       read_addr,
	output logic[DATA_WIDTH - 1:0] read_data,
	input                          write_en,
	input [ADDR_WIDTH - 1:0]       write_addr,
	input [DATA_WIDTH - 1:0]       write_data);

`ifdef VENDOR_ALTERA
	ALTSYNCRAM #(
		.OPERATION_MODE("DUAL_PORT"),
		.WIDTH_A(DATA_WIDTH),
		.WIDTHAD_A(ADDR_WIDTH),
		.WIDTH_B(DATA_WIDTH),
		.WIDTHAD_B(ADDR_WIDTH),
		.READ_DURING_WRITE_MODE_PORT_B("NEW_DATA_WITH_NBE_READ")
	) data0(
		.data_a(write_data),
		.address_a(write_addr),
		.wren_a(write_en),
		.rden_a(1'b0),
		.q_a(),
		.data_b(0),
		.address_b(read_addr),
		.wren_b(1'b0),
		.rden_b(read_en),
		.byteena_b(0),
		.q_b(read_data),
		.clock0(clk),
		.clock1(clk));
`else
	logic[DATA_WIDTH - 1:0] data[SIZE];

	always_ff @(posedge clk)
	begin
		if (write_en)
			data[write_addr] <= write_data;	

		if (write_addr == read_addr && write_en && read_en)
			read_data <= write_data;
		else if (read_en)
			read_data <= data[read_addr];
	end
`endif
endmodule

// Local Variables:
// verilog-typedef-regexp:"_t$"
// End:
