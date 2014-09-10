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


`include "defines.sv"

//
// Block SRAM with 1 read port and 1 write port. Reads and writes are performed 
// synchronously, with the value for a read appearing on the next clock edge after 
// the address is asserted. 
// The READ_DURING_WRITE parameter determine what happens if a read and a write are 
// performed to the same address in the same cycle:
//  "NEW_DATA" the newly written data will be returned ("read-after-write").
//  "DONT_CARE" The results are undefined. This can be used to improve clock speed.
//
// Memory contents are not cleared on reset.
//

module sram_1r1w
	#(parameter DATA_WIDTH = 32,
	parameter SIZE = 1024,
	parameter READ_DURING_WRITE = "NEW_DATA",	
	parameter ADDR_WIDTH = $clog2(SIZE))

	(input                         clk,
	input                          read_en,
	input [ADDR_WIDTH - 1:0]       read_addr,
	output logic[DATA_WIDTH - 1:0] read_data,
	input                          write_en,
	input [ADDR_WIDTH - 1:0]       write_addr,
	input [DATA_WIDTH - 1:0]       write_data);

`ifdef VENDOR_ALTERA
	logic[DATA_WIDTH - 1:0] data_from_ram;

	ALTSYNCRAM #(
		.OPERATION_MODE("DUAL_PORT"),
		.WIDTH_A(DATA_WIDTH),
		.WIDTHAD_A(ADDR_WIDTH),
		.WIDTH_B(DATA_WIDTH),
		.WIDTHAD_B(ADDR_WIDTH),
		.READ_DURING_WRITE_MIXED_PORTS("DONT_CARE")
	) data0(
		.clock0(clk),
		.clock1(clk),
		
		// Write port
		.wren_a(write_en),
		.address_a(write_addr),
		.data_a(write_data),
		.q_a(),
		
		// Read port
		.rden_b(read_en),
		.address_b(read_addr),
		.q_b(data_from_ram));
	
	generate	
		if (READ_DURING_WRITE == "NEW_DATA")
		begin
			logic pass_thru_en;
			logic[DATA_WIDTH - 1:0] pass_thru_data;

			always_ff @(posedge clk)
			begin
				pass_thru_en <= write_en && read_en && read_addr == write_addr;
				pass_thru_data <= write_data;
			end
			
			assign read_data = pass_thru_en ? pass_thru_data : data_from_ram; 
		end
		else
		begin
			assign read_data = data_from_ram;
		end
	endgenerate
`else
	logic[DATA_WIDTH - 1:0] data[SIZE];

	always_ff @(posedge clk)
	begin
		if (write_en)
			data[write_addr] <= write_data;	

		if (write_addr == read_addr && write_en && read_en)
		begin
			if (READ_DURING_WRITE == "NEW_DATA")
				read_data <= write_data;	// Bypass
			else
				read_data <= {DATA_WIDTH{1'bx}};	// This will be randomized by Verilator
		end
		else if (read_en)
			read_data <= data[read_addr];
	end
`endif
endmodule

// Local Variables:
// verilog-typedef-regexp:"_t$"
// End:
