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
// Synchronous FIFO
//

module sync_fifo
	#(parameter					WIDTH = 64,
	parameter					NUM_ENTRIES = 2,
	parameter					ADDR_WIDTH = 1)	// clog2(NUM_ENTRIES) 

	(input						clk,
	input						flush_i,
	output reg					full_o = 0,
	output reg					almost_full_o = 0,	// asserts when there is one entry left
	input						enqueue_i,
	input [WIDTH - 1:0]			value_i,
	output reg					empty_o,
	input						dequeue_i,
	output [WIDTH - 1:0]		value_o);

	reg[ADDR_WIDTH - 1:0]		head_ff = 0;
	reg[ADDR_WIDTH - 1:0]		head_nxt = 0;
	reg[ADDR_WIDTH - 1:0]		tail_ff = 0;
	reg[ADDR_WIDTH - 1:0]		tail_nxt = 0;
	reg[ADDR_WIDTH:0]			count_ff = 0;
	reg[ADDR_WIDTH:0]			count_nxt = 0;

	initial
	begin
		empty_o = 1;	
	end

	sram_1r1w #(WIDTH, NUM_ENTRIES, ADDR_WIDTH) fifo_data(
		.clk(clk),
		.rd_addr(head_nxt),
		.rd_data(value_o),
		.wr_addr(tail_ff),
		.wr_data(value_i),
		.wr_enable(enqueue_i));

	always @*
	begin
		if (flush_i)
		begin
			count_nxt = 0;
			head_nxt = 0;
			tail_nxt = 0;
		end
		else
		begin
			if (enqueue_i)
			begin
				if (tail_ff == NUM_ENTRIES - 1)
					tail_nxt = 0;
				else
					tail_nxt = tail_ff + 1;
			end
			else
				tail_nxt = tail_ff;
				
			if (dequeue_i)
			begin
				if (head_ff == NUM_ENTRIES - 1)
					head_nxt = 0;
				else
					head_nxt = head_ff + 1;
			end
			else 
				head_nxt = head_ff;

			if (enqueue_i && ~dequeue_i)		
				count_nxt = count_ff + 1;
			else if (dequeue_i && ~enqueue_i)
				count_nxt = count_ff - 1;
			else
				count_nxt = count_ff;
		end	
	end

	always @(posedge clk)
	begin
		head_ff <= #1 head_nxt;
		tail_ff <= #1 tail_nxt;
		count_ff <= #1 count_nxt;
		full_o <= #1 count_nxt == NUM_ENTRIES;	
		almost_full_o <= #1 count_nxt == NUM_ENTRIES - 1;	
		empty_o <= #1 count_nxt == 0;
	end

	assertion #("attempt to enqueue into full fifo") 
		a0(.clk(clk), .test(count_ff == NUM_ENTRIES && enqueue_i));
	assertion #("attempt to dequeue from empty fifo") 
		a1(.clk(clk), .test(count_ff == 0 && dequeue_i));
endmodule
