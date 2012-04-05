//
// Used to check for exceptional conditions during simulation
//

module assertion
	#(parameter 	MESSAGE = "")
	(input			clk,
	input			test);

	// synthesis translate_off
	always @(posedge clk)
	begin
		if (test !== 0)
		begin
			$display("ASSERTION FAILED: %s", MESSAGE);
			$finish;
		end
	end
	// synthesis translate_on
endmodule
