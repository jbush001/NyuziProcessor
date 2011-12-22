//
// Synchronous FIFO
//
// Note: will_be_full_o isn't registered, but depends on enqueue_i.
// Must avoid logic loop by making sure enqueue_i doesn't depend on this
// value.
//

module sync_fifo
	#(parameter					WIDTH = 32,
	parameter					COUNT = 4,
	parameter					ADDR_WIDTH = 2)	// log2(COUNT)

	(input						clk,
	input						clear_i,
	output reg					full_o = 0,
	output 						will_be_full_o,
	input						enqueue_i,
	input [WIDTH - 1:0]			value_i,
	output reg					empty_o = 1,
	input						dequeue_i,
	output [WIDTH - 1:0]		value_o);

	reg[WIDTH - 1:0] 			fifo_data[0:COUNT - 1];
	reg[ADDR_WIDTH - 1:0]		head_ff = 0;
	reg[ADDR_WIDTH - 1:0]		tail_ff = 0;
	reg							empty_nxt = 0;
	reg							full_nxt = 0;
	reg[ADDR_WIDTH - 1:0]  		head_nxt = 0;
	reg[ADDR_WIDTH - 1:0]  		tail_nxt = 0;
	integer						i;

	initial
	begin
		for (i = 0; i < COUNT; i = i + 1)
			fifo_data[i] = 0;
	end

	assign value_o = fifo_data[head_ff];
	assign will_be_full_o = full_nxt;

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
			empty_nxt = 0;
		end
		else if (dequeue_i && ~enqueue_i)
		begin
			// Queue count is decreasing
			full_nxt = 0;
			empty_nxt = head_nxt == tail_ff;
		end
		else
		begin
			// Queue count remains the same
			full_nxt = full_o;
			empty_nxt = empty_o;
		end
	end
	
	// synthesis translate_off
	always @(posedge clk)
	begin
		if (full_o && enqueue_i)
		begin
			$display("attempt to enqueue into full fifo");
			$finish;
		end
		
		if (empty_o && dequeue_i)
		begin
			$display("attempt to dequeue from empty fifo");
			$finish;
		end
	end
	
	// synthesis translate_on

	always @(posedge clk)
	begin
		if (clear_i)
		begin
			head_ff 			<= #1 0;
			tail_ff 			<= #1 0;
			full_o 				<= #1 0;
			empty_o 			<= #1 1;
		end
		else
		begin
			head_ff 			<= #1 head_nxt;
			tail_ff 			<= #1 tail_nxt;
			full_o 				<= #1 full_nxt;
			empty_o 			<= #1 empty_nxt;
			if (enqueue_i)
				fifo_data[tail_ff] <= #1 value_i;
		end
	end
endmodule
