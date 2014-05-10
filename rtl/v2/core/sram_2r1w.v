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
	parameter ENABLE_BYTE_LANES = 0,
	parameter ADDR_WIDTH = $clog2(SIZE),
	parameter BYTE_LANES = (DATA_WIDTH / 8))
	(input                           clk,
	input                            rd1_en,
	input [ADDR_WIDTH - 1:0]         rd1_addr,
	output logic[DATA_WIDTH - 1:0]   rd1_data,
	input                            rd2_en,
	input [ADDR_WIDTH - 1:0]         rd2_addr,
	output logic[DATA_WIDTH - 1:0]   rd2_data,
	input                            wr_en,
	input [ADDR_WIDTH - 1:0]         wr_addr,
	input [DATA_WIDTH - 1:0]         wr_data,
	input [BYTE_LANES - 1:0]         wr_byte_en);

`ifdef VENDOR_ALTERA
	ALTSYNCRAM #(
		.OPERATION_MODE("DUAL_PORT"),
		.WIDTH_A(DATA_WIDTH),
		.WIDTHAD_A(ADDR_WIDTH),
		.WIDTH_B(DATA_WIDTH),
		.WIDTHAD_B(ADDR_WIDTH),
		.WIDTH_BYTEENA(8),
		.READ_DURING_WRITE_MODE_PORT_B("NEW_DATA")
	) data0(
		.data_a(wr_data),
		.address_a(wr_addr),
		.wren_a(wr_en),
		.rden_a(1'b0),
		.byteena_a(wr_byte_en),
		.q_a(),
		.data_b(0),
		.address_b(rd1_addr),
		.wren_b(1'b0),
		.rden_b(rd1_en),
		.byteena_b(0),
		.q_b(rd1_data),
		.clock0(clk),
		.clock1(clk));

	ALTSYNCRAM #(
		.OPERATION_MODE("DUAL_PORT"),
		.WIDTH_A(DATA_WIDTH),
		.WIDTHAD_A(ADDR_WIDTH),
		.WIDTH_B(DATA_WIDTH),
		.WIDTHAD_B(ADDR_WIDTH),
		.WIDTH_BYTEENA(8),
		.READ_DURING_WRITE_MODE_PORT_B("NEW_DATA")
	) data1(
		.data_a(wr_data),
		.address_a(wr_addr),
		.wren_a(wr_en),
		.rden_a(1'b0),
		.byteena_a(wr_byte_en),
		.q_a(),
		.data_b(0),
		.address_b(rd2_addr),
		.wren_b(1'b0),
		.rden_b(rd2_en),
		.byteena_b(0),
		.q_b(rd2_data),
		.clock0(clk),
		.clock1(clk));
`else
	// Simulation
	logic[DATA_WIDTH - 1:0] data[SIZE];

	generate
		if (ENABLE_BYTE_LANES)
		begin
			always_ff @(posedge clk)
			begin
				if (wr_en)
				begin
					for (int i = 0; i < BYTE_LANES; i++)
						if (wr_byte_en[i])
							data[wr_addr][i * 8+:8] <= wr_data[i * 8+:8];	
				end

				if (wr_addr == rd1_addr && wr_en && rd1_en)
				begin
					// Bypass
					for (int i = 0; i < BYTE_LANES; i++)
						rd1_data[i * 8+:8] <= wr_byte_en[i] ? wr_data[i * 8+:8] : data[wr_addr][i * 8+:8];	
				end
				else if (rd1_en)
					rd1_data <= data[rd1_addr];

				if (wr_addr == rd2_addr && wr_en && rd2_en)
				begin
					// Bypass
					for (int i = 0; i < BYTE_LANES; i++)
						rd2_data[i * 8+:8] <= wr_byte_en[i] ? wr_data[i * 8+:8] : data[wr_addr][i * 8+:8];	
				end
				else if (rd2_en)
					rd2_data <= data[rd2_addr];
			end
		end
		else
		begin
			always_ff @(posedge clk)
			begin
				if (wr_en)
					data[wr_addr] <= wr_data;	

				if (wr_addr == rd1_addr && wr_en && rd1_en)
					rd1_data <= wr_data;	// Bypass
				else if (rd1_en)
					rd1_data <= data[rd1_addr];

				if (wr_addr == rd2_addr && wr_en && rd2_en)
					rd2_data <= wr_data;	// Bypass
				else if (rd2_en)
					rd2_data <= data[rd2_addr];
			end
		end
	endgenerate
`endif
endmodule

// Local Variables:
// verilog-typedef-regexp:"_t$"
// End:

