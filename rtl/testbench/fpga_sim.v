// 
// Copyright 2013 Jeff Bush
// 
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
// 
//     http://www.apache.org/licenses/LICENSE-2.0
// 
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
// 

// Simulate the FPGA configuration

module fpga_sim;

	reg clk50 = 0;
	reg uart_rx = 1;

	/*AUTOWIRE*/
	// Beginning of automatic wires (for undeclared instantiated-module outputs)
	wire [12:0]	dram_addr;		// From fpga of fpga_top.v
	wire [1:0]	dram_ba;		// From fpga of fpga_top.v
	wire		dram_cas_n;		// From fpga of fpga_top.v
	wire		dram_cke;		// From fpga of fpga_top.v
	wire		dram_clk;		// From fpga of fpga_top.v
	wire		dram_cs_n;		// From fpga of fpga_top.v
	wire [31:0]	dram_dq;		// To/From fpga of fpga_top.v
	wire [3:0]	dram_dqm;		// From fpga of fpga_top.v
	wire		dram_ras_n;		// From fpga of fpga_top.v
	wire		dram_we_n;		// From fpga of fpga_top.v
	wire [8:0]	green_led;		// From fpga of fpga_top.v
	wire [6:0]	hex0;			// From fpga of fpga_top.v
	wire [6:0]	hex1;			// From fpga of fpga_top.v
	wire [6:0]	hex2;			// From fpga of fpga_top.v
	wire [6:0]	hex3;			// From fpga of fpga_top.v
	wire [17:0]	red_led;		// From fpga of fpga_top.v
	wire		uart_tx;		// From fpga of fpga_top.v
	wire [7:0]	vga_b;			// From fpga of fpga_top.v
	wire		vga_blank_n;		// From fpga of fpga_top.v
	wire		vga_clk;		// From fpga of fpga_top.v
	wire [7:0]	vga_g;			// From fpga of fpga_top.v
	wire		vga_hs;			// From fpga of fpga_top.v
	wire [7:0]	vga_r;			// From fpga of fpga_top.v
	wire		vga_sync_n;		// From fpga of fpga_top.v
	wire		vga_vs;			// From fpga of fpga_top.v
	// End of automatics

	fpga_top fpga(
			/*AUTOINST*/
		      // Outputs
		      .red_led		(red_led[17:0]),
		      .green_led	(green_led[8:0]),
		      .hex0		(hex0[6:0]),
		      .hex1		(hex1[6:0]),
		      .hex2		(hex2[6:0]),
		      .hex3		(hex3[6:0]),
		      .uart_tx		(uart_tx),
		      .dram_clk		(dram_clk),
		      .dram_cke		(dram_cke),
		      .dram_cs_n	(dram_cs_n),
		      .dram_ras_n	(dram_ras_n),
		      .dram_cas_n	(dram_cas_n),
		      .dram_we_n	(dram_we_n),
		      .dram_ba		(dram_ba[1:0]),
		      .dram_addr	(dram_addr[12:0]),
		      .dram_dqm		(dram_dqm[3:0]),
		      .vga_r		(vga_r[7:0]),
		      .vga_g		(vga_g[7:0]),
		      .vga_b		(vga_b[7:0]),
		      .vga_clk		(vga_clk),
		      .vga_blank_n	(vga_blank_n),
		      .vga_hs		(vga_hs),
		      .vga_vs		(vga_vs),
		      .vga_sync_n	(vga_sync_n),
		      // Inouts
		      .dram_dq		(dram_dq[31:0]),
		      // Inputs
		      .clk50		(clk50),
		      .uart_rx		(uart_rx));


	sim_sdram #(
			.DATA_WIDTH(32), 
			.ROW_ADDR_WIDTH(13), 
			.COL_ADDR_WIDTH(10),
			.MEM_SIZE('h12C000)) memory(
		.clk(dram_clk),
		.dqmh(1'b0),
		.dqml(1'b0),
		.dq(dram_dq),
		.cke(dram_cke),
		.cs_n(dram_cs_n),
		.ras_n(dram_ras_n),
		.cas_n(dram_cas_n),
		.we_n(dram_we_n),
		.ba(dram_ba),
		.addr(dram_addr));	

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
	
	localparam CLOCKS_PER_BIT = 434;

	task send_serial_character;
		input[7:0] char;
		integer count;

		begin
			// Start bit
			repeat (CLOCKS_PER_BIT)
				@(posedge clk50) uart_rx = 0;

			for (count = 0; count < 8; count = count + 1)
			begin
				repeat (CLOCKS_PER_BIT)
					@(posedge clk50) uart_rx = char[count];
			end	

			// Stop bit
			repeat (CLOCKS_PER_BIT)
				@(posedge clk50) uart_rx = 1;
		end
	endtask
	
	initial
	begin
		#500 send_serial_character(65);
		send_serial_character(67);
		send_serial_character(68);
	end

endmodule

// Local Variables:
// verilog-library-flags:("-y ../core" "-y ../fpga")
// verilog-auto-inst-param-value: t
// End:
