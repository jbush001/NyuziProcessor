module fpga_sim;

	reg clk50 = 0;

	/*AUTOWIRE*/
	// Beginning of automatic wires (for undeclared instantiated-module outputs)
	wire [12:0]	addr;			// From fpga of fpga_top.v
	wire [1:0]	ba;			// From fpga of fpga_top.v
	wire		cas_n;			// From fpga of fpga_top.v
	wire		cke;			// From fpga of fpga_top.v
	wire		cs_n;			// From fpga of fpga_top.v
	wire [31:0]	dq;			// To/From fpga of fpga_top.v, ...
	wire [3:0]	dqm;			// From fpga of fpga_top.v
	wire		dram_clk;		// From fpga of fpga_top.v
	wire [8:0]	green_led;		// From fpga of fpga_top.v
	wire [6:0]	hex0;			// From fpga of fpga_top.v
	wire [6:0]	hex1;			// From fpga of fpga_top.v
	wire [6:0]	hex2;			// From fpga of fpga_top.v
	wire [6:0]	hex3;			// From fpga of fpga_top.v
	wire		ras_n;			// From fpga of fpga_top.v
	wire [17:0]	red_led;		// From fpga of fpga_top.v
	wire		uart_tx;		// From fpga of fpga_top.v
	wire		we_n;			// From fpga of fpga_top.v
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
		      .dram_clk		(dram_clk),
		      .cke		(cke),
		      .cs_n		(cs_n),
		      .ras_n		(ras_n),
		      .cas_n		(cas_n),
		      .we_n		(we_n),
		      .ba		(ba[1:0]),
		      .addr		(addr[12:0]),
		      .dqm		(dqm[3:0]),
		      // Inouts
		      .dq		(dq[31:0]),
		      // Inputs
		      .clk50		(clk50),
		      .uart_rx		(uart_rx));


	sim_sdram #(.DATA_WIDTH(32), .ROW_ADDR_WIDTH(13), .COL_ADDR_WIDTH(10)) memory(
		.clk(dram_clk),
		.dqmh(1'b0),
		.dqml(1'b0),
		/*AUTOINST*/
										      // Inouts
										      .dq		(dq[31:0]),
										      // Inputs
										      .cke		(cke),
										      .cs_n		(cs_n),
										      .ras_n		(ras_n),
										      .cas_n		(cas_n),
										      .we_n		(we_n),
										      .ba		(ba[1:0]),
										      .addr		(addr[12:0]));	

	integer i;

	reg[17:0] old_led = 0;
	initial 
	begin
		$dumpfile("trace.lxt");
		$dumpvars;

		for (i = 0; i < 120000; i = i + 1)
		begin
			#5 clk50 = 0;
			if (red_led != old_led)
			begin
				$display("%b", red_led);
				old_led = red_led;
			end

			#5 clk50 = 1;
		end
	end

endmodule

// Local Variables:
// verilog-library-flags:("-y ../core" "-y ../fpga")
// verilog-auto-inst-param-value: t
// End:
