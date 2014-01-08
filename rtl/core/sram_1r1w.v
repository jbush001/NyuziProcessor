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

`include "defines.v"

//
// Block SRAM with 1 read port and 1 write port. This is the primary SRAM primitive
// used in most places in the design. Reads and writes are performed synchronously, 
// with the value for a read appearing on the next clock edge after the address is 
// asserted. If a read and a write are performed to the same address in the same 
// cycle, the newly written data will be returned ("read-after-write").
//

module sram_1r1w
	#(parameter DATA_WIDTH = 32,
	parameter SIZE = 1024,
	parameter INIT_FILE = "",
	parameter ADDR_WIDTH = `CLOG2(SIZE))

	(input                         clk,
	input                          rd_enable,
	input [ADDR_WIDTH - 1:0]       rd_addr,
	output reg[DATA_WIDTH - 1:0]   rd_data,
	input                          wr_enable,
	input [ADDR_WIDTH - 1:0]       wr_addr,
	input [DATA_WIDTH - 1:0]       wr_data);

	reg[DATA_WIDTH - 1:0] data[0:SIZE - 1] /*verilator public*/;
	
`ifdef VENDOR_ALTERA
	initial
	begin
		if (INIT_FILE != "")
			$readmemh(INIT_FILE, data);
	end

	// Note that the use of blocking assignments is not usually proper
	// in sequential logic, but this is explicitly recommended by 
	// Altera's "Recommended HDL Coding Styles" document (Example 13-13).
	// to infer a block RAM with the proper read-after-write behavior. 
	always @(posedge clk)
	begin
		if (wr_enable)
			data[wr_addr] = wr_data;	

		if (rd_enable)
			rd_data = data[rd_addr];
	end
`else
	// Simulation
	initial
	begin : clear
		integer	i;

		for (i = 0; i < SIZE; i = i + 1)
			data[i] = 0;

		if (INIT_FILE != "")
			$readmemh(INIT_FILE, data);

		rd_data = 0;
	end

	always @(posedge clk)
	begin
		if (wr_enable)
			data[wr_addr] <= wr_data;	

		if (wr_addr == rd_addr && wr_enable && rd_enable)
			rd_data <= wr_data;
		else if (rd_enable)
			rd_data <= data[rd_addr];
	end
`endif
endmodule

