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

`include "defines.v"

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

	assign dram_dqm = 4'b0000;

	/*AUTOWIRE*/
	// Beginning of automatic wires (for undeclared instantiated-module outputs)
	wire [31:0]	axi_araddr_m0;		// From axi_interconnect of axi_interconnect.v
	wire [31:0]	axi_araddr_m1;		// From axi_interconnect of axi_interconnect.v
	wire [7:0]	axi_arlen_m0;		// From axi_interconnect of axi_interconnect.v
	wire [7:0]	axi_arlen_m1;		// From axi_interconnect of axi_interconnect.v
	wire		axi_arready_s0;		// From axi_interconnect of axi_interconnect.v
	wire		axi_arready_s1;		// From axi_interconnect of axi_interconnect.v
	wire		axi_arvalid_m0;		// From axi_interconnect of axi_interconnect.v
	wire		axi_arvalid_m1;		// From axi_interconnect of axi_interconnect.v
	wire [31:0]	axi_awaddr_m0;		// From axi_interconnect of axi_interconnect.v
	wire [31:0]	axi_awaddr_m1;		// From axi_interconnect of axi_interconnect.v
	wire [7:0]	axi_awlen_m0;		// From axi_interconnect of axi_interconnect.v
	wire [7:0]	axi_awlen_m1;		// From axi_interconnect of axi_interconnect.v
	wire		axi_awready_s0;		// From axi_interconnect of axi_interconnect.v
	wire		axi_awvalid_m0;		// From axi_interconnect of axi_interconnect.v
	wire		axi_awvalid_m1;		// From axi_interconnect of axi_interconnect.v
	wire		axi_bready_m0;		// From axi_interconnect of axi_interconnect.v
	wire		axi_bready_m1;		// From axi_interconnect of axi_interconnect.v
	wire		axi_bvalid_s0;		// From axi_interconnect of axi_interconnect.v
	wire [31:0]	axi_rdata_s0;		// From axi_interconnect of axi_interconnect.v
	wire [31:0]	axi_rdata_s1;		// From axi_interconnect of axi_interconnect.v
	wire		axi_rready_m0;		// From axi_interconnect of axi_interconnect.v
	wire		axi_rready_m1;		// From axi_interconnect of axi_interconnect.v
	wire		axi_rvalid_s0;		// From axi_interconnect of axi_interconnect.v
	wire		axi_rvalid_s1;		// From axi_interconnect of axi_interconnect.v
	wire [31:0]	axi_wdata_m0;		// From axi_interconnect of axi_interconnect.v
	wire [31:0]	axi_wdata_m1;		// From axi_interconnect of axi_interconnect.v
	wire		axi_wlast_m0;		// From axi_interconnect of axi_interconnect.v
	wire		axi_wlast_m1;		// From axi_interconnect of axi_interconnect.v
	wire		axi_wready_s0;		// From axi_interconnect of axi_interconnect.v
	wire		axi_wvalid_m0;		// From axi_interconnect of axi_interconnect.v
	wire		axi_wvalid_m1;		// From axi_interconnect of axi_interconnect.v
	wire [31:0]	io_address;		// From gpgpu of gpgpu.v
	wire		io_read_en;		// From gpgpu of gpgpu.v
	wire [31:0]	io_write_data;		// From gpgpu of gpgpu.v
	wire		io_write_en;		// From gpgpu of gpgpu.v
	wire		pc_event_dram_page_hit;	// From sdram_controller of sdram_controller.v
	wire		pc_event_dram_page_miss;// From sdram_controller of sdram_controller.v
	wire		processor_halt;		// From gpgpu of gpgpu.v
	// End of automatics

	wire axi_awready_m0;
	wire axi_wready_m0;
	wire axi_bvalid_m0; 
	wire axi_arready_m0;
	wire axi_rvalid_m0;     
	wire [31:0] axi_rdata_m0;
	wire axi_awready_m1;
	wire axi_wready_m1;
	wire axi_bvalid_m1; 
	wire axi_arready_m1;
	wire axi_rvalid_m1;     
	wire [31:0] axi_rdata_m1;
	wire [31:0] axi_awaddr_s0;
	wire [7:0] axi_awlen_s0;
	wire axi_awvalid_s0;
	wire [31:0] axi_wdata_s0;
	wire axi_wlast_s0;
	wire axi_wvalid_s0;
	wire axi_bready_s0;
	wire [31:0] axi_araddr_s0;
	wire [7:0] axi_arlen_s0;
	wire axi_arvalid_s0;
	wire axi_rready_s0;
	wire [31:0] axi_awaddr_core;
	wire [7:0] axi_awlen_core;
	wire axi_awvalid_core;
	wire axi_awready_core;
	wire [31:0] axi_wdata_core; 
	wire axi_wlast_core;
	wire axi_wvalid_core;
	wire axi_wready_core;
	wire axi_bvalid_core; 
	wire axi_bready_core;
	wire [31:0] axi_araddr_core; 
	wire [7:0] axi_arlen_core;
	wire axi_arvalid_core;
	wire axi_arready_core;
	wire axi_rready_core;  
	wire axi_rvalid_core;         
	wire [31:0] axi_rdata_core;
	wire reset;
	wire[31:0] loader_addr;
	wire[31:0] loader_data;
	wire loader_we;
	reg [31:0] io_read_data;
	wire axi_arvalid_s1;
	wire axi_rready_s1;	
	wire [31:0] axi_araddr_s1;
	wire [7:0] axi_arlen_s1;
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
	reg core_clk = 0;
	always @(posedge clk50)
		core_clk = !core_clk;	// Divide core_clock down

	// Reset synchronizer for CPU. Reset is asserted asynchronously and 
	// deasserted synchronously.
	reg core_reset;
	always @(posedge core_clk, posedge reset)
	begin
		if (reset)
			core_reset <= 1'b1;
		else
			core_reset <= 1'b0;
	end

	gpgpu gpgpu(
		.reset(reset),
		.clk(core_clk),
		.axi_awaddr(axi_awaddr_core),
		.axi_awlen(axi_awlen_core),
		.axi_awvalid(axi_awvalid_core),
		.axi_wdata(axi_wdata_core),
		.axi_wlast(axi_wlast_core),
		.axi_wvalid(axi_wvalid_core),
		.axi_bready(axi_bready_core),
		.axi_araddr(axi_araddr_core),
		.axi_arlen(axi_arlen_core),
		.axi_arvalid(axi_arvalid_core),
		.axi_rready(axi_rready_core),
		.axi_awready(axi_awready_core),
		.axi_wready(axi_wready_core),
		.axi_bvalid(axi_bvalid_core),
		.axi_arready(axi_arready_core),
		.axi_rvalid(axi_rvalid_core),
		.axi_rdata(axi_rdata_core),
		/*AUTOINST*/
		    // Outputs
		    .processor_halt	(processor_halt),
		    .io_write_en	(io_write_en),
		    .io_read_en		(io_read_en),
		    .io_address		(io_address[31:0]),
		    .io_write_data	(io_write_data[31:0]),
		    // Inputs
		    .io_read_data	(io_read_data[31:0]));

	always @(posedge core_clk, posedge core_reset)
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
	
	always @*
	begin
		case (io_address)
			'h18, 'h1c: io_read_data = uart_read_data;
			'h24: io_read_data = timer_val;
			default: io_read_data = 0;
		endcase
	end
	
	uart #(.BASE_ADDRESS(24), .BAUD_DIVIDE(27)) uart(
		.rx(uart_rx),
		.tx(uart_tx),
		.clk(core_clk),
		.reset(core_reset),
		.io_read_data(uart_read_data),
		/*AUTOINST*/
							 // Inputs
							 .io_address		(io_address[31:0]),
							 .io_read_en		(io_read_en),
							 .io_write_data		(io_write_data[31:0]),
							 .io_write_en		(io_write_en));
	
	// Bridge signals from core clock domain to memory clock domain.
	axi_async_bridge cpu_async_bridge(
		.reset(reset),
		.clk_s(core_clk),
		.axi_awaddr_s(axi_awaddr_core), 
		.axi_awlen_s(axi_awlen_core),
		.axi_awvalid_s(axi_awvalid_core),
		.axi_awready_s(axi_awready_core),
		.axi_wdata_s(axi_wdata_core),  
		.axi_wlast_s(axi_wlast_core),
		.axi_wvalid_s(axi_wvalid_core),
		.axi_wready_s(axi_wready_core),
		.axi_bvalid_s(axi_bvalid_core), 
		.axi_bready_s(axi_bready_core),
		.axi_araddr_s(axi_araddr_core), 
		.axi_arlen_s(axi_arlen_core),
		.axi_arvalid_s(axi_arvalid_core),
		.axi_arready_s(axi_arready_core),
		.axi_rready_s(axi_rready_core), 
		.axi_rvalid_s(axi_rvalid_core), 
		.axi_rdata_s(axi_rdata_core),
		.clk_m(mem_clk),
		.axi_awaddr_m(axi_awaddr_s0), 
		.axi_awlen_m(axi_awlen_s0),
		.axi_awvalid_m(axi_awvalid_s0),
		.axi_awready_m(axi_awready_s0),
		.axi_wdata_m(axi_wdata_s0),  
		.axi_wlast_m(axi_wlast_s0),
		.axi_wvalid_m(axi_wvalid_s0),
		.axi_wready_m(axi_wready_s0),
		.axi_bvalid_m(axi_bvalid_s0), 
		.axi_bready_m(axi_bready_s0),
		.axi_araddr_m(axi_araddr_s0), 
		.axi_arlen_m(axi_arlen_s0),
		.axi_arvalid_m(axi_arvalid_s0),
		.axi_arready_m(axi_arready_s0),
		.axi_rready_m(axi_rready_s0), 
		.axi_rvalid_m(axi_rvalid_s0), 
		.axi_rdata_m(axi_rdata_s0));
			  			  
	axi_interconnect axi_interconnect(
		.clk(mem_clk),
		.reset(reset),
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
			  
	// Internal SRAM
	axi_internal_ram #(.MEM_SIZE('h800)) axi_internal_ram(
		.clk(mem_clk),
		.reset(reset),
		.axi_awaddr(axi_awaddr_m0), 
		.axi_awlen(axi_awlen_m0),
		.axi_awvalid(axi_awvalid_m0),
		.axi_awready(axi_awready_m0),
		.axi_wdata(axi_wdata_m0),  
		.axi_wlast(axi_wlast_m0),
		.axi_wvalid(axi_wvalid_m0),
		.axi_wready(axi_wready_m0),
		.axi_bvalid(axi_bvalid_m0), 
		.axi_bready(axi_bready_m0),
		.axi_araddr(axi_araddr_m0),
		.axi_arlen(axi_arlen_m0),
		.axi_arvalid(axi_arvalid_m0),
		.axi_arready(axi_arready_m0),
		.axi_rready(axi_rready_m0),
		.axi_rvalid(axi_rvalid_m0),      
		.axi_rdata(axi_rdata_m0),
		.loader_we(loader_we),
		.loader_addr(loader_addr),
		.loader_data(loader_data));

	sdram_controller #(
			.DATA_WIDTH(32), 
			.ROW_ADDR_WIDTH(13), 
			.COL_ADDR_WIDTH(10),
			.T_REFRESH(390)	// 64 ms / 8192 rows = 7.8125 uS @ 50 Mhz 
		) sdram_controller(
		.clk(mem_clk),
		.reset(reset),
		.axi_awaddr(axi_awaddr_m1), 
		.axi_awlen(axi_awlen_m1),
		.axi_awvalid(axi_awvalid_m1),
		.axi_awready(axi_awready_m1),
		.axi_wdata(axi_wdata_m1),  
		.axi_wlast(axi_wlast_m1),
		.axi_wvalid(axi_wvalid_m1),
		.axi_wready(axi_wready_m1),
		.axi_bvalid(axi_bvalid_m1), 
		.axi_bready(axi_bready_m1),
		.axi_araddr(axi_araddr_m1),
		.axi_arlen(axi_arlen_m1),
		.axi_arvalid(axi_arvalid_m1),
		.axi_arready(axi_arready_m1),
		.axi_rready(axi_rready_m1),
		.axi_rvalid(axi_rvalid_m1),      
		.axi_rdata(axi_rdata_m1),
		.dqmh(),
		.dqml(),
		 .dram_clk(dram_clk),
		 .cke(dram_cke),
		 .cs_n(dram_cs_n),
		 .ras_n(dram_ras_n),
		 .cas_n(dram_cas_n),
		 .we_n(dram_we_n),
		 .ba(dram_ba),
		 .addr(dram_addr),
		 .dq(dram_dq),
		/*AUTOINST*/
				   // Outputs
				   .pc_event_dram_page_miss(pc_event_dram_page_miss),
				   .pc_event_dram_page_hit(pc_event_dram_page_hit));

	vga_controller vga_controller(
		.clk(mem_clk),
		.axi_araddr(axi_araddr_s1),
		.axi_arlen(axi_arlen_s1),
		.axi_arvalid(axi_arvalid_s1),
		.axi_arready(axi_arready_s1),
		.axi_rready(axi_rready_s1), 
		.axi_rvalid(axi_rvalid_s1),         
		.axi_rdata(axi_rdata_s1),	
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
				      // Inputs
				      .reset		(reset));

	jtagloader jtagloader(
		.we(loader_we),
		.addr(loader_addr),
		.data(loader_data),
		.reset(reset),
		.clk(mem_clk));

endmodule

// Local Variables:
// verilog-library-flags:("-y ../core" "-y ../testbench")
// verilog-auto-inst-param-value: t
// End:
