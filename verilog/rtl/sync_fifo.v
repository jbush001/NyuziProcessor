//
// Synchronous FIFO
//
// Internally structured as a parallel shift register.  Enqueuing just shifts 
// everything down one.  A mux selects the head element.  A single index register
// keeps track of the head index (which is also the enqueued count).
//
// NOTE: can_enqueue_o depends on enqueue_i. Be careful to avoid making a 
// combinational loop.  This should probably be rethought.
//

module sync_fifo
	#(parameter					WIDTH = 64,
	parameter					COUNT = 2,
	parameter					ADDR_WIDTH = 1)	// log2(COUNT)

	(input						clk,
	input						flush_i,
	output 						can_enqueue_o,
	input						enqueue_i,
	input [WIDTH - 1:0]			value_i,
	output 						can_dequeue_o,
	input						dequeue_i,
	output [WIDTH - 1:0]		value_o);

	localparam					EMPTY_PTR = {COUNT{1'b1}};

	reg[WIDTH - 1:0] 			fifo_data[0:COUNT - 1];
	reg[ADDR_WIDTH:0]			head_ff = EMPTY_PTR;	// Note extra bit.  High bit is empty bit.
	reg[ADDR_WIDTH:0]			head_nxt = EMPTY_PTR;
	integer						i, j;
	
	initial
	begin
		// synthesis translate_off
		for (i = 0; i < COUNT; i = i + 1)
			fifo_data[i] = 0;
			
		// synthesis translate_on
	end

	assign value_o = fifo_data[head_ff[ADDR_WIDTH - 1:0]];
	assign can_enqueue_o = head_nxt != COUNT - 1;	// Assert a cycle early
	assign can_dequeue_o = !head_ff[ADDR_WIDTH];	// High bit signals empty

	always @*
	begin
		if (enqueue_i && ~dequeue_i)		
			head_nxt = head_ff + 1;
		else if (dequeue_i && ~enqueue_i)
			head_nxt = head_ff - 1;
		else
			head_nxt = head_ff;
	end

	always @(posedge clk)
	begin
		if (flush_i)
		begin
			for (j = 0; j < COUNT; j = j + 1)
				fifo_data[j] <= #1 0;

			head_ff <= #1 EMPTY_PTR;
		end
		else
		begin
			if (enqueue_i)
			begin
				// Shift a new value in.
				for (j = 1; j < COUNT; j = j + 1)
					fifo_data[j] <= #1 fifo_data[j - 1];
					
				fifo_data[0] <= #1 value_i;
			end
			head_ff <= #1 head_nxt;
		end
	end

	assertion #("attempt to enqueue into full fifo") 
		a0(.clk(clk), .test(head_ff == COUNT - 1 && enqueue_i));
	assertion #("attempt to dequeue from empty fifo") 
		a1(.clk(clk), .test(head_ff == EMPTY_PTR && dequeue_i));
endmodule
