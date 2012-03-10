module assertion
	#(parameter 	MESSAGE = "")
	(input			clk,
	input			test);

	// synthesis translate_off
	always @(posedge clk)
	begin
		if (test)
		begin
			$display("ASSERTION FAILED: %s", MESSAGE);
			$finish;
		end
	end
	// synthesis translate_on
endmodule
