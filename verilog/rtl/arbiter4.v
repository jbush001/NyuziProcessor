//
// 4-way LRU arbiter
// This is effectively a tree of 2-way arbiters.  The order is updated in 
// a pseudo-LRU fashion.
//

module arbiter4(
	input				clk,
	input				req0_i,
	input				req1_i,
	input				req2_i,
	input				req3_i,
	output 				grant0_o,
	output				grant1_o,
	output				grant2_o,
	output				grant3_o);
	
	wire				grant_left;
	wire				grant_right;
	wire				left_grant0;
	wire				left_grant1;
	wire				right_grant0;
	wire				right_grant1;
	reg[2:0]			lru_bits_ff = 0;
	reg[2:0]			lru_bits_nxt = 0;
	
	// Update LRU based on grant status
	always @*
	begin
		case ({grant0_o, grant1_o, grant2_o, grant3_o})
			4'b1000: lru_bits_nxt = { 2'b11, lru_bits_ff[0] };
			4'b0100: lru_bits_nxt = { 2'b01, lru_bits_ff[0] };
			4'b0010: lru_bits_nxt = { lru_bits_ff[2], 2'b01 };
			4'b0001: lru_bits_nxt = { lru_bits_ff[2], 2'b00 };
			default: lru_bits_nxt = lru_bits_ff;
		endcase
	end
	
	always @(posedge clk)
		lru_bits_ff <= #1 lru_bits_nxt;
	
	arbiter2 left_arb(
		.priority_i(lru_bits_ff[2]),
		.req0_i(req0_i),
		.req1_i(req1_i),
		.grant0_o(left_grant0),
		.grant1_o(left_grant1));

	arbiter2 right_arb(
		.priority_i(lru_bits_ff[0]),
		.req0_i(req2_i),
		.req1_i(req3_i),
		.grant0_o(right_grant0),
		.grant1_o(right_grant1));

	wire req_left = left_grant0 || left_grant1;
	wire req_right = right_grant0 || right_grant1;

	arbiter2 top_arb(
		.priority_i(lru_bits_ff[1]),
		.req0_i(req_left),
		.req1_i(req_right),
		.grant0_o(grant_left),
		.grant1_o(grant_right));
	
	assign grant0_o = left_grant0 && grant_left;
	assign grant1_o = left_grant1 && grant_left;
	assign grant2_o = right_grant0 && grant_right;
	assign grant3_o = right_grant1 && grant_right;

	/////////////////////////////////////////////////
	// Validation code
	// Ensure that:
	//  - We only grant one unit per cycle
	//  - We always grant if there are requests
	//  - A unit always is granted within 3 cycles
	//  - We don't grant to a unit that hasn't requested it.
	/////////////////////////////////////////////////

	// synthesis translate_off
	integer delay0 = 0;
	integer delay1 = 0;
	integer delay2 = 0;
	integer delay3 = 0;
	
	always @(posedge clk)
	begin
		// Make sure we only grant one unit in a cycle
		if (grant0_o + grant1_o + grant2_o + grant3_o > 1)
		begin
			$display("error: more than one unit granted");
			$finish;
		end
		
		// Verify that no unit is starved
		if (req0_i)
		begin
			if (!grant0_o) 
				delay0 = delay0 + 1;
			else
				delay0 = 0;
				
			if (delay0 > 3)
			begin
				$display("unit0 has been starved");
				$finish;
			end
		end
		else
			delay0 = 0;

		if (req1_i)
		begin
			if (!grant1_o) 
				delay1 = delay1 + 1;
			else
				delay1 = 0;

			if (delay1 > 3)
			begin
				$display("unit1 has been starved");
				$finish;
			end
		end
		else
			delay1 = 0;

		if (req2_i)
		begin
			if (!grant2_o) 
				delay2 = delay2 + 1;
			else
				delay2 = 0;

			if (delay2 > 3)
			begin
				$display("unit2 has been starved");
				$finish;
			end
		end
		else
			delay2 = 0;

		if (req3_i)
		begin
			if (!grant3_o) 
				delay3 = delay3 + 1;
			else
				delay3 = 0;

			if (delay3 > 3)
			begin
				$display("unit3 has been starved");
				$finish;
			end
		end
		else
			delay3 = 0;

		// Make sure we don't grant to a unit that hasn't requested it.
		if ((grant0_o & !req0_i)
			|| (grant1_o && !req1_i)
			|| (grant2_o && !req2_i)
			|| (grant3_o && !req3_i))
		begin
			$display("granted to unit that hasn't requested");
			$finish;
		end
	end
	// synthesis translate_on
endmodule

//
// Two-way arbiter
//
module arbiter2(
	input 			priority_i,
	input			req0_i,
	input			req1_i,
	output reg		grant0_o = 0,
	output reg		grant1_o = 0);

	always @*
	begin
		if (priority_i)
		begin
			// Prioritize req1
			grant0_o = req0_i && !req1_i;
			grant1_o = req1_i;
		end
		else
		begin
			// Prioritize req0
			grant0_o = req0_i;
			grant1_o = req1_i && !req0_i;
		end
	end
endmodule