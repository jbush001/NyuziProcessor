`timescale 1ns/1ns;

module modelsim_tb;
	reg clk50;
	
	wire uart_rx = 1'b1;
	
	/*AUTOWIRE*/
	// Beginning of automatic wires (for undeclared instantiated-module outputs)
	wire [12:0]	dram_addr;		// From fpga_top of fpga_top.v
	wire [1:0]	dram_ba;		// From fpga_top of fpga_top.v
	wire		dram_cas_n;		// From fpga_top of fpga_top.v
	wire		dram_cke;		// From fpga_top of fpga_top.v
	wire		dram_clk;		// From fpga_top of fpga_top.v
	wire		dram_cs_n;		// From fpga_top of fpga_top.v
	wire [31:0]	dram_dq;		// To/From fpga_top of fpga_top.v, ...
	wire [3:0]	dram_dqm;		// From fpga_top of fpga_top.v
	wire		dram_ras_n;		// From fpga_top of fpga_top.v
	wire		dram_we_n;		// From fpga_top of fpga_top.v
	wire [8:0]	green_led;		// From fpga_top of fpga_top.v
	wire [6:0]	hex0;			// From fpga_top of fpga_top.v
	wire [6:0]	hex1;			// From fpga_top of fpga_top.v
	wire [6:0]	hex2;			// From fpga_top of fpga_top.v
	wire [6:0]	hex3;			// From fpga_top of fpga_top.v
	wire [17:0]	red_led;		// From fpga_top of fpga_top.v
	wire		uart_tx;		// From fpga_top of fpga_top.v
	wire [7:0]	vga_b;			// From fpga_top of fpga_top.v
	wire		vga_blank_n;		// From fpga_top of fpga_top.v
	wire		vga_clk;		// From fpga_top of fpga_top.v
	wire [7:0]	vga_g;			// From fpga_top of fpga_top.v
	wire		vga_hs;			// From fpga_top of fpga_top.v
	wire [7:0]	vga_r;			// From fpga_top of fpga_top.v
	wire		vga_sync_n;		// From fpga_top of fpga_top.v
	wire		vga_vs;			// From fpga_top of fpga_top.v
	// End of automatics

	fpga_top fpga_top(/*AUTOINST*/
			  // Outputs
			  .red_led		(red_led[17:0]),
			  .green_led		(green_led[8:0]),
			  .hex0			(hex0[6:0]),
			  .hex1			(hex1[6:0]),
			  .hex2			(hex2[6:0]),
			  .hex3			(hex3[6:0]),
			  .uart_tx		(uart_tx),
			  .dram_clk		(dram_clk),
			  .dram_cke		(dram_cke),
			  .dram_cs_n		(dram_cs_n),
			  .dram_ras_n		(dram_ras_n),
			  .dram_cas_n		(dram_cas_n),
			  .dram_we_n		(dram_we_n),
			  .dram_ba		(dram_ba[1:0]),
			  .dram_addr		(dram_addr[12:0]),
			  .dram_dqm		(dram_dqm[3:0]),
			  .vga_r		(vga_r[7:0]),
			  .vga_g		(vga_g[7:0]),
			  .vga_b		(vga_b[7:0]),
			  .vga_clk		(vga_clk),
			  .vga_blank_n		(vga_blank_n),
			  .vga_hs		(vga_hs),
			  .vga_vs		(vga_vs),
			  .vga_sync_n		(vga_sync_n),
			  // Inouts
			  .dram_dq		(dram_dq[31:0]),
			  // Inputs
			  .clk50		(clk50),
			  .uart_rx		(uart_rx));

	sim_sdram #(
			.DATA_WIDTH(32),
			.ROW_ADDR_WIDTH(13),
			.COL_ADDR_WIDTH(10),
			.MEM_SIZE('h400000) 
		) sim_sdram(/*AUTOINST*/
			    // Inouts
			    .dram_dq		(dram_dq[31:0]),
			    // Inputs
			    .dram_clk		(dram_clk),
			    .dram_cke		(dram_cke),
			    .dram_cs_n		(dram_cs_n),
			    .dram_ras_n		(dram_ras_n),
			    .dram_cas_n		(dram_cas_n),
			    .dram_we_n		(dram_we_n),
			    .dram_ba		(dram_ba[1:0]),
			    .dram_addr		(dram_addr[12:0]));

	integer i;

	initial
	begin
		$readmemh("/home/jeff/src/GPGPU/tests/fpga/atomic_bug/bug.hex", fpga_top.axi_internal_ram.memory.data);
		fpga_top.simulator_reset = 1;
		for (i = 0; i < 3; i = i + 1)
		begin
			#10 clk50 = 1'b0;
			#10 clk50 = 1'b1;
		end

		fpga_top.simulator_reset = 0;		

		for (i = 0; i < 10000 && !fpga_top.processor_halt; i = i + 1)
		begin
			#10 clk50 = 1'b0;
			#10 clk50 = 1'b1;
		end
		
		$finish;
	end
endmodule

// Local Variables:
// verilog-library-flags:("-y ../core" "-y ../fpga")
// verilog-auto-inst-param-value: t
// End:
