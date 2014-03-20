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
// FIFO, with synchronous read/write
// almost_full_o asserts when there are (NUM_ENTRIES - ALMOST_FULL_THRESHOLD) 
// or more entries queued.  almost_empty_o asserts when there are 
// ALMOST_EMPTY_THRESHOLD or fewer entries queued.  Note that almost_full_o
// will be asserted when full_o is asserted, as will almost_empty_o when
// empty_o is asserted.
//

module sync_fifo
	#(parameter DATA_WIDTH = 64,
	parameter NUM_ENTRIES = 2,
	parameter ALMOST_FULL_THRESHOLD = 1,
	parameter ALMOST_EMPTY_THRESHOLD = 1)

	(input                       clk,
	input                        reset,
	input                        flush_i,	// flush is synchronous, unlike reset
	output logic                 full_o,
	output logic                 almost_full_o,	
	input                        enqueue_i,
	input [DATA_WIDTH - 1:0]     value_i,
	output logic                 empty_o,
	output logic                 almost_empty_o,
	input                        dequeue_i,
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

	sram_1r1w #(.DATA_WIDTH(DATA_WIDTH), .SIZE(NUM_ENTRIES)) fifo_data(
		.clk(clk),
		.rd_addr(head_nxt),
		.rd_data(value_o),
		.rd_enable(1'b1),
		.wr_addr(tail_ff),
		.wr_data(value_i),
		.wr_enable(enqueue_i));

	always_comb
	begin
		if (flush_i)
		begin
			count_nxt = 0;
			head_nxt = 0;
			tail_nxt = 0;
			almost_full_nxt = 0;
			almost_empty_nxt = 1'b1;
		end
		else
		begin
			almost_full_nxt = almost_full_o;
			almost_empty_nxt = almost_empty_o;
			tail_nxt = tail_ff;
			head_nxt = head_ff;
			count_nxt = count_ff;
			
			if (enqueue_i)
			begin
				if (tail_ff == NUM_ENTRIES - 1)
					tail_nxt = 0;
				else
					tail_nxt = tail_ff + 1;
			end
				
			if (dequeue_i)
			begin
				if (head_ff == NUM_ENTRIES - 1)
					head_nxt = 0;
				else
					head_nxt = head_ff + 1;
			end

			if (enqueue_i && !dequeue_i)	
			begin
				count_nxt = count_ff + 1;
				if (count_ff == (NUM_ENTRIES - ALMOST_FULL_THRESHOLD - 1))
					almost_full_nxt = 1;

				if (count_ff == ALMOST_EMPTY_THRESHOLD)
					almost_empty_nxt = 0;
			end
			else if (dequeue_i && !enqueue_i)
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
			empty_o <= 1'b1;
			almost_empty_o <= 1'b1;

			/*AUTORESET*/
			// Beginning of autoreset for uninitialized flops
			almost_full_o <= 1'h0;
			count_ff <= {(1+(ADDR_WIDTH)){1'b0}};
			full_o <= 1'h0;
			head_ff <= {ADDR_WIDTH{1'b0}};
			tail_ff <= {ADDR_WIDTH{1'b0}};
			// End of automatics
		end
		else
		begin
			assert(count_ff != NUM_ENTRIES || !enqueue_i); // enqueue into full FIFO 
			assert(count_ff != 0 || !dequeue_i); // dequeue from empty FIFO 

			head_ff <= head_nxt;
			tail_ff <= tail_nxt;
			count_ff <= count_nxt;
			full_o <= count_nxt == NUM_ENTRIES;	
			almost_full_o <= almost_full_nxt;	
			empty_o <= count_nxt == 0;
			almost_empty_o <= almost_empty_nxt;
		end
	end
endmodule
