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

//
// Block SRAM with 2 read ports and 1 write port. Reads and writes are performed 
// synchronously, with the value for a read appearing on the next clock edge after 
// the address is asserted. If a read and a write are performed to the same address 
// in the same cycle, the newly written data will be returned ("read-after-write").
//

module sram_2r1w
	#(parameter DATA_WIDTH = 32,
	parameter SIZE = 1024,
	parameter ADDR_WIDTH = $clog2(SIZE))
	(input logic                     clk,
	input logic                      rd1_en,
	input logic[ADDR_WIDTH - 1:0]    rd1_addr,
	output logic[DATA_WIDTH - 1:0]   rd1_data,
	input logic                      rd2_en,
	input logic[ADDR_WIDTH - 1:0]    rd2_addr,
	output logic[DATA_WIDTH - 1:0]   rd2_data,
	input logic                      wr_en,
	input logic[ADDR_WIDTH - 1:0]    wr_addr,
	input logic[DATA_WIDTH - 1:0]    wr_data);

	logic[DATA_WIDTH - 1:0] data[SIZE];

	always_ff @(posedge clk)
	begin
		if (wr_en)
			data[wr_addr] <= wr_data;	

		if (wr_addr == rd1_addr && wr_en && rd1_en)
			rd1_data <= wr_data;
		else if (rd1_en)
			rd1_data <= data[rd1_addr];

		if (wr_addr == rd2_addr && wr_en && rd2_en)
			rd2_data <= wr_data;
		else if (rd2_en)
			rd2_data <= data[rd2_addr];
	end
endmodule

// Local Variables:
// verilog-typedef-regexp:"_t$"
// End:

