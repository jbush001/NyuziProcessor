module fpga_sim;

	reg clk50 = 0;

	/*AUTOWIRE*/
	// Beginning of automatic wires (for undeclared instantiated-module outputs)
	wire [8:0]	green_led;		// From fpga of fpga_top.v
	wire [6:0]	hex0;			// From fpga of fpga_top.v
	wire [6:0]	hex1;			// From fpga of fpga_top.v
	wire [6:0]	hex2;			// From fpga of fpga_top.v
	wire [6:0]	hex3;			// From fpga of fpga_top.v
	wire [17:0]	red_led;		// From fpga of fpga_top.v
	wire		uart_tx;		// From fpga of fpga_top.v
	// End of automatics
	wire uart_rx = 1'b1;

	fpga_top fpga(/*AUTOINST*/
		      // Outputs
		      .red_led		(red_led[17:0]),
		      .green_led	(green_led[8:0]),
		      .hex0		(hex0[6:0]),
		      .hex1		(hex1[6:0]),
		      .hex2		(hex2[6:0]),
		      .hex3		(hex3[6:0]),
		      .uart_tx		(uart_tx),
		      // Inputs
		      .clk50		(clk50),
		      .uart_rx		(uart_rx));

	integer i;

	initial 
	begin
		$dumpfile("trace.vcd");
		$dumpvars;

		for (i = 0; i < 8000; i = i + 1)
		begin
			#5 clk50 = 0;
			#5 clk50 = 1;
		end
	end

endmodule

// Local Variables:
// verilog-library-flags:("-y ../core" "-y ../fpga")
// End:
