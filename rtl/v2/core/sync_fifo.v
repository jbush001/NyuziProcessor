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

`include "defines.v"

//
// FIFO, with synchronous read/write
// almost_full asserts when there are ALMOST_FULL_THRESHOLD or fewer empty
// entries available.  almost_empty asserts when there are 
// ALMOST_EMPTY_THRESHOLD or fewer entries queued.  Note that almost_full
// will be asserted when full is asserted, as will almost_empty when
// empty is asserted.
//

module sync_fifo
	#(parameter DATA_WIDTH = 64,
	parameter NUM_ENTRIES = 2,
	parameter ALMOST_FULL_THRESHOLD = 1,
	parameter ALMOST_EMPTY_THRESHOLD = 1)

	(input                       clk,
	input                        reset,
	input                        flush_en,	// flush is synchronous, unlike reset
	output logic                 full,
	output logic                 almost_full,	
	input                        enqueue_en,
	input [DATA_WIDTH - 1:0]     value_i,
	output logic                 empty,
	output logic                 almost_empty,
	input                        dequeue_en,
	output [DATA_WIDTH - 1:0]    value_o);

	localparam ADDR_WIDTH = $clog2(NUM_ENTRIES);

	logic[ADDR_WIDTH - 1:0] head_ff;
	logic[ADDR_WIDTH - 1:0] head_nxt;
	logic[ADDR_WIDTH - 1:0] tail_ff;
	logic[ADDR_WIDTH - 1:0] tail_nxt;
	logic[ADDR_WIDTH:0] count_ff;
	logic[ADDR_WIDTH:0] count_nxt;
	logic almost_full_nxt;
	logic almost_empty_nxt;
	logic[DATA_WIDTH - 1:0] fifo_data[NUM_ENTRIES];

	always_comb
	begin
		if (flush_en)
		begin
			count_nxt = 0;
			head_nxt = 0;
			tail_nxt = 0;
			almost_full_nxt = 0;
			almost_empty_nxt = 1'b1;
		end
		else
		begin
			almost_full_nxt = almost_full;
			almost_empty_nxt = almost_empty;
			tail_nxt = tail_ff;
			head_nxt = head_ff;
			count_nxt = count_ff;
			
			if (enqueue_en)
			begin
				if (tail_ff == NUM_ENTRIES - 1)
					tail_nxt = 0;
				else
					tail_nxt = tail_ff + 1;
			end
				
			if (dequeue_en)
			begin
				if (head_ff == NUM_ENTRIES - 1)
					head_nxt = 0;
				else
					head_nxt = head_ff + 1;
			end

			if (enqueue_en && !dequeue_en)	
			begin
				count_nxt = count_ff + 1;
				if (count_ff == (NUM_ENTRIES - ALMOST_FULL_THRESHOLD - 1))
					almost_full_nxt = 1;

				if (count_ff == ALMOST_EMPTY_THRESHOLD)
					almost_empty_nxt = 0;
			end
			else if (dequeue_en && !enqueue_en)
			begin
				count_nxt = count_ff - 1;
				if (count_ff == NUM_ENTRIES - ALMOST_FULL_THRESHOLD)
					almost_full_nxt = 0;

				if (count_ff == ALMOST_EMPTY_THRESHOLD + 1)
					almost_empty_nxt = 1;
			end
		end	
	end
	
	always_ff @(posedge clk, posedge reset)
	begin
		if (reset)
		begin
			empty <= 1'b1;
			almost_empty <= 1'b1;
			
			`ifdef SUPPRESS_AUTORESET
			fifo_data <= 0;
			`endif

			/*AUTORESET*/
			// Beginning of autoreset for uninitialized flops
			almost_full <= 1'h0;
			count_ff <= {(1+(ADDR_WIDTH)){1'b0}};
			full <= 1'h0;
			head_ff <= {ADDR_WIDTH{1'b0}};
			tail_ff <= {ADDR_WIDTH{1'b0}};
			value_o <= {DATA_WIDTH{1'b0}};
			// End of automatics
		end
		else
		begin
			assert(count_ff != NUM_ENTRIES || !enqueue_en); // enqueue into full FIFO 
			assert(count_ff != 0 || !dequeue_en); // dequeue from empty FIFO 

			head_ff <= head_nxt;
			tail_ff <= tail_nxt;
			count_ff <= count_nxt;
			full <= count_nxt == NUM_ENTRIES;	
			almost_full <= almost_full_nxt;	
			empty <= count_nxt == 0;
			almost_empty <= almost_empty_nxt;
			if (enqueue_en)
				fifo_data[tail_ff] <= value_i;
				
			if (head_nxt == tail_ff && enqueue_en)
				value_o <= value_i;	// Bypass
			else
				value_o <= fifo_data[head_nxt];
		end
	end
endmodule

// Local Variables:
// verilog-typedef-regexp:"_t$"
// End:

