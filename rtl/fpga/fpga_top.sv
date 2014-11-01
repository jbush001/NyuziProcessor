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


`include "defines.sv"

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

	logic fb_base_update_en;
	logic [31:0] fb_new_base;
	logic frame_toggle;

	/*AUTOWIRE*/
	// Beginning of automatic wires (for undeclared instantiated-module outputs)
	scalar_t	io_address;		// From nyuzi of nyuzi.v
	wire		io_read_en;		// From nyuzi of nyuzi.v
	scalar_t	io_write_data;		// From nyuzi of nyuzi.v
	wire		io_write_en;		// From nyuzi of nyuzi.v
	logic		pc_event_dram_page_hit;	// From sdram_controller of sdram_controller.v
	logic		pc_event_dram_page_miss;// From sdram_controller of sdram_controller.v
	wire		processor_halt;		// From nyuzi of nyuzi.v
	// End of automatics

	axi_interface axi_bus_m0();
	axi_interface axi_bus_m1();
	axi_interface axi_bus_s0();
	axi_interface axi_bus_s1();
	logic reset;
	wire[31:0] loader_addr;
	wire[31:0] loader_data;
	wire loader_we;
	logic clk;
	scalar_t io_read_data;
	scalar_t uart_read_data;
	
	assign clk = clk50;

	/* nyuzi AUTO_TEMPLATE(
		.axi_bus(axi_bus_s0[]),
		);
	*/
	nyuzi nyuzi(
			.interrupt_req(0),
		/*AUTOINST*/
		    // Interfaces
		    .axi_bus		(axi_bus_s0),		 // Templated
		    // Outputs
		    .processor_halt	(processor_halt),
		    .io_write_en	(io_write_en),
		    .io_read_en		(io_read_en),
		    .io_address		(io_address),
		    .io_write_data	(io_write_data),
		    // Inputs
		    .clk		(clk),
		    .reset		(reset),
		    .io_read_data	(io_read_data));
	
	axi_interconnect axi_interconnect(
		/*AUTOINST*/
					  // Interfaces
					  .axi_bus_m0		(axi_bus_m0.master),
					  .axi_bus_m1		(axi_bus_m1.master),
					  .axi_bus_s0		(axi_bus_s0.slave),
					  .axi_bus_s1		(axi_bus_s1.slave),
					  // Inputs
					  .clk			(clk),
					  .reset		(reset));
			  
	// Internal SRAM.  The system boots out of this.
	/* axi_internal_ram AUTO_TEMPLATE(
		.axi_bus(axi_bus_m0),);
	*/
	axi_internal_ram #(.MEM_SIZE('h800)) axi_internal_ram(
		/*AUTOINST*/
							      // Interfaces
							      .axi_bus		(axi_bus_m0),	 // Templated
							      // Inputs
							      .clk		(clk),
							      .reset		(reset),
							      .loader_we	(loader_we),
							      .loader_addr	(loader_addr[31:0]),
							      .loader_data	(loader_data[31:0]));

	// This module loads data over JTAG into axi_internal_ram and resets
	// the core.
	jtagloader jtagloader(
		.we(loader_we),
		.addr(loader_addr),
		.data(loader_data),
		.reset(reset),
		.clk(clk));
		
	/* sdram_controller AUTO_TEMPLATE(
		.clk(clk),
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
				   .clk			(clk),		 // Templated
				   .reset		(reset));

	vga_controller vga_controller(
	      .axi_bus(axi_bus_s1),
		  .*);

`ifdef DEBUG_TRACE
	logic[87:0] capture_data;
	logic capture_enable;
	logic trigger;
	logic[31:0] event_count;
	
	assign capture_data = {};
	assign capture_enable = 1;
	assign trigger = event_count == 120;

	debug_trace #(.CAPTURE_WIDTH_BITS($bits(capture_data)), 
		.CAPTURE_SIZE(128),
		.BAUD_DIVIDE(50000000 / 115200)) debug_trace(.*);

	always_ff @(posedge clk, posedge reset)
	begin
		if (reset)
			event_count <= 0;
		else if (capture_enable)
			event_count <= event_count + 1;
	end
`else	
	uart #(.BASE_ADDRESS(24), .BAUD_DIVIDE(50000000 / (115200 * 8))) uart(
		.io_read_data(uart_read_data),
		.*);
`endif

	assign fb_new_base = io_write_data;
	assign fb_base_update_en = io_write_en && io_address == 'h28;
					  
	always_ff @(posedge clk, posedge reset)
	begin
		if (reset)
		begin
			red_led <= 0;
			green_led <= 0;
			hex0 <= 7'b1111111;
			hex1 <= 7'b1111111;
			hex2 <= 7'b1111111;
			hex3 <= 7'b1111111;
		end
		else
		begin
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

	always_ff @(posedge clk)
	begin
		case (io_address)
			'h18, 'h1c: io_read_data <= uart_read_data;
			'h2c: io_read_data <= frame_toggle;
			default: io_read_data <= 0;
		endcase
	end
endmodule

// Local Variables:
// verilog-library-flags:("-y ../core" "-y ../testbench")
// verilog-auto-inst-param-value: t
// End:
