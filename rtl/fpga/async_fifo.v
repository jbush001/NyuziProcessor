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
// NUM_ENTRIES must be at least 2.
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

	reg [WIDTH - 1:0] fifo_data[0:NUM_ENTRIES - 1];

	integer i;

	initial
	begin
		for (i = 0; i < NUM_ENTRIES; i = i + 1)
			fifo_data[i] = 0;
	end

	// Read clock domain
	reg[ADDR_WIDTH - 1:0] write_ptr_sync0;
	reg[ADDR_WIDTH - 1:0] write_ptr_sync1;
	reg[ADDR_WIDTH - 1:0]  read_ptr;
	reg[ADDR_WIDTH - 1:0] read_ptr_gray;
	wire[ADDR_WIDTH - 1:0]  read_ptr_nxt = read_ptr + 1;
	wire[ADDR_WIDTH - 1:0] read_ptr_gray_nxt = read_ptr_nxt ^ (read_ptr_nxt >> 1);

	assign empty = write_ptr_sync1 == read_ptr_gray;

	// We must release the reset after an edge of the appropriate clock to avoid 
	// metastability. 
	reg reset_rsync;
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
			write_ptr_sync0 <= {ADDR_WIDTH{1'b0}};
			write_ptr_sync1 <= {ADDR_WIDTH{1'b0}};
			// End of automatics
		end
		else
		begin
			{ write_ptr_sync1, write_ptr_sync0 } <= { write_ptr_sync0, write_ptr_gray };
			if (read_enable && !empty)
			begin
				read_ptr <= read_ptr_nxt;
				read_ptr_gray <= read_ptr_gray_nxt;
			end
		end
	end

	assign read_data = fifo_data[read_ptr];

	// Write clock domain
	reg[ADDR_WIDTH - 1:0] read_ptr_sync0;
	reg[ADDR_WIDTH - 1:0] read_ptr_sync1;
	reg[ADDR_WIDTH - 1:0] write_ptr;
	reg[ADDR_WIDTH - 1:0] write_ptr_gray;
	reg[ADDR_WIDTH - 1:0] write_ptr_plus_one_gray;
	wire[ADDR_WIDTH - 1:0] write_ptr_nxt = write_ptr + 1;
	wire[ADDR_WIDTH - 1:0] write_ptr_gray_nxt = write_ptr_nxt ^ (write_ptr_nxt >> 1);
	wire[ADDR_WIDTH - 1:0] write_ptr_plus_one_nxt = write_ptr + 2;
	wire[ADDR_WIDTH - 1:0] write_ptr_plus_one_gray_nxt = write_ptr_plus_one_nxt ^ (write_ptr_plus_one_nxt >> 1);

	assign full = write_ptr_plus_one_gray == read_ptr_sync1;

	// We must release the reset after an edge of the appropriate clock to avoid 
	// metastability. 
	reg reset_wsync;
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

			write_ptr_plus_one_gray <= 1;
		
			/*AUTORESET*/
			// Beginning of autoreset for uninitialized flops
			read_ptr_sync0 <= {ADDR_WIDTH{1'b0}};
			read_ptr_sync1 <= {ADDR_WIDTH{1'b0}};
			write_ptr <= {ADDR_WIDTH{1'b0}};
			write_ptr_gray <= {ADDR_WIDTH{1'b0}};
			// End of automatics
		end
		else
		begin
			{ read_ptr_sync1, read_ptr_sync0 } <= { read_ptr_sync0, read_ptr_gray };
			if (write_enable && !full)
			begin
				fifo_data[write_ptr] <= write_data;
				write_ptr <= write_ptr_nxt;
				write_ptr_gray <= write_ptr_gray_nxt;
				write_ptr_plus_one_gray <= write_ptr_plus_one_gray_nxt;
			end
		end
	end
endmodule
