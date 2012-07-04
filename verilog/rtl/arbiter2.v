//
// Two-way arbiter (subcomponent of arbiter4)
//

module arbiter2(
	input 			lru,
	input			req0,
	input			req1,
	output reg		grant0 = 0,
	output reg		grant1 = 0);

	always @*
	begin
		if (lru)
		begin
			// Prioritize req1
			grant0 = req0 && !req1;
			grant1 = req1;
		end
		else
		begin
			// Prioritize req0
			grant0 = req0;
			grant1 = req1 && !req0;
		end
	end
endmodule
