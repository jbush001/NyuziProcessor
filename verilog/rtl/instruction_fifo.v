module instruction_fifo
	#(parameter					WIDTH = 64,
	parameter					COUNT = 2,
	parameter					ADDR_WIDTH = 1)	// log2(COUNT)

	(input						clk,
	input						flush_i,
	output 						instruction_request_o,
	input						enqueue_i,
	input [WIDTH - 1:0]			value_i,
	output 						instruction_ready_o,
	input						dequeue_i,
	output [WIDTH - 1:0]		value_o);

	parameter					EMPTY_PTR = {COUNT{1'b1}};

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
	assign instruction_request_o = head_nxt != COUNT - 1;	// Assert a cycle early
	assign instruction_ready_o = !head_ff[COUNT - 1];	

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
					fifo_data[j] <= fifo_data[j - 1];
					
				fifo_data[0] <= #1 value_i;
			end
			head_ff <= #1 head_nxt;
		end
	end

	// Checking code
	// synthesis translate_off
	always @(posedge clk)
	begin
		if (head_ff == COUNT - 1 && enqueue_i)
		begin
			$display("attempt to enqueue into full fifo");
			$finish;
		end
		
		if (head_ff == EMPTY_PTR && dequeue_i)
		begin
			$display("attempt to dequeue from empty fifo");
			$finish;
		end
	end
	// synthesis translate_on
endmodule
