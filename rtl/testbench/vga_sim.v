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

//
// Simulates just the VGA controller and a piece of memory without the CPU
// or anything else.  It takes many cycles to output a single VGA frame, 
// which takes a long time with all of that other stuff simulated. This is much 
// faster.
//

module vga_sim;

	reg clk = 0;
	reg reset = 0;
	
	/*AUTOWIRE*/
	// Beginning of automatic wires (for undeclared instantiated-module outputs)
	wire [31:0]	axi_araddr;		// From vga_controller of vga_controller.v
	wire [7:0]	axi_arlen;		// From vga_controller of vga_controller.v
	wire		axi_arready;		// From internal_ram of axi_internal_ram.v
	wire		axi_arvalid;		// From vga_controller of vga_controller.v
	wire		axi_awready;		// From internal_ram of axi_internal_ram.v
	wire		axi_bvalid;		// From internal_ram of axi_internal_ram.v
	wire [31:0]	axi_rdata;		// From internal_ram of axi_internal_ram.v
	wire		axi_rready;		// From vga_controller of vga_controller.v
	wire		axi_rvalid;		// From internal_ram of axi_internal_ram.v
	wire		axi_wready;		// From internal_ram of axi_internal_ram.v
	wire [7:0]	vga_b;			// From vga_controller of vga_controller.v
	wire		vga_blank_n;		// From vga_controller of vga_controller.v
	wire		vga_clk;		// From vga_controller of vga_controller.v
	wire [7:0]	vga_g;			// From vga_controller of vga_controller.v
	wire		vga_hs;			// From vga_controller of vga_controller.v
	wire [7:0]	vga_r;			// From vga_controller of vga_controller.v
	wire		vga_sync_n;		// From vga_controller of vga_controller.v
	wire		vga_vs;			// From vga_controller of vga_controller.v
	// End of automatics

	wire axi_awvalid = 0;
	wire axi_wvalid = 0;
	wire axi_bready = 0;
	wire axi_wlast = 0;
	wire[31:0] axi_awaddr = 0;
	wire[31:0] axi_wdata = 0;
	wire[7:0] axi_awlen = 0;
	wire loader_we = 0;
	wire[31:0] loader_addr = 0;
	wire[31:0] loader_data = 0;

	vga_controller vga_controller(/*AUTOINST*/
				      // Outputs
				      .vga_r		(vga_r[7:0]),
				      .vga_g		(vga_g[7:0]),
				      .vga_b		(vga_b[7:0]),
				      .vga_clk		(vga_clk),
				      .vga_blank_n	(vga_blank_n),
				      .vga_hs		(vga_hs),
				      .vga_vs		(vga_vs),
				      .vga_sync_n	(vga_sync_n),
				      .axi_araddr	(axi_araddr[31:0]),
				      .axi_arlen	(axi_arlen[7:0]),
				      .axi_arvalid	(axi_arvalid),
				      .axi_rready	(axi_rready),
				      // Inputs
				      .clk		(clk),
				      .reset		(reset),
				      .axi_arready	(axi_arready),
				      .axi_rvalid	(axi_rvalid),
				      .axi_rdata	(axi_rdata[31:0]));

	axi_internal_ram #(.MEM_SIZE('h12c000)) internal_ram(
				      .axi_araddr	(axi_araddr - 32'h10000000),
					/*AUTOINST*/
				      // Outputs
				      .axi_awready	(axi_awready),
				      .axi_wready	(axi_wready),
				      .axi_bvalid	(axi_bvalid),
				      .axi_arready	(axi_arready),
				      .axi_rvalid	(axi_rvalid),
				      .axi_rdata	(axi_rdata[31:0]),
				      // Inputs
				      .clk		(clk),
				      .reset		(reset),
				      .axi_awaddr	(axi_awaddr[31:0]),
				      .axi_awlen	(axi_awlen[7:0]),
				      .axi_awvalid	(axi_awvalid),
				      .axi_wdata	(axi_wdata[31:0]),
				      .axi_wlast	(axi_wlast),
				      .axi_wvalid	(axi_wvalid),
				      .axi_bready	(axi_bready),
				      .axi_arlen	(axi_arlen[7:0]),
				      .axi_arvalid	(axi_arvalid),
				      .axi_rready	(axi_rready),
				      .loader_we	(loader_we),
				      .loader_addr	(loader_addr[31:0]),
				      .loader_data	(loader_data[31:0]));

	integer i;
	
	initial
	begin
		$dumpfile("trace.lxt");
		$dumpvars;

		internal_ram.memory.data[0] = 32'h55555555;
		internal_ram.memory.data[1] = 32'hcccccccc;
		internal_ram.memory.data[640] = 32'haaaaaaaa;
		internal_ram.memory.data[641] = 32'h33333333;

		#5 reset = 1;
		#5 reset = 0;
		for (i = 0; i < 840000; i = i + 1)
		begin
			#5 clk = 0;
			#5 clk = 1;
		end
	end
endmodule

// Local Variables:
// verilog-library-flags:("-y ../core" "-y ../fpga")
// verilog-auto-inst-param-value: t
// End:
