// 
// Copyright (C) 2011-2014 Jeff Bush
// 
// This library is free software; you can redistribute it and/or
// modify it under the terms of the GNU Library General Public
// License as published by the Free Software Foundation; either
// version 2 of the License, or (at your option) any later version.
// 
// This library is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
// Library General Public License for more details.
// 
// You should have received a copy of the GNU Library General Public
// License along with this library; if not, write to the
// Free Software Foundation, Inc., 51 Franklin St, Fifth Floor,
// Boston, MA  02110-1301, USA.
// 


`include "../core/defines.v"

module fpga_top(
	input						clk50,

	// Der blinkenlights
	output logic[17:0]			red_led,
	output logic[8:0]			green_led,
	output logic[6:0]			hex0,
	output logic[6:0]			hex1,
	output logic[6:0]			hex2,
	output logic[6:0]			hex3,
	
	// UART
	output						uart_tx,
	input						uart_rx,

	// SDRAM	
	output						dram_clk,
	output 						dram_cke, 
	output 						dram_cs_n, 
	output 						dram_ras_n, 
	output 						dram_cas_n, 
	output 						dram_we_n,
	output [1:0]				dram_ba,	
	output [12:0] 				dram_addr,
	output [3:0]				dram_dqm,
	inout [31:0]				dram_dq,
	
	// VGA
	output [7:0]				vga_r,
	output [7:0]				vga_g,
	output [7:0]				vga_b,
	output 						vga_clk,
	output 						vga_blank_n,
	output 						vga_hs,
	output 						vga_vs,
	output 						vga_sync_n);

	// We always access the full word width, so hard code these to active (low)
	assign dram_dqm = 4'b0000;

	/*AUTOWIRE*/
	// Beginning of automatic wires (for undeclared instantiated-module outputs)
	wire [31:0]	io_address;		// From gpgpu of gpgpu.v
	wire		io_read_en;		// From gpgpu of gpgpu.v
	wire [31:0]	io_write_data;		// From gpgpu of gpgpu.v
	wire		io_write_en;		// From gpgpu of gpgpu.v
	logic		pc_event_dram_page_hit;	// From sdram_controller of sdram_controller.v
	logic		pc_event_dram_page_miss;// From sdram_controller of sdram_controller.v
	wire		processor_halt;		// From gpgpu of gpgpu.v
	// End of automatics

	axi_interface axi_bus_core();
	axi_interface axi_bus_m0();
	axi_interface axi_bus_m1();
	axi_interface axi_bus_s0();
	axi_interface axi_bus_s1();
	wire jtag_reset;
	logic simulator_reset = 0;
	wire global_reset = simulator_reset || jtag_reset;
	wire[31:0] loader_addr;
	wire[31:0] loader_data;
	wire loader_we;
	logic [31:0] io_read_data;
	wire [31:0] uart_read_data;
	logic [31:0] timer_val;

	// There are two clock domains: the memory/bus clock runs at 50 Mhz and the CPU
	// clock runs at 25 Mhz.  It's necessary to run memory that fast to have
	// enough bandwidth to satisfy the VGA controller, but the CPU has an 
	// Fmax of ~30Mhz.  Note that CPU could actually run at a non-integer divisor
	// of the bus clock, since there is a proper bridge.  I may put a PLL here at 
	// some point to allow squeezing a little more performance out, but this is 
	// simplest for now.
	wire mem_clk = clk50;
	wire core_reset;
	logic core_clk = 0;

	synchronizer #(.RESET_STATE(1)) core_reset_synchronizer(
		.clk(core_clk),
		.reset(global_reset),
		.data_i(0),
		.data_o(core_reset));

	always_ff @(posedge clk50)
		core_clk <= !core_clk;	// Divide core_clock down

	/* gpgpu AUTO_TEMPLATE(
		.clk(core_clk),
		.reset(core_reset),
		.axi_bus(axi_bus_core[]),
		);
	*/
	gpgpu gpgpu(
		/*AUTOINST*/
		    // Interfaces
		    .axi_bus		(axi_bus_core),		 // Templated
		    // Outputs
		    .processor_halt	(processor_halt),
		    .io_write_en	(io_write_en),
		    .io_read_en		(io_read_en),
		    .io_address		(io_address[31:0]),
		    .io_write_data	(io_write_data[31:0]),
		    // Inputs
		    .clk		(core_clk),		 // Templated
		    .reset		(core_reset),		 // Templated
		    .io_read_data	(io_read_data[31:0]));

	always_ff @(posedge core_clk, posedge core_reset)
	begin
		if (core_reset)
		begin
			/*AUTORESET*/
			// Beginning of autoreset for uninitialized flops
			green_led <= 9'h0;
			hex0 <= 7'h0;
			hex1 <= 7'h0;
			hex2 <= 7'h0;
			hex3 <= 7'h0;
			red_led <= 18'h0;
			timer_val <= 32'h0;
			// End of automatics
		end
		else
		begin
			timer_val <= timer_val + 1;
		
			if (io_write_en)
			begin
				case (io_address)
					0: red_led <= io_write_data[17:0];
					4: green_led <= io_write_data[8:0];
					8: hex0 <= io_write_data[6:0];
					12: hex1 <= io_write_data[6:0];
					16: hex2 <= io_write_data[6:0];
					20: hex3 <= io_write_data[6:0];
				endcase
			end
		end
	end
	
	always_comb
	begin
		case (io_address)
			'h18, 'h1c: io_read_data = uart_read_data;
			'h24: io_read_data = timer_val;
			default: io_read_data = 0;
		endcase
	end

`ifdef ENABLE_TRACE_MODULE
	// Debug trace model takes over the UART output to dump events.
	wire[31:0] capture_data = 0;
	wire capture_enable = 0;
	wire trigger = 0;

	debug_trace #(.CAPTURE_WIDTH_BITS(32), .CAPTURE_SIZE(64), .BAUD_DIVIDE(27 * 8)) debug_trace(
		.clk(core_clk),
		.reset(core_reset),
		/*AUTOINST*/
												    // Outputs
												    .uart_tx		(uart_tx),
												    // Inputs
												    .capture_data	(capture_data[31:0]),
												    .capture_enable	(capture_enable),
												    .trigger		(trigger));
`else	
	uart #(.BASE_ADDRESS(24), .BAUD_DIVIDE(27)) uart(
		.clk(core_clk),
		.reset(core_reset),
		.io_read_data(uart_read_data),
		/*AUTOINST*/
							 // Outputs
							 .uart_tx		(uart_tx),
							 // Inputs
							 .io_address		(io_address[31:0]),
							 .io_read_en		(io_read_en),
							 .io_write_data		(io_write_data[31:0]),
							 .io_write_en		(io_write_en),
							 .uart_rx		(uart_rx));
`endif
	
	// Bridge signals from core clock domain to memory clock domain.
	/* axi_async_bridge AUTO_TEMPLATE(
		.clk_s(core_clk),
		.clk_m(mem_clk),
		.reset(global_reset),
		.axi_bus_s(axi_bus_core[]),
		.axi_bus_m(axi_bus_s0[]),
		);
	*/
	axi_async_bridge #(.ADDR_WIDTH(32), .DATA_WIDTH(32)) cpu_async_bridge(
		/*AUTOINST*/
									      // Interfaces
									      .axi_bus_s	(axi_bus_core),	 // Templated
									      .axi_bus_m	(axi_bus_s0),	 // Templated
									      // Inputs
									      .reset		(global_reset),	 // Templated
									      .clk_s		(core_clk),	 // Templated
									      .clk_m		(mem_clk));	 // Templated
			  			  
	/* axi_interconnect AUTO_TEMPLATE(
		.clk(mem_clk),
		.reset(global_reset));
	*/
	axi_interconnect axi_interconnect(
		/*AUTOINST*/
					  // Interfaces
					  .axi_bus_m0		(axi_bus_m0),
					  .axi_bus_m1		(axi_bus_m1),
					  .axi_bus_s0		(axi_bus_s0),
					  .axi_bus_s1		(axi_bus_s1),
					  // Inputs
					  .clk			(mem_clk),	 // Templated
					  .reset		(global_reset));	 // Templated
			  
	// Internal SRAM.  The system boots out of this.
	/* axi_internal_ram AUTO_TEMPLATE(
		.clk(mem_clk),
		.reset(global_reset),
		.axi_bus(axi_bus_m0),);
	*/
	axi_internal_ram #(.MEM_SIZE('h800)) axi_internal_ram(
		/*AUTOINST*/
							      // Interfaces
							      .axi_bus		(axi_bus_m0),	 // Templated
							      // Inputs
							      .clk		(mem_clk),	 // Templated
							      .reset		(global_reset),	 // Templated
							      .loader_we	(loader_we),
							      .loader_addr	(loader_addr[31:0]),
							      .loader_data	(loader_data[31:0]));

	// This module loads data over JTAG into axi_internal_ram and resets
	// the core.
	jtagloader jtagloader(
		.we(loader_we),
		.addr(loader_addr),
		.data(loader_data),
		.reset(jtag_reset),
		.clk(mem_clk));
		
	/* sdram_controller AUTO_TEMPLATE(
		.clk(mem_clk),
		.reset(global_reset),
		.axi_bus(axi_bus_m1),);
	*/
	sdram_controller #(
			.DATA_WIDTH(32), 
			.ROW_ADDR_WIDTH(13), 
			.COL_ADDR_WIDTH(10),

			// 50 Mhz = 20ns clock.  Each value is clocks of delay minus one.
			// Timing values based on datasheet for A3V64S40ETP SDRAM parts
			// on the DE2-115 board.
			.T_REFRESH(390),          // 64 ms / 8192 rows = 7.8125 uS  
			.T_POWERUP(10000),        // 200 us		
			.T_ROW_PRECHARGE(1),      // 21 ns	
			.T_AUTO_REFRESH_CYCLE(3), // 75 ns
			.T_RAS_CAS_DELAY(1),      // 21 ns	
			.T_CAS_LATENCY(1)		  // 21 ns (2 cycles)
		) sdram_controller(
			/*AUTOINST*/
				   // Interfaces
				   .axi_bus		(axi_bus_m1),	 // Templated
				   // Outputs
				   .dram_clk		(dram_clk),
				   .dram_cke		(dram_cke),
				   .dram_cs_n		(dram_cs_n),
				   .dram_ras_n		(dram_ras_n),
				   .dram_cas_n		(dram_cas_n),
				   .dram_we_n		(dram_we_n),
				   .dram_ba		(dram_ba[1:0]),
				   .dram_addr		(dram_addr[12:0]),
				   .pc_event_dram_page_miss(pc_event_dram_page_miss),
				   .pc_event_dram_page_hit(pc_event_dram_page_hit),
				   // Inouts
				   .dram_dq		(dram_dq[31:0]),
				   // Inputs
				   .clk			(mem_clk),	 // Templated
				   .reset		(global_reset));	 // Templated

	/* vga_controller AUTO_TEMPLATE(
		.clk(mem_clk),
		.reset(global_reset),
		.axi_bus(axi_bus_s1));
	*/
	vga_controller vga_controller(
		/*AUTOINST*/
				      // Interfaces
				      .axi_bus		(axi_bus_s1),	 // Templated
				      // Outputs
				      .vga_r		(vga_r[7:0]),
				      .vga_g		(vga_g[7:0]),
				      .vga_b		(vga_b[7:0]),
				      .vga_clk		(vga_clk),
				      .vga_blank_n	(vga_blank_n),
				      .vga_hs		(vga_hs),
				      .vga_vs		(vga_vs),
				      .vga_sync_n	(vga_sync_n),
				      // Inputs
				      .clk		(mem_clk),	 // Templated
				      .reset		(global_reset));	 // Templated

endmodule

// Local Variables:
// verilog-library-flags:("-y ../core" "-y ../testbench" "-y ../../fpga_common")
// verilog-auto-inst-param-value: t
// End:
