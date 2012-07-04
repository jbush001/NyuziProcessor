//
// 4-way LRU arbiter
// This is effectively a tree of 2-way arbiters.  The order is updated in 
// a pseudo-LRU fashion.
//

module arbiter4(
	input				clk,
	input				req0,
	input				req1,
	input				req2,
	input				req3,
	input				update_lru,	// If we've actually used the granted unit, set this to one to update
	output 				grant0,
	output				grant1,
	output				grant2,
	output				grant3);
	
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
		case ({grant0, grant1, grant2, grant3})
			4'b1000: lru_bits_nxt = { 2'b11, lru_bits_ff[0] };
			4'b0100: lru_bits_nxt = { 2'b01, lru_bits_ff[0] };
			4'b0010: lru_bits_nxt = { lru_bits_ff[2], 2'b01 };
			4'b0001: lru_bits_nxt = { lru_bits_ff[2], 2'b00 };
			default: lru_bits_nxt = lru_bits_ff;
		endcase
	end
	
	always @(posedge clk)
	begin
		if (update_lru && (req0 | req1 | req2 | req3))
			lru_bits_ff <= #1 lru_bits_nxt;
	end
	
	arbiter2 left_arb(
		.lru(lru_bits_ff[2]),
		.req0(req0),
		.req1(req1),
		.grant0(left_grant0),
		.grant1(left_grant1));

	arbiter2 right_arb(
		.lru(lru_bits_ff[0]),
		.req0(req2),
		.req1(req3),
		.grant0(right_grant0),
		.grant1(right_grant1));

	wire req_left = left_grant0 || left_grant1;
	wire req_right = right_grant0 || right_grant1;

	arbiter2 top_arb(
		.lru(lru_bits_ff[1]),
		.req0(req_left),
		.req1(req_right),
		.grant0(grant_left),
		.grant1(grant_right));
	
	assign grant0 = left_grant0 && grant_left;
	assign grant1 = left_grant1 && grant_left;
	assign grant2 = right_grant0 && grant_right;
	assign grant3 = right_grant1 && grant_right;

	assertion #("arbiter4: unit 0 granted but not requested") a0(
		.clk(clk), .test(grant0 & !req0));
	assertion #("arbiter4: unit 1 granted but not requested") a1(
		.clk(clk), .test(grant1 & !req1));
	assertion #("arbiter4: unit 2 granted but not requested") a2(
		.clk(clk), .test(grant2 & !req2));
	assertion #("arbiter4: unit 3 granted but not requested") a3(
		.clk(clk), .test(grant3 & !req3));
	assertion #("arbiter4: more than one unit granted") a4(
		.clk(clk), .test(grant0 + grant1 + grant2 + grant3 > 1));
	assertion #("arbiter4: request and no grant") a5(
		.clk(clk), .test((req0 | req1 | req2 | req3) 
		& !(grant0 | grant1 | grant2 | grant3)));

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
		if (grant0 || !req0)
			delay0 <= #1 0;
		else if (update_lru)
			delay0 <= #1 delay0 + 1;

		if (grant1 || !req1)
			delay1 <= #1 0;
		else if (update_lru)
			delay1 <= #1 delay1 + 1;

		if (grant2 || !req2)
			delay2 <= #1 0;
		else if (update_lru)
			delay2 <= #1 delay2 + 1;

		if (grant3 || !req3)
			delay3 <= #1 0;
		else if (update_lru)
			delay3 <= #1 delay3 + 1;
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

