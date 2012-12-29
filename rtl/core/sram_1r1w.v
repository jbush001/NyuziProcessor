// 
// Copyright 2011-2012 Jeff Bush
// 
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
// 
//     http://www.apache.org/licenses/LICENSE-2.0
// 
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
// 

//
// Block SRAM with 1 read port and 1 write port
// Reads and writes are performed synchronously, with the value for a read
// appearing on the next clock cycle after the address is asserted.
// If a read and a write are performed in the same cycle, the newly written
// data will be returned.
// The reset signal will reinitialize the internal state of this block, but will
// not clear memory.
//

module sram_1r1w
	#(parameter DATA_WIDTH = 32,
	parameter SIZE = 1024,
	parameter ADDR_WIDTH = 10)

	(input						clk,
	input						reset,
	input						rd_enable,
	input [ADDR_WIDTH - 1:0]	rd_addr,
	output reg[DATA_WIDTH - 1:0] rd_data = 0,
	input						wr_enable,
	input [ADDR_WIDTH - 1:0]	wr_addr,
	input [DATA_WIDTH - 1:0]	wr_data);

	
`ifdef VENDOR_ALTERA
	wire[DATA_WIDTH - 1:0] data_from_mem;
	reg read_during_write = 0;
	reg[DATA_WIDTH - 1:0] wr_data_latched = 0;

	ALTSYNCRAM ram(
		.clock0(clk),
		.clock1(clk),
		
		// read port
		.address_a(rd_addr),
		.wren_a(1'b0),
		.rden_a(rd_enable),
		.q_a(data_from_mem),

		// write port
		.address_b(wr_addr),
		.wren_b(wr_enable),
		.data_b(wr_data));
	defparam
		ram.WIDTH_A = DATA_WIDTH,
		ram.WIDTHAD_A = ADDR_WIDTH,
		ram.WIDTH_B = DATA_WIDTH,
		ram.WIDTHAD_B = ADDR_WIDTH,
		ram.READ_DURING_WRITE_MODE_MIXED_PORTS = "DONT_CARE";

	always @(posedge clk, posedge reset)
	begin
		if (reset)
		begin
			read_during_write <= 0;
			wr_data_latched <= 0;
		end
		else
		begin
			read_during_write <= rd_addr == wr_addr && wr_enable;
			wr_data_latched <= wr_data;
		end
	end

	always @*
		rd_data = read_during_write ? wr_data_latched : data_from_mem;
`else
	// Simulation
	reg[DATA_WIDTH - 1:0] data[0:SIZE - 1];
	integer	i;

	initial
	begin
		for (i = 0; i < SIZE; i = i + 1)
			data[i] = 0;
	end

	always @(posedge clk, posedge reset)
	begin
		if (reset)
		begin
			rd_data <= 0;
		end
		else
		begin
			if (wr_enable)
				data[wr_addr] <= wr_data;	
	
			if (wr_addr == rd_addr && wr_enable)
				rd_data <= wr_data;
			else if (rd_enable)
				rd_data <= data[rd_addr];
		end
	end
`endif
endmodule

