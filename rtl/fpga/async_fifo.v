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
//

module async_fifo
	#(parameter WIDTH=32,
	parameter NUM_ENTRIES=8)

	// Read
	(input					read_clock,
	input 		 			read_enable,
	output [WIDTH - 1:0]	read_data,
	output 		 			empty,

	// Write 	
	input 					write_clock,
	input 					write_enable,
	output 					full,
	input [WIDTH - 1:0]		write_data);

	localparam ADDR_WIDTH = $clog2(NUM_ENTRIES);

	reg [WIDTH - 1:0] fifo_data[0:NUM_ENTRIES - 1];

	// Read clock domain
	reg [ADDR_WIDTH - 1:0] write_ptr_sync0;
	reg [ADDR_WIDTH - 1:0] write_ptr_sync1;
	wire [ADDR_WIDTH - 1:0] read_ptr_gray = read_ptr ^ (read_ptr >> 1);
	reg [ADDR_WIDTH - 1:0]  read_ptr;

	assign empty = write_ptr_sync1 == read_ptr_gray;

	always @(posedge read_clock)
	begin
		{ write_ptr_sync1, write_ptr_sync0 } <= { write_ptr_sync0, write_ptr_gray };
		if (read_enable && !empty)
			read_ptr <= read_ptr + 1;
	end

	assign read_data = fifo_data[read_ptr];

	// Write clock domain
	reg[ADDR_WIDTH - 1:0] read_ptr_sync0;
	reg[ADDR_WIDTH - 1:0] read_ptr_sync1;
	reg[ADDR_WIDTH - 1:0] write_ptr;
	wire[ADDR_WIDTH - 1:0] write_ptr_gray = write_ptr ^ (write_ptr >> 1);
	wire[ADDR_WIDTH - 1:0] write_ptr_plus_one = write_ptr + 1;
	wire[ADDR_WIDTH - 1:0] write_ptr_plus_one_gray = write_ptr_plus_one ^ (write_ptr_plus_one >> 1);

	assign full = write_ptr_plus_one_gray == read_ptr_sync1;

	always @(posedge write_clock)
	begin
		{ read_ptr_sync1, read_ptr_sync0 } <= { read_ptr_sync0, read_ptr_gray };
		if (write_enable && !full)
		begin
			fifo_data[write_ptr] <= write_data;
			write_ptr <= write_ptr_plus_one;
		end
	end
endmodule
