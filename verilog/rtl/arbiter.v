//
// N-Way arbiter, with fairness.
//

module arbiter
	#(parameter NUM_ENTRIES = 4)

	(input						clk,
	input[NUM_ENTRIES - 1:0]	request,
	input						update_lru,	// If we've actually used the granted unit, set this to one to update
	output[NUM_ENTRIES - 1:0]	grant_oh);

	reg[NUM_ENTRIES - 1:0] base = 1;
	wire[NUM_ENTRIES * 2 - 1:0]	double_request = { request, request };
	wire[NUM_ENTRIES * 2 - 1:0] double_grant = double_request & ~(double_request - base);
	assign grant_oh = double_grant[NUM_ENTRIES * 2 - 1:NUM_ENTRIES] 
		| double_grant[NUM_ENTRIES - 1:0];

	always @(posedge clk)
	begin
		if (|grant_oh && update_lru)
			base <= #1 { grant_oh[NUM_ENTRIES - 2:0], grant_oh[NUM_ENTRIES - 1] };	// Rotate left
	end
endmodule

