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
// Memory contents are not cleared on reset.
//

module sram_2r1w
	#(parameter DATA_WIDTH = 32,
	parameter SIZE = 1024,
	parameter ENABLE_BYTE_LANES = 0,
	parameter ADDR_WIDTH = $clog2(SIZE),
	parameter BYTE_LANES = (DATA_WIDTH / 8))
	(input                           clk,
	input                            read1_en,
	input [ADDR_WIDTH - 1:0]         read1_addr,
	output logic[DATA_WIDTH - 1:0]   read1_data,
	input                            read2_en,
	input [ADDR_WIDTH - 1:0]         read2_addr,
	output logic[DATA_WIDTH - 1:0]   read2_data,
	input                            write_en,
	input [ADDR_WIDTH - 1:0]         write_addr,
	input [DATA_WIDTH - 1:0]         write_data,
	input [BYTE_LANES - 1:0]         write_byte_en);

`ifdef VENDOR_ALTERA
	ALTSYNCRAM #(
		.OPERATION_MODE("DUAL_PORT"),
		.WIDTH_A(DATA_WIDTH),
		.WIDTHAD_A(ADDR_WIDTH),
		.WIDTH_B(DATA_WIDTH),
		.WIDTHAD_B(ADDR_WIDTH),
		.WIDTH_BYTEENA(8),
		.READ_DURING_WRITE_MODE_PORT_B("NEW_DATA_WITH_NBE_READ")
	) data0(
		.data_a(write_data),
		.address_a(write_addr),
		.wren_a(write_en),
		.rden_a(1'b0),
		.byteena_a(write_byte_en),
		.q_a(),
		.data_b(0),
		.address_b(read1_addr),
		.wren_b(1'b0),
		.rden_b(read1_en),
		.byteena_b(0),
		.q_b(read1_data),
		.clock0(clk),
		.clock1(clk));

	ALTSYNCRAM #(
		.OPERATION_MODE("DUAL_PORT"),
		.WIDTH_A(DATA_WIDTH),
		.WIDTHAD_A(ADDR_WIDTH),
		.WIDTH_B(DATA_WIDTH),
		.WIDTHAD_B(ADDR_WIDTH),
		.WIDTH_BYTEENA(8),
		.READ_DURING_WRITE_MODE_PORT_B("NEW_DATA_WITH_NBE_READ")
	) data1(
		.data_a(write_data),
		.address_a(write_addr),
		.wren_a(write_en),
		.rden_a(1'b0),
		.byteena_a(write_byte_en),
		.q_a(),
		.data_b(0),
		.address_b(read2_addr),
		.wren_b(1'b0),
		.rden_b(read2_en),
		.byteena_b(0),
		.q_b(read2_data),
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
				if (write_en)
				begin
					for (int i = 0; i < BYTE_LANES; i++)
						if (write_byte_en[i])
							data[write_addr][i * 8+:8] <= write_data[i * 8+:8];	
				end

				if (write_addr == read1_addr && write_en && read1_en)
				begin
					// Bypass
					for (int i = 0; i < BYTE_LANES; i++)
						read1_data[i * 8+:8] <= write_byte_en[i] ? write_data[i * 8+:8] : data[write_addr][i * 8+:8];	
				end
				else if (read1_en)
					read1_data <= data[read1_addr];

				if (write_addr == read2_addr && write_en && read2_en)
				begin
					// Bypass
					for (int i = 0; i < BYTE_LANES; i++)
						read2_data[i * 8+:8] <= write_byte_en[i] ? write_data[i * 8+:8] : data[write_addr][i * 8+:8];	
				end
				else if (read2_en)
					read2_data <= data[read2_addr];
			end
		end
		else
		begin
			always_ff @(posedge clk)
			begin
				if (write_en)
					data[write_addr] <= write_data;	

				if (write_addr == read1_addr && write_en && read1_en)
					read1_data <= write_data;	// Bypass
				else if (read1_en)
					read1_data <= data[read1_addr];

				if (write_addr == read2_addr && write_en && read2_en)
					read2_data <= write_data;	// Bypass
				else if (read2_en)
					read2_data <= data[read2_addr];
			end
		end
	endgenerate
`endif
endmodule

// Local Variables:
// verilog-typedef-regexp:"_t$"
// End:

