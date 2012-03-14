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
	input				update_lru_i,	// If we've actually used the granted unit, set this to one to update
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
	begin
		if (update_lru_i && (req0_i | req1_i | req2_i | req3_i))
			lru_bits_ff <= #1 lru_bits_nxt;
	end
	
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

	assertion #("arbiter4: unit 0 granted but not requested") a0(
		.clk(clk), .test(grant0_o & !req0_i));
	assertion #("arbiter4: unit 1 granted but not requested") a1(
		.clk(clk), .test(grant1_o & !req1_i));
	assertion #("arbiter4: unit 2 granted but not requested") a2(
		.clk(clk), .test(grant2_o & !req2_i));
	assertion #("arbiter4: unit 3 granted but not requested") a3(
		.clk(clk), .test(grant3_o & !req3_i));
	assertion #("arbiter4: more than one unit granted") a4(
		.clk(clk), .test(grant0_o + grant1_o + grant2_o + grant3_o > 1));
	assertion #("arbiter4: request and no grant") a5(
		.clk(clk), .test((req0_i | req1_i | req2_i | req3_i) 
		& !(grant0_o | grant1_o | grant2_o | grant3_o)));

	/////////////////////////////////////////////////
	// Validation code
	// Ensure that a unit always is granted within 3 cycles
	/////////////////////////////////////////////////

	integer delay0 = 0;
	integer delay1 = 0;
	integer delay2 = 0;
	integer delay3 = 0;
	
	always @(posedge clk)
	begin
		if (grant0_o || !req0_i)
			delay0 = 0;
		else if (update_lru_i)
			delay0 = delay0 + 1;

		if (grant1_o || !req1_i)
			delay1 = 0;
		else if (update_lru_i)
			delay1 = delay1 + 1;

		if (grant2_o || !req2_i)
			delay2 = 0;
		else if (update_lru_i)
			delay2 = delay2 + 1;

		if (grant3_o || !req3_i)
			delay3 = 0;
		else if (update_lru_i)
			delay3 = delay3 + 1;
	end

	assertion #("arbiter4: unit0 starved") a6(
		.clk(clk), .test(delay0 > 3));
	assertion #("arbiter4: unit1 starved") a7(
		.clk(clk), .test(delay1 > 3));
	assertion #("arbiter4: unit2 starved") a8(
		.clk(clk), .test(delay2 > 3));
	assertion #("arbiter4: unit3 starved") a9(
		.clk(clk), .test(delay3 > 3));
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