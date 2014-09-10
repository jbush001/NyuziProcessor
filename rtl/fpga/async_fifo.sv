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
	wire reset_rsync;
	wire[ADDR_WIDTH - 1:0] read_ptr_sync;
	reg[ADDR_WIDTH - 1:0] write_ptr;
	reg[ADDR_WIDTH - 1:0] write_ptr_gray;
	wire[ADDR_WIDTH - 1:0] write_ptr_nxt = write_ptr + 1;
	wire[ADDR_WIDTH - 1:0] write_ptr_gray_nxt = write_ptr_nxt ^ (write_ptr_nxt >> 1);
	wire reset_wsync;
	reg [WIDTH - 1:0] fifo_data[0:NUM_ENTRIES - 1];

	initial
	begin
		for (int i = 0; i < NUM_ENTRIES; i = i + 1)
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

	synchronizer #(.RESET_STATE(1)) read_reset_synchronizer(
		.clk(read_clock),
		.reset(reset),
		.data_i(0),
		.data_o(reset_rsync));

	always_ff @(posedge read_clock, posedge reset_rsync)
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

	synchronizer #(.RESET_STATE(1)) write_reset_synchronizer(
		.clk(write_clock),
		.reset(reset),
		.data_i(0),
		.data_o(reset_wsync));

	always_ff @(posedge write_clock, posedge reset_wsync)
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

// Local Variables:
// verilog-typedef-regexp:"_t$"
// End:
