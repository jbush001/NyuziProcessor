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
//

module sram_1r1w
	#(parameter WIDTH = 32,
	parameter SIZE = 1024,
	parameter ADDR_WIDTH = 10,
	parameter READ_BEFORE_WRITE = 0)	// If true, return old data when there is a
										// simultaneous read and write to the same
										// location.  Otherwise the newly written
										// data is returned (write-before-read).
	(input						clk,
	input [ADDR_WIDTH - 1:0]	rd_addr,
	output reg[WIDTH - 1:0]		rd_data = 0,
	input [ADDR_WIDTH - 1:0]	wr_addr,
	input [WIDTH - 1:0]			wr_data,
	input						wr_enable);

	reg[WIDTH - 1:0]			data[0:SIZE - 1];
	reg[WIDTH - 1:0]			data_from_mem = 0;
	reg							read_during_write = 0;
	reg[WIDTH - 1:0]			wr_data_latched = 0;
	integer						i;

	initial
	begin
		for (i = 0; i < SIZE; i = i + 1)
			data[i] = 0;
	end

	always @(posedge clk)
	begin
		if (wr_enable)
			data[wr_addr] <= #1 wr_data;	
			
		data_from_mem <= #1 data[rd_addr];
		read_during_write <= #1 wr_addr == rd_addr && wr_enable;
		wr_data_latched <= #1 wr_data;
	end

	always @*
	begin
		if (!READ_BEFORE_WRITE && read_during_write)
			rd_data = wr_data_latched;	// Bypass data
		else
			rd_data = data_from_mem;
	end
endmodule
