//
// Two-way arbiter (subcomponent of arbiter4)
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
