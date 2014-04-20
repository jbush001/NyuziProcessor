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

module fifo_test;

	reg clk = 0;
	reg reset = 0;
	reg flush = 0;
	wire full;
	wire almost_full;
	wire empty;
	wire almost_emtpy;
	reg enqueue = 0;
	reg dequeue = 0;
	reg[31:0] value_i;
	wire[31:0] value_o;

	sync_fifo #(
		.DATA_WIDTH(32), 
		.NUM_ENTRIES(10), 
		.ALMOST_FULL_THRESHOLD(2), 
		.ALMOST_EMPTY_THRESHOLD(2))
		fifo (.clk(clk),
		.reset(reset),
		.flush_i(flush),
		.full_o(full),
		.almost_full_o(almost_full),	
		.enqueue_i(enqueue),
		.value_i(value_i),
		.empty_o(empty),
		.almost_empty_o(almost_empty),
		.dequeue_i(dequeue),
		.value_o(value_o));

	task check;
		input value;
		input[7:0] num;
	begin
		if (!value)
		begin
			$display("Check failed %d", num);
			$finish;
		end
	end
	endtask

	initial
	begin
		reset = 1;
		#5 reset = 0;
		
		check(empty, 0);
		check(!full, 1);
		check(almost_empty, 2);
		check(!almost_full, 3);
		
		enqueue = 1;
		#5 clk = 1;
		#5 clk = 0;
		
		check(!empty, 4);
		check(!full, 5);
		check(almost_empty, 6);
		check(!almost_full, 7);

		#5 clk = 1;
		#5 clk = 0;
		
		check(!empty, 8);
		check(!full, 9);
		check(almost_empty, 10);
		check(!almost_full, 11);

		#5 clk = 1;
		#5 clk = 0;
		
		check(!empty, 12);
		check(!full, 13);
		check(!almost_empty, 14);
		check(!almost_full, 15);

		enqueue = 0;
		dequeue = 1;

		#5 clk = 1;
		#5 clk = 0;
		
		check(!empty, 16);
		check(!full, 17);
		check(almost_empty, 18);
		check(!almost_full, 19);

		#5 clk = 1;
		#5 clk = 0;
		
		check(!empty, 20);
		check(!full, 21);
		check(almost_empty, 22);
		check(!almost_full, 23);

		#5 clk = 1;
		#5 clk = 0;
		
		check(empty, 24);
		check(!full, 25);
		check(almost_empty, 26);
		check(!almost_full, 27);

		$display("all good");

	end
endmodule
