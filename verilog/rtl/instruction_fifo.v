module instruction_fifo
	#(parameter					WIDTH = 64,
	parameter					COUNT = 2,
	parameter					ADDR_WIDTH = 1)	// log2(COUNT)

	(input						clk,
	input						flush_i,
	output 						instruction_request_o,
	input						enqueue_i,
	input [WIDTH - 1:0]			value_i,
	output reg					instruction_ready_o,
	input						dequeue_i,
	output [WIDTH - 1:0]		value_o);

	reg[WIDTH - 1:0] 			fifo_data[0:COUNT - 1];
	reg[ADDR_WIDTH - 1:0]		head_ff;
	reg[ADDR_WIDTH - 1:0]		tail_ff;
	reg							instruction_ready_nxt;
	reg							full_nxt;
	reg[ADDR_WIDTH - 1:0]  		head_nxt;
	reg[ADDR_WIDTH - 1:0]  		tail_nxt;
	reg							full_ff;
	integer						i;
	
	initial
	begin
		for (i = 0; i < COUNT; i = i + 1)
			fifo_data[i] = 0;
			
		full_ff = 0;
		instruction_ready_o = 0;
		head_ff = 0;
		tail_ff = 0;
		instruction_ready_nxt = 1;
		full_nxt = 0;
		head_nxt = 0;
		tail_nxt = 0;
	end

	assign value_o = fifo_data[head_ff];
	assign instruction_request_o = !full_nxt;

	always @*
	begin
		if (enqueue_i)
			tail_nxt = tail_ff + 1;
		else
			tail_nxt = tail_ff;
			
		if (dequeue_i)
			head_nxt = head_ff + 1;
		else
			head_nxt = head_ff;

		if (enqueue_i && ~dequeue_i)		
		begin
			// Queue count is increasing
			full_nxt = tail_nxt == head_ff;
			instruction_ready_nxt = 1;
		end
		else if (dequeue_i && ~enqueue_i)
		begin
			// Queue count is decreasing
			full_nxt = 0;
			instruction_ready_nxt = head_nxt != tail_ff;
		end
		else
		begin
			// Queue count remains the same
			full_nxt = full_ff;
			instruction_ready_nxt = instruction_ready_o;
		end
	end
	
	// synthesis translate_off
	always @(posedge clk)
	begin
		if (full_ff && enqueue_i)
		begin
			$display("attempt to enqueue into full fifo");
			$finish;
		end
		
		if (!instruction_ready_o && dequeue_i)
		begin
			$display("attempt to dequeue from empty fifo");
			$finish;
		end
	end
	
	// synthesis translate_on

	always @(posedge clk)
	begin
		if (flush_i)
		begin
			head_ff 				<= #1 0;
			tail_ff 				<= #1 0;
			full_ff 				<= #1 0;
			instruction_ready_o 	<= #1 0;
		end
		else
		begin
			head_ff 				<= #1 head_nxt;
			tail_ff 				<= #1 tail_nxt;
			full_ff 				<= #1 full_nxt;
			instruction_ready_o 	<= #1 instruction_ready_nxt;
			if (enqueue_i)
				fifo_data[tail_ff] <= #1 value_i;
		end
	end
endmodule
