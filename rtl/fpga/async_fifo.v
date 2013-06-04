// 
// Copyright 2013 Jeff Bush
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
// Asynchronous FIFO, with two clock domains
// reset is asynchronous and is synchronized to each clock domain
// internally.
// NUM_ENTRIES must be a power of two and >= 2
//

module async_fifo
	#(parameter WIDTH=32,
	parameter NUM_ENTRIES=8)

	(input					reset,		
	
	// Read.
	input					read_clock,
	input 		 			read_enable,
	output [WIDTH - 1:0]	read_data,
	output 		 			empty,

	// Write 	
	input 					write_clock,
	input 					write_enable,
	output 					full,
	input [WIDTH - 1:0]		write_data);

	localparam ADDR_WIDTH = $clog2(NUM_ENTRIES);

	wire[ADDR_WIDTH - 1:0] write_ptr_sync;
	reg[ADDR_WIDTH - 1:0]  read_ptr;
	reg[ADDR_WIDTH - 1:0] read_ptr_gray;
	wire[ADDR_WIDTH - 1:0]  read_ptr_nxt = read_ptr + 1;
	wire[ADDR_WIDTH - 1:0] read_ptr_gray_nxt = read_ptr_nxt ^ (read_ptr_nxt >> 1);
	reg reset_rsync;
	wire[ADDR_WIDTH - 1:0] read_ptr_sync;
	reg[ADDR_WIDTH - 1:0] write_ptr;
	reg[ADDR_WIDTH - 1:0] write_ptr_gray;
	wire[ADDR_WIDTH - 1:0] write_ptr_nxt = write_ptr + 1;
	wire[ADDR_WIDTH - 1:0] write_ptr_gray_nxt = write_ptr_nxt ^ (write_ptr_nxt >> 1);
	reg reset_wsync;
	reg [WIDTH - 1:0] fifo_data[0:NUM_ENTRIES - 1];

	integer i;

	initial
	begin
		for (i = 0; i < NUM_ENTRIES; i = i + 1)
			fifo_data[i] = 0;
	end

	//
	// Read clock domain
	//
	synchronizer #(.WIDTH(ADDR_WIDTH)) write_ptr_synchronizer(
		.clk(read_clock),
		.reset(reset_rsync),
		.data_o(write_ptr_sync),
		.data_i(write_ptr_gray));

	assign empty = write_ptr_sync == read_ptr_gray;

	// We must release the reset after an edge of the appropriate clock to avoid 
	// metastability. 
	always @(posedge read_clock, posedge reset)
	begin
		if (reset)
			reset_rsync <= 1'b1;
		else
			reset_rsync <= 1'b0;
	end
	
	always @(posedge read_clock, posedge reset_rsync)
	begin
		if (reset_rsync)
		begin
			/*AUTORESET*/
			// Beginning of autoreset for uninitialized flops
			read_ptr <= {ADDR_WIDTH{1'b0}};
			read_ptr_gray <= {ADDR_WIDTH{1'b0}};
			// End of automatics
		end
		else if (read_enable && !empty)
		begin
			read_ptr <= read_ptr_nxt;
			read_ptr_gray <= read_ptr_gray_nxt;
		end
	end

	assign read_data = fifo_data[read_ptr];

	//
	// Write clock domain
	//
	synchronizer #(.WIDTH(ADDR_WIDTH)) read_ptr_synchronizer(
		.clk(write_clock),
		.reset(reset_wsync),
		.data_o(read_ptr_sync),
		.data_i(read_ptr_gray));

	assign full = write_ptr_gray_nxt == read_ptr_sync;

	// We must release the reset after an edge of the appropriate clock to avoid 
	// metastability. 
	always @(posedge write_clock, posedge reset)
	begin
		if (reset)
			reset_wsync <= 1'b1;
		else
			reset_wsync <= 1'b0;
	end

	always @(posedge write_clock, posedge reset_wsync)
	begin
		if (reset_wsync)
		begin
			`ifdef SUPPRESSAUTORESET
			fifo_data <= 0;
			`endif
		
			/*AUTORESET*/
			// Beginning of autoreset for uninitialized flops
			write_ptr <= {ADDR_WIDTH{1'b0}};
			write_ptr_gray <= {ADDR_WIDTH{1'b0}};
			// End of automatics
		end
		else if (write_enable && !full)
		begin
			fifo_data[write_ptr] <= write_data;
			write_ptr <= write_ptr_nxt;
			write_ptr_gray <= write_ptr_gray_nxt;
		end
	end
endmodule
