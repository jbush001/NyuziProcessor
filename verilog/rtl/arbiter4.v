//
// 4-way LRU arbiter
// This is effectively a tree of 2-way arbiters.  The order is updated in 
// a pseudo-LRU fashion.  A 1 bit in the LRU represents the right branch, and a 0
// represents the left branch.
//
//        [1]
//       /   \
//    [2]     [0]
//   /   \   /   \
//  3     2 1     0
//

module arbiter4(
	input				clk,
	input[3:0]			request,
	input				update_lru,	// If we've actually used the granted unit, set this to one to update
	output[3:0]			grant_oh);
	
	wire[1:0]			top_grant;
	wire[1:0]			left_grant;
	wire[1:0]			right_grant;
	reg[2:0]			lru_bits_ff = 0;
	reg[2:0]			lru_bits_nxt = 0;
	
	// Update LRU based on grant status
	always @*
	begin
		case (grant_oh)
			4'b1000: lru_bits_nxt = { 2'b11, lru_bits_ff[0] };
			4'b0100: lru_bits_nxt = { 2'b01, lru_bits_ff[0] };
			4'b0010: lru_bits_nxt = { lru_bits_ff[2], 2'b01 };
			4'b0001: lru_bits_nxt = { lru_bits_ff[2], 2'b00 };
			default: lru_bits_nxt = lru_bits_ff;
		endcase
	end
	
	always @(posedge clk)
	begin
		if (update_lru && |request)
			lru_bits_ff <= #1 lru_bits_nxt;
	end

	arbiter2 left_arb(
		.lru(lru_bits_ff[2]),
		.request(request[3:2]),
		.grant(left_grant));

	arbiter2 right_arb(
		.lru(lru_bits_ff[0]),
		.request(request[1:0]),
		.grant(right_grant));

	arbiter2 top_arb(
		.lru(lru_bits_ff[1]),
		.request({|left_grant, |right_grant}),
		.grant(top_grant));
	
	assign grant_oh = { left_grant, right_grant } 
		& { {2{top_grant[1]}}, {2{top_grant[0]}} };

	assertion #("arbiter4: unit granted but not requested") a0(
		.clk(clk), .test(|(grant_oh & ~request)));
	assertion #("arbiter4: more than one unit granted") a4(
		.clk(clk), .test(grant_oh[0] + grant_oh[1] + grant_oh[2] + grant_oh[3] > 1));
	assertion #("arbiter4: request and no grant") a5(
		.clk(clk), .test(|request && !(|grant_oh)));

	/////////////////////////////////////////////////
	// Validation code
	// Ensure that a unit always is granted within 3 cycles
	/////////////////////////////////////////////////

	integer delay[0:3];
	integer i, j;
	
	initial
	begin
		for (i = 0; i < 4; i = i + 1)
			delay[i] = 0;
	end
	
	always @(posedge clk)
	begin
		for (j = 0; j < 4; j = j + 1)
		begin
			if (grant_oh[j] || !request[j])
				delay[j] <= #1 0;
			else if (update_lru)
				delay[j] <= #1 delay[j] + 1;
				
			if (delay[j] == 4)
			begin
				$display("arbiter4: unit %d starved", j);
				$finish;
			end
		end
	end
endmodule

