//
// Synchronous FIFO
//

module sync_fifo
	#(parameter					WIDTH = 32,
	parameter					COUNT = 4,
	parameter					ADDR_WIDTH = 2)	// log2(COUNT)

	(input						clk,
	output reg					full_o,
	input						enqueue_i,
	input [WIDTH - 1:0]			value_i,
	output reg					empty_o,
	input						dequeue_i,
	output reg[WIDTH - 1:0]		value_o);

	reg[WIDTH - 1:0] 			fifo_data[0:COUNT - 1];
	reg[ADDR_WIDTH - 1:0]		head_ff;
	reg[ADDR_WIDTH - 1:0]		tail_ff;
	reg							empty_nxt;
	reg							full_nxt;
	reg[ADDR_WIDTH - 1:0]  		head_nxt;
	reg[ADDR_WIDTH - 1:0]  		tail_nxt;

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
			full_nxt = head_nxt == tail_ff;
			empty_nxt = 0;
		end
		else if (dequeue_i && ~enqueue_i)
		begin
			// Queue count is decreasing
			full_nxt = 0;
			empty_nxt = tail_nxt == head_ff;
		end
		else
		begin
			// Queue count remains the same
			full_nxt = full_o;
			empty_nxt = empty_o;
		end
	end

	always @(posedge clk)
	begin
		value_o 			<= #1 fifo_data[head_ff];
		head_ff 			<= #1 head_nxt;
		tail_ff 			<= #1 tail_nxt;
		full_o 				<= #1 full_nxt;
		empty_o 			<= #1 empty_nxt;
		if (enqueue_i)
			fifo_data[tail_ff] <= #1 value_i;
	end
endmodule
