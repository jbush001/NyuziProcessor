// 
// Copyright 2011-2013 Jeff Bush
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

`include "../core/defines.sv"

module fpga_top(
	input						clk50,

	// Der blinkenlights
	output reg[17:0]			red_led,
	output reg[8:0]				green_led,
	output reg[6:0]				hex0,
	output reg[6:0]				hex1,
	output reg[6:0]				hex2,
	output reg[6:0]				hex3,
	
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
	wire [31:0]	axi_araddr_core;	// From gpgpu of gpgpu.v
	wire [31:0]	axi_araddr_m0;		// From axi_interconnect of axi_interconnect.v
	wire [31:0]	axi_araddr_m1;		// From axi_interconnect of axi_interconnect.v
	wire [31:0]	axi_araddr_s0;		// From cpu_async_bridge of axi_async_bridge.v
	wire [31:0]	axi_araddr_s1;		// From vga_controller of vga_controller.v
	wire [7:0]	axi_arlen_core;		// From gpgpu of gpgpu.v
	wire [7:0]	axi_arlen_m0;		// From axi_interconnect of axi_interconnect.v
	wire [7:0]	axi_arlen_m1;		// From axi_interconnect of axi_interconnect.v
	wire [7:0]	axi_arlen_s0;		// From cpu_async_bridge of axi_async_bridge.v
	wire [7:0]	axi_arlen_s1;		// From vga_controller of vga_controller.v
	wire		axi_arready_core;	// From cpu_async_bridge of axi_async_bridge.v
	wire		axi_arready_m0;		// From axi_internal_ram of axi_internal_ram.v
	wire		axi_arready_m1;		// From sdram_controller of sdram_controller.v
	wire		axi_arready_s0;		// From axi_interconnect of axi_interconnect.v
	wire		axi_arready_s1;		// From axi_interconnect of axi_interconnect.v
	wire		axi_arvalid_core;	// From gpgpu of gpgpu.v
	wire		axi_arvalid_m0;		// From axi_interconnect of axi_interconnect.v
	wire		axi_arvalid_m1;		// From axi_interconnect of axi_interconnect.v
	wire		axi_arvalid_s0;		// From cpu_async_bridge of axi_async_bridge.v
	wire		axi_arvalid_s1;		// From vga_controller of vga_controller.v
	wire [31:0]	axi_awaddr_core;	// From gpgpu of gpgpu.v
	wire [31:0]	axi_awaddr_m0;		// From axi_interconnect of axi_interconnect.v
	wire [31:0]	axi_awaddr_m1;		// From axi_interconnect of axi_interconnect.v
	wire [31:0]	axi_awaddr_s0;		// From cpu_async_bridge of axi_async_bridge.v
	wire [7:0]	axi_awlen_core;		// From gpgpu of gpgpu.v
	wire [7:0]	axi_awlen_m0;		// From axi_interconnect of axi_interconnect.v
	wire [7:0]	axi_awlen_m1;		// From axi_interconnect of axi_interconnect.v
	wire [7:0]	axi_awlen_s0;		// From cpu_async_bridge of axi_async_bridge.v
	wire		axi_awready_core;	// From cpu_async_bridge of axi_async_bridge.v
	wire		axi_awready_m0;		// From axi_internal_ram of axi_internal_ram.v
	wire		axi_awready_m1;		// From sdram_controller of sdram_controller.v
	wire		axi_awready_s0;		// From axi_interconnect of axi_interconnect.v
	wire		axi_awvalid_core;	// From gpgpu of gpgpu.v
	wire		axi_awvalid_m0;		// From axi_interconnect of axi_interconnect.v
	wire		axi_awvalid_m1;		// From axi_interconnect of axi_interconnect.v
	wire		axi_awvalid_s0;		// From cpu_async_bridge of axi_async_bridge.v
	wire		axi_bready_core;	// From gpgpu of gpgpu.v
	wire		axi_bready_m0;		// From axi_interconnect of axi_interconnect.v
	wire		axi_bready_m1;		// From axi_interconnect of axi_interconnect.v
	wire		axi_bready_s0;		// From cpu_async_bridge of axi_async_bridge.v
	wire		axi_bvalid_core;	// From cpu_async_bridge of axi_async_bridge.v
	wire		axi_bvalid_m0;		// From axi_internal_ram of axi_internal_ram.v
	wire		axi_bvalid_m1;		// From sdram_controller of sdram_controller.v
	wire		axi_bvalid_s0;		// From axi_interconnect of axi_interconnect.v
	wire [31:0]	axi_rdata_core;		// From cpu_async_bridge of axi_async_bridge.v
	wire [31:0]	axi_rdata_m0;		// From axi_internal_ram of axi_internal_ram.v
	wire [31:0]	axi_rdata_m1;		// From sdram_controller of sdram_controller.v
	wire [31:0]	axi_rdata_s0;		// From axi_interconnect of axi_interconnect.v
	wire [31:0]	axi_rdata_s1;		// From axi_interconnect of axi_interconnect.v
	wire		axi_rready_core;	// From gpgpu of gpgpu.v
	wire		axi_rready_m0;		// From axi_interconnect of axi_interconnect.v
	wire		axi_rready_m1;		// From axi_interconnect of axi_interconnect.v
	wire		axi_rready_s0;		// From cpu_async_bridge of axi_async_bridge.v
	wire		axi_rready_s1;		// From vga_controller of vga_controller.v
	wire		axi_rvalid_core;	// From cpu_async_bridge of axi_async_bridge.v
	wire		axi_rvalid_m0;		// From axi_internal_ram of axi_internal_ram.v
	wire		axi_rvalid_m1;		// From sdram_controller of sdram_controller.v
	wire		axi_rvalid_s0;		// From axi_interconnect of axi_interconnect.v
	wire		axi_rvalid_s1;		// From axi_interconnect of axi_interconnect.v
	wire [31:0]	axi_wdata_core;		// From gpgpu of gpgpu.v
	wire [31:0]	axi_wdata_m0;		// From axi_interconnect of axi_interconnect.v
	wire [31:0]	axi_wdata_m1;		// From axi_interconnect of axi_interconnect.v
	wire [31:0]	axi_wdata_s0;		// From cpu_async_bridge of axi_async_bridge.v
	wire		axi_wlast_core;		// From gpgpu of gpgpu.v
	wire		axi_wlast_m0;		// From axi_interconnect of axi_interconnect.v
	wire		axi_wlast_m1;		// From axi_interconnect of axi_interconnect.v
	wire		axi_wlast_s0;		// From cpu_async_bridge of axi_async_bridge.v
	wire		axi_wready_core;	// From cpu_async_bridge of axi_async_bridge.v
	wire		axi_wready_m0;		// From axi_internal_ram of axi_internal_ram.v
	wire		axi_wready_m1;		// From sdram_controller of sdram_controller.v
	wire		axi_wready_s0;		// From axi_interconnect of axi_interconnect.v
	wire		axi_wvalid_core;	// From gpgpu of gpgpu.v
	wire		axi_wvalid_m0;		// From axi_interconnect of axi_interconnect.v
	wire		axi_wvalid_m1;		// From axi_interconnect of axi_interconnect.v
	wire		axi_wvalid_s0;		// From cpu_async_bridge of axi_async_bridge.v
	wire [31:0]	io_address;		// From gpgpu of gpgpu.v
	wire		io_read_en;		// From gpgpu of gpgpu.v
	wire [31:0]	io_write_data;		// From gpgpu of gpgpu.v
	wire		io_write_en;		// From gpgpu of gpgpu.v
	wire		pc_event_dram_page_hit;	// From sdram_controller of sdram_controller.v
	wire		pc_event_dram_page_miss;// From sdram_controller of sdram_controller.v
	wire		processor_halt;		// From gpgpu of gpgpu.v
	// End of automatics

	wire jtag_reset;
	reg simulator_reset = 0;
	wire global_reset = simulator_reset || jtag_reset;
	wire[31:0] loader_addr;
	wire[31:0] loader_data;
	wire loader_we;
	reg [31:0] io_read_data;
	wire [31:0] uart_read_data;
	reg [31:0] timer_val;

	// There are two clock domains: the memory/bus clock runs at 50 Mhz and the CPU
	// clock runs at 25 Mhz.  It's necessary to run memory that fast to have
	// enough bandwidth to satisfy the VGA controller, but the CPU has an 
	// Fmax of ~30Mhz.  Note that CPU could actually run at a non-integer divisor
	// of the bus clock, since there is a proper bridge.  I may put a PLL here at 
	// some point to allow squeezing a little more performance out, but this is 
	// simplest for now.
	wire mem_clk = clk50;
	wire core_reset;
	reg core_clk = 0;

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
		.\(axi_.*\)(\1_core[]),
		);
	*/
	gpgpu gpgpu(
		/*AUTOINST*/
		    // Outputs
		    .processor_halt	(processor_halt),
		    .axi_awaddr		(axi_awaddr_core[31:0]), // Templated
		    .axi_awlen		(axi_awlen_core[7:0]),	 // Templated
		    .axi_awvalid	(axi_awvalid_core),	 // Templated
		    .axi_wdata		(axi_wdata_core[31:0]),	 // Templated
		    .axi_wlast		(axi_wlast_core),	 // Templated
		    .axi_wvalid		(axi_wvalid_core),	 // Templated
		    .axi_bready		(axi_bready_core),	 // Templated
		    .axi_araddr		(axi_araddr_core[31:0]), // Templated
		    .axi_arlen		(axi_arlen_core[7:0]),	 // Templated
		    .axi_arvalid	(axi_arvalid_core),	 // Templated
		    .axi_rready		(axi_rready_core),	 // Templated
		    .io_write_en	(io_write_en),
		    .io_read_en		(io_read_en),
		    .io_address		(io_address[31:0]),
		    .io_write_data	(io_write_data[31:0]),
		    // Inputs
		    .clk		(core_clk),		 // Templated
		    .reset		(core_reset),		 // Templated
		    .axi_awready	(axi_awready_core),	 // Templated
		    .axi_wready		(axi_wready_core),	 // Templated
		    .axi_bvalid		(axi_bvalid_core),	 // Templated
		    .axi_arready	(axi_arready_core),	 // Templated
		    .axi_rvalid		(axi_rvalid_core),	 // Templated
		    .axi_rdata		(axi_rdata_core[31:0]),	 // Templated
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

	debug_trace #(.CAPTURE_WIDTH_BITS(32), .CAPTURE_SIZE(64)) debug_trace(
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
		.\(axi_.*\)_s(\1_core[]),
		.\(axi_.*\)_m(\1_s0[]),
		);
	*/
	axi_async_bridge #(.ADDR_WIDTH(32), .DATA_WIDTH(32)) cpu_async_bridge(
		/*AUTOINST*/
									      // Outputs
									      .axi_awready_s	(axi_awready_core), // Templated
									      .axi_wready_s	(axi_wready_core), // Templated
									      .axi_bvalid_s	(axi_bvalid_core), // Templated
									      .axi_arready_s	(axi_arready_core), // Templated
									      .axi_rvalid_s	(axi_rvalid_core), // Templated
									      .axi_rdata_s	(axi_rdata_core[31:0]), // Templated
									      .axi_awaddr_m	(axi_awaddr_s0[31:0]), // Templated
									      .axi_awlen_m	(axi_awlen_s0[7:0]), // Templated
									      .axi_awvalid_m	(axi_awvalid_s0), // Templated
									      .axi_wdata_m	(axi_wdata_s0[31:0]), // Templated
									      .axi_wlast_m	(axi_wlast_s0),	 // Templated
									      .axi_wvalid_m	(axi_wvalid_s0), // Templated
									      .axi_bready_m	(axi_bready_s0), // Templated
									      .axi_araddr_m	(axi_araddr_s0[31:0]), // Templated
									      .axi_arlen_m	(axi_arlen_s0[7:0]), // Templated
									      .axi_arvalid_m	(axi_arvalid_s0), // Templated
									      .axi_rready_m	(axi_rready_s0), // Templated
									      // Inputs
									      .reset		(global_reset),	 // Templated
									      .clk_s		(core_clk),	 // Templated
									      .axi_awaddr_s	(axi_awaddr_core[31:0]), // Templated
									      .axi_awlen_s	(axi_awlen_core[7:0]), // Templated
									      .axi_awvalid_s	(axi_awvalid_core), // Templated
									      .axi_wdata_s	(axi_wdata_core[31:0]), // Templated
									      .axi_wlast_s	(axi_wlast_core), // Templated
									      .axi_wvalid_s	(axi_wvalid_core), // Templated
									      .axi_bready_s	(axi_bready_core), // Templated
									      .axi_araddr_s	(axi_araddr_core[31:0]), // Templated
									      .axi_arlen_s	(axi_arlen_core[7:0]), // Templated
									      .axi_arvalid_s	(axi_arvalid_core), // Templated
									      .axi_rready_s	(axi_rready_core), // Templated
									      .clk_m		(mem_clk),	 // Templated
									      .axi_awready_m	(axi_awready_s0), // Templated
									      .axi_wready_m	(axi_wready_s0), // Templated
									      .axi_bvalid_m	(axi_bvalid_s0), // Templated
									      .axi_arready_m	(axi_arready_s0), // Templated
									      .axi_rvalid_m	(axi_rvalid_s0), // Templated
									      .axi_rdata_m	(axi_rdata_s0[31:0])); // Templated
			  			  
	/* axi_interconnect AUTO_TEMPLATE(
		.clk(mem_clk),
		.reset(global_reset));
	*/
	axi_interconnect axi_interconnect(
		/*AUTOINST*/
					  // Outputs
					  .axi_awaddr_m0	(axi_awaddr_m0[31:0]),
					  .axi_awlen_m0		(axi_awlen_m0[7:0]),
					  .axi_awvalid_m0	(axi_awvalid_m0),
					  .axi_wdata_m0		(axi_wdata_m0[31:0]),
					  .axi_wlast_m0		(axi_wlast_m0),
					  .axi_wvalid_m0	(axi_wvalid_m0),
					  .axi_bready_m0	(axi_bready_m0),
					  .axi_araddr_m0	(axi_araddr_m0[31:0]),
					  .axi_arlen_m0		(axi_arlen_m0[7:0]),
					  .axi_arvalid_m0	(axi_arvalid_m0),
					  .axi_rready_m0	(axi_rready_m0),
					  .axi_awaddr_m1	(axi_awaddr_m1[31:0]),
					  .axi_awlen_m1		(axi_awlen_m1[7:0]),
					  .axi_awvalid_m1	(axi_awvalid_m1),
					  .axi_wdata_m1		(axi_wdata_m1[31:0]),
					  .axi_wlast_m1		(axi_wlast_m1),
					  .axi_wvalid_m1	(axi_wvalid_m1),
					  .axi_bready_m1	(axi_bready_m1),
					  .axi_araddr_m1	(axi_araddr_m1[31:0]),
					  .axi_arlen_m1		(axi_arlen_m1[7:0]),
					  .axi_arvalid_m1	(axi_arvalid_m1),
					  .axi_rready_m1	(axi_rready_m1),
					  .axi_awready_s0	(axi_awready_s0),
					  .axi_wready_s0	(axi_wready_s0),
					  .axi_bvalid_s0	(axi_bvalid_s0),
					  .axi_arready_s0	(axi_arready_s0),
					  .axi_rvalid_s0	(axi_rvalid_s0),
					  .axi_rdata_s0		(axi_rdata_s0[31:0]),
					  .axi_arready_s1	(axi_arready_s1),
					  .axi_rvalid_s1	(axi_rvalid_s1),
					  .axi_rdata_s1		(axi_rdata_s1[31:0]),
					  // Inputs
					  .clk			(mem_clk),	 // Templated
					  .reset		(global_reset),	 // Templated
					  .axi_awready_m0	(axi_awready_m0),
					  .axi_wready_m0	(axi_wready_m0),
					  .axi_bvalid_m0	(axi_bvalid_m0),
					  .axi_arready_m0	(axi_arready_m0),
					  .axi_rvalid_m0	(axi_rvalid_m0),
					  .axi_rdata_m0		(axi_rdata_m0[31:0]),
					  .axi_awready_m1	(axi_awready_m1),
					  .axi_wready_m1	(axi_wready_m1),
					  .axi_bvalid_m1	(axi_bvalid_m1),
					  .axi_arready_m1	(axi_arready_m1),
					  .axi_rvalid_m1	(axi_rvalid_m1),
					  .axi_rdata_m1		(axi_rdata_m1[31:0]),
					  .axi_awaddr_s0	(axi_awaddr_s0[31:0]),
					  .axi_awlen_s0		(axi_awlen_s0[7:0]),
					  .axi_awvalid_s0	(axi_awvalid_s0),
					  .axi_wdata_s0		(axi_wdata_s0[31:0]),
					  .axi_wlast_s0		(axi_wlast_s0),
					  .axi_wvalid_s0	(axi_wvalid_s0),
					  .axi_bready_s0	(axi_bready_s0),
					  .axi_araddr_s0	(axi_araddr_s0[31:0]),
					  .axi_arlen_s0		(axi_arlen_s0[7:0]),
					  .axi_arvalid_s0	(axi_arvalid_s0),
					  .axi_rready_s0	(axi_rready_s0),
					  .axi_araddr_s1	(axi_araddr_s1[31:0]),
					  .axi_arlen_s1		(axi_arlen_s1[7:0]),
					  .axi_arvalid_s1	(axi_arvalid_s1),
					  .axi_rready_s1	(axi_rready_s1));
			  
	// Internal SRAM.  The system boots out of this.
	/* axi_internal_ram AUTO_TEMPLATE(
		.clk(mem_clk),
		.reset(global_reset),
		.\(axi_.*\)(\1_m0[]),);
	*/
	axi_internal_ram #(.MEM_SIZE('h800)) axi_internal_ram(
		/*AUTOINST*/
							      // Outputs
							      .axi_awready	(axi_awready_m0), // Templated
							      .axi_wready	(axi_wready_m0), // Templated
							      .axi_bvalid	(axi_bvalid_m0), // Templated
							      .axi_arready	(axi_arready_m0), // Templated
							      .axi_rvalid	(axi_rvalid_m0), // Templated
							      .axi_rdata	(axi_rdata_m0[31:0]), // Templated
							      // Inputs
							      .clk		(mem_clk),	 // Templated
							      .reset		(global_reset),	 // Templated
							      .axi_awaddr	(axi_awaddr_m0[31:0]), // Templated
							      .axi_awlen	(axi_awlen_m0[7:0]), // Templated
							      .axi_awvalid	(axi_awvalid_m0), // Templated
							      .axi_wdata	(axi_wdata_m0[31:0]), // Templated
							      .axi_wlast	(axi_wlast_m0),	 // Templated
							      .axi_wvalid	(axi_wvalid_m0), // Templated
							      .axi_bready	(axi_bready_m0), // Templated
							      .axi_araddr	(axi_araddr_m0[31:0]), // Templated
							      .axi_arlen	(axi_arlen_m0[7:0]), // Templated
							      .axi_arvalid	(axi_arvalid_m0), // Templated
							      .axi_rready	(axi_rready_m0), // Templated
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
		.\(axi_.*\)(\1_m1[]),);
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
				   // Outputs
				   .dram_clk		(dram_clk),
				   .dram_cke		(dram_cke),
				   .dram_cs_n		(dram_cs_n),
				   .dram_ras_n		(dram_ras_n),
				   .dram_cas_n		(dram_cas_n),
				   .dram_we_n		(dram_we_n),
				   .dram_ba		(dram_ba[1:0]),
				   .dram_addr		(dram_addr[12:0]),
				   .axi_awready		(axi_awready_m1), // Templated
				   .axi_wready		(axi_wready_m1), // Templated
				   .axi_bvalid		(axi_bvalid_m1), // Templated
				   .axi_arready		(axi_arready_m1), // Templated
				   .axi_rvalid		(axi_rvalid_m1), // Templated
				   .axi_rdata		(axi_rdata_m1[31:0]), // Templated
				   .pc_event_dram_page_miss(pc_event_dram_page_miss),
				   .pc_event_dram_page_hit(pc_event_dram_page_hit),
				   // Inouts
				   .dram_dq		(dram_dq[31:0]),
				   // Inputs
				   .clk			(mem_clk),	 // Templated
				   .reset		(global_reset),	 // Templated
				   .axi_awaddr		(axi_awaddr_m1[31:0]), // Templated
				   .axi_awlen		(axi_awlen_m1[7:0]), // Templated
				   .axi_awvalid		(axi_awvalid_m1), // Templated
				   .axi_wdata		(axi_wdata_m1[31:0]), // Templated
				   .axi_wlast		(axi_wlast_m1),	 // Templated
				   .axi_wvalid		(axi_wvalid_m1), // Templated
				   .axi_bready		(axi_bready_m1), // Templated
				   .axi_araddr		(axi_araddr_m1[31:0]), // Templated
				   .axi_arlen		(axi_arlen_m1[7:0]), // Templated
				   .axi_arvalid		(axi_arvalid_m1), // Templated
				   .axi_rready		(axi_rready_m1)); // Templated

	/* vga_controller AUTO_TEMPLATE(
		.clk(mem_clk),
		.reset(global_reset),
		.\(axi_.*\)(\1_s1[]),);
	*/
	vga_controller vga_controller(
		/*AUTOINST*/
				      // Outputs
				      .vga_r		(vga_r[7:0]),
				      .vga_g		(vga_g[7:0]),
				      .vga_b		(vga_b[7:0]),
				      .vga_clk		(vga_clk),
				      .vga_blank_n	(vga_blank_n),
				      .vga_hs		(vga_hs),
				      .vga_vs		(vga_vs),
				      .vga_sync_n	(vga_sync_n),
				      .axi_araddr	(axi_araddr_s1[31:0]), // Templated
				      .axi_arlen	(axi_arlen_s1[7:0]), // Templated
				      .axi_arvalid	(axi_arvalid_s1), // Templated
				      .axi_rready	(axi_rready_s1), // Templated
				      // Inputs
				      .clk		(mem_clk),	 // Templated
				      .reset		(global_reset),	 // Templated
				      .axi_arready	(axi_arready_s1), // Templated
				      .axi_rvalid	(axi_rvalid_s1), // Templated
				      .axi_rdata	(axi_rdata_s1[31:0])); // Templated

endmodule

// Local Variables:
// verilog-library-flags:("-y ../core" "-y ../testbench")
// verilog-auto-inst-param-value: t
// End:
