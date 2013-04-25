// 
// Copyright 2011-2012 Jeff Bush
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

module fpga_top(
	input						clk50,
	
	// VGA interface
	output						vga_clk,
	output						vga_blank_n,
	output						vga_sync_n,
	output						vga_hs,
	output						vga_vs,
	output[7:0]					vga_r,
	output[7:0]					vga_g,
	output[7:0]					vga_b,
	
	// SDRAM interface
	output						dram_clk,
	output 						cke, 
	output 						cs_n, 
	output 						ras_n, 
	output 						cas_n, 
	output 						we_n,
	output reg[1:0]				ba,
	output reg[11:0] 			addr,
	output						dqmh,
	output						dqml,
	inout [DATA_WIDTH - 1:0]	dq);
	
	/*AUTOWIRE*/
	// Beginning of automatic wires (for undeclared instantiated-module outputs)
	wire [31:0]	axi_araddr;		// From l2_cache of l2_cache.v
	wire [7:0]	axi_arlen;		// From l2_cache of l2_cache.v
	wire		axi_arready;		// From sdram_controller of sdram_controller.v
	wire		axi_arvalid;		// From l2_cache of l2_cache.v
	wire [31:0]	axi_awaddr;		// From l2_cache of l2_cache.v
	wire [7:0]	axi_awlen;		// From l2_cache of l2_cache.v
	wire		axi_awready;		// From sdram_controller of sdram_controller.v
	wire		axi_awvalid;		// From l2_cache of l2_cache.v
	wire		axi_bready;		// From l2_cache of l2_cache.v
	wire		axi_bvalid;		// From sdram_controller of sdram_controller.v
	wire [31:0]	axi_rdata;		// From sdram_controller of sdram_controller.v
	wire		axi_rready;		// From l2_cache of l2_cache.v
	wire		axi_rvalid;		// From sdram_controller of sdram_controller.v
	wire [31:0]	axi_wdata;		// From l2_cache of l2_cache.v
	wire		axi_wlast;		// From l2_cache of l2_cache.v
	wire		axi_wready;		// From sdram_controller of sdram_controller.v
	wire		axi_wvalid;		// From l2_cache of l2_cache.v
	wire		halt_o;			// From core of core.v
	wire [10:0]	horizontal_counter;	// From timing_generator of vga_timing_generator.v
	wire [31:0]	io_address;		// From core of core.v
	wire		io_read_en;		// From core of core.v
	wire [31:0]	io_write_data;		// From core of core.v
	wire		io_write_en;		// From core of core.v
	wire [25:0]	l2req_address;		// From core of core.v
	wire [511:0]	l2req_data;		// From core of core.v
	wire [63:0]	l2req_mask;		// From core of core.v
	wire [2:0]	l2req_op;		// From core of core.v
	wire		l2req_ready;		// From l2_cache of l2_cache.v
	wire [1:0]	l2req_strand;		// From core of core.v
	wire [1:0]	l2req_unit;		// From core of core.v
	wire		l2req_valid;		// From core of core.v
	wire [1:0]	l2req_way;		// From core of core.v
	wire [25:0]	l2rsp_address;		// From l2_cache of l2_cache.v
	wire [`CORE_INDEX_WIDTH-1:0] l2rsp_core;// From l2_cache of l2_cache.v
	wire [511:0]	l2rsp_data;		// From l2_cache of l2_cache.v
	wire [1:0]	l2rsp_op;		// From l2_cache of l2_cache.v
	wire		l2rsp_status;		// From l2_cache of l2_cache.v
	wire [1:0]	l2rsp_strand;		// From l2_cache of l2_cache.v
	wire [1:0]	l2rsp_unit;		// From l2_cache of l2_cache.v
	wire [`NUM_CORES-1:0] l2rsp_update;	// From l2_cache of l2_cache.v
	wire		l2rsp_valid;		// From l2_cache of l2_cache.v
	wire [`NUM_CORES*2-1:0] l2rsp_way;	// From l2_cache of l2_cache.v
	wire		pc_event_cond_branch_not_taken;// From core of core.v
	wire		pc_event_cond_branch_taken;// From core of core.v
	wire [3:0]	pc_event_dcache_wait;	// From core of core.v
	wire		pc_event_dram_page_hit;	// From sdram_controller of sdram_controller.v
	wire		pc_event_dram_page_miss;// From sdram_controller of sdram_controller.v
	wire [3:0]	pc_event_icache_wait;	// From core of core.v
	wire		pc_event_instruction_issue;// From core of core.v
	wire		pc_event_instruction_retire;// From core of core.v
	wire		pc_event_l1d_collided_load;// From core of core.v
	wire		pc_event_l1d_hit;	// From core of core.v
	wire		pc_event_l1d_miss;	// From core of core.v
	wire		pc_event_l1i_collided_load;// From core of core.v
	wire		pc_event_l1i_hit;	// From core of core.v
	wire		pc_event_l1i_miss;	// From core of core.v
	wire		pc_event_l2_hit;	// From l2_cache of l2_cache.v
	wire		pc_event_l2_miss;	// From l2_cache of l2_cache.v
	wire		pc_event_mispredicted_branch;// From core of core.v
	wire [3:0]	pc_event_raw_wait;	// From core of core.v
	wire		pc_event_store;		// From l2_cache of l2_cache.v
	wire		pc_event_uncond_branch;	// From core of core.v
	wire [10:0]	vertical_counter;	// From timing_generator of vga_timing_generator.v
	// End of automatics


	reg clk = 0;
	wire[31:0] display_address;

	always @(posedge clk50)
		clk = ~clk;		// Divide down to 25 Mhz

	// Asynchronous reset. Wait some number of cycles for everything to settle,
	// then release reset at the clock edge so the logic will be ready for 
	// normal operation at the next clock edge.
	reg reset = 1'b1;	
	reg[7:0] reset_count = 100;

	always @(posedge clk)
	begin
		if (reset_count == 0)
			reset <= 0;
		else
			reset_count <= reset_count - 1;
	end

	wire [31:0] io_read_data = 0;
	
	core core(/*AUTOINST*/
		  // Outputs
		  .halt_o		(halt_o),
		  .io_write_en		(io_write_en),
		  .io_read_en		(io_read_en),
		  .io_address		(io_address[31:0]),
		  .io_write_data	(io_write_data[31:0]),
		  .l2req_valid		(l2req_valid),
		  .l2req_strand		(l2req_strand[1:0]),
		  .l2req_unit		(l2req_unit[1:0]),
		  .l2req_op		(l2req_op[2:0]),
		  .l2req_way		(l2req_way[1:0]),
		  .l2req_address	(l2req_address[25:0]),
		  .l2req_data		(l2req_data[511:0]),
		  .l2req_mask		(l2req_mask[63:0]),
		  .pc_event_raw_wait	(pc_event_raw_wait[3:0]),
		  .pc_event_dcache_wait	(pc_event_dcache_wait[3:0]),
		  .pc_event_icache_wait	(pc_event_icache_wait[3:0]),
		  .pc_event_l1d_hit	(pc_event_l1d_hit),
		  .pc_event_l1d_miss	(pc_event_l1d_miss),
		  .pc_event_l1d_collided_load(pc_event_l1d_collided_load),
		  .pc_event_l1i_hit	(pc_event_l1i_hit),
		  .pc_event_l1i_miss	(pc_event_l1i_miss),
		  .pc_event_l1i_collided_load(pc_event_l1i_collided_load),
		  .pc_event_mispredicted_branch(pc_event_mispredicted_branch),
		  .pc_event_instruction_issue(pc_event_instruction_issue),
		  .pc_event_instruction_retire(pc_event_instruction_retire),
		  .pc_event_uncond_branch(pc_event_uncond_branch),
		  .pc_event_cond_branch_taken(pc_event_cond_branch_taken),
		  .pc_event_cond_branch_not_taken(pc_event_cond_branch_not_taken),
		  // Inputs
		  .clk			(clk),
		  .reset		(reset),
		  .io_read_data		(io_read_data[31:0]),
		  .l2req_ready		(l2req_ready),
		  .l2rsp_valid		(l2rsp_valid),
		  .l2rsp_core		(l2rsp_core[`CORE_INDEX_WIDTH-1:0]),
		  .l2rsp_status		(l2rsp_status),
		  .l2rsp_unit		(l2rsp_unit[1:0]),
		  .l2rsp_strand		(l2rsp_strand[1:0]),
		  .l2rsp_op		(l2rsp_op[1:0]),
		  .l2rsp_update		(l2rsp_update),
		  .l2rsp_address	(l2rsp_address[25:0]),
		  .l2rsp_way		(l2rsp_way[1:0]),
		  .l2rsp_data		(l2rsp_data[511:0]));
	
	l2_cache l2_cache(/*AUTOINST*/
			  // Outputs
			  .l2req_ready		(l2req_ready),
			  .l2rsp_valid		(l2rsp_valid),
			  .l2rsp_core		(l2rsp_core[`CORE_INDEX_WIDTH-1:0]),
			  .l2rsp_status		(l2rsp_status),
			  .l2rsp_unit		(l2rsp_unit[1:0]),
			  .l2rsp_strand		(l2rsp_strand[1:0]),
			  .l2rsp_op		(l2rsp_op[1:0]),
			  .l2rsp_update		(l2rsp_update[`NUM_CORES-1:0]),
			  .l2rsp_way		(l2rsp_way[`NUM_CORES*2-1:0]),
			  .l2rsp_address	(l2rsp_address[25:0]),
			  .l2rsp_data		(l2rsp_data[511:0]),
			  .axi_awaddr		(axi_awaddr[31:0]),
			  .axi_awlen		(axi_awlen[7:0]),
			  .axi_awvalid		(axi_awvalid),
			  .axi_wdata		(axi_wdata[31:0]),
			  .axi_wlast		(axi_wlast),
			  .axi_wvalid		(axi_wvalid),
			  .axi_bready		(axi_bready),
			  .axi_araddr		(axi_araddr[31:0]),
			  .axi_arlen		(axi_arlen[7:0]),
			  .axi_arvalid		(axi_arvalid),
			  .axi_rready		(axi_rready),
			  .pc_event_l2_hit	(pc_event_l2_hit),
			  .pc_event_l2_miss	(pc_event_l2_miss),
			  .pc_event_store	(pc_event_store),
			  // Inputs
			  .clk			(clk),
			  .reset		(reset),
			  .l2req_valid		(l2req_valid),
			  .l2req_core		(l2req_core[`CORE_INDEX_WIDTH-1:0]),
			  .l2req_unit		(l2req_unit[1:0]),
			  .l2req_strand		(l2req_strand[1:0]),
			  .l2req_op		(l2req_op[2:0]),
			  .l2req_way		(l2req_way[1:0]),
			  .l2req_address	(l2req_address[25:0]),
			  .l2req_data		(l2req_data[511:0]),
			  .l2req_mask		(l2req_mask[63:0]),
			  .axi_awready		(axi_awready),
			  .axi_wready		(axi_wready),
			  .axi_bvalid		(axi_bvalid),
			  .axi_arready		(axi_arready),
			  .axi_rvalid		(axi_rvalid),
			  .axi_rdata		(axi_rdata[31:0]));
	
	sdram_controller sdram_controller(/*AUTOINST*/
					  // Outputs
					  .dram_clk		(dram_clk),
					  .cke			(cke),
					  .cs_n			(cs_n),
					  .ras_n		(ras_n),
					  .cas_n		(cas_n),
					  .we_n			(we_n),
					  .ba			(ba[1:0]),
					  .addr			(addr[11:0]),
					  .dqmh			(dqmh),
					  .dqml			(dqml),
					  .axi_awready		(axi_awready),
					  .axi_wready		(axi_wready),
					  .axi_bvalid		(axi_bvalid),
					  .axi_arready		(axi_arready),
					  .axi_rvalid		(axi_rvalid),
					  .axi_rdata		(axi_rdata[31:0]),
					  .pc_event_dram_page_miss(pc_event_dram_page_miss),
					  .pc_event_dram_page_hit(pc_event_dram_page_hit),
					  // Inouts
					  .dq			(dq[DATA_WIDTH-1:0]),
					  // Inputs
					  .clk			(clk),
					  .reset		(reset),
					  .axi_awaddr		(axi_awaddr[31:0]),
					  .axi_awlen		(axi_awlen[7:0]),
					  .axi_awvalid		(axi_awvalid),
					  .axi_wdata		(axi_wdata[31:0]),
					  .axi_wlast		(axi_wlast),
					  .axi_wvalid		(axi_wvalid),
					  .axi_bready		(axi_bready),
					  .axi_araddr		(axi_araddr[31:0]),
					  .axi_arlen		(axi_arlen[7:0]),
					  .axi_arvalid		(axi_arvalid),
					  .axi_rready		(axi_rready));

	// XXX display_data and display_address currently unconnected.  Need to
	// arbitrate for SDRAM.

	vga_timing_generator timing_generator(/*AUTOINST*/
					      // Outputs
					      .vga_vs		(vga_vs),
					      .vga_hs		(vga_hs),
					      .vga_blank_n	(vga_blank_n),
					      .horizontal_counter(horizontal_counter[10:0]),
					      .vertical_counter	(vertical_counter[10:0]),
					      .vga_sync_n	(vga_sync_n),
					      // Inputs
					      .clk		(clk));

	assign vga_clk = clk;
	assign { vga_b, vga_g, vga_r } = display_data[31:8];	// BGRA
	assign display_address = { horizontal_counter[10:8], vertical_counter[10:8] };
endmodule

// Local Variables:
// verilog-library-flags:("-y ../core" "-y ../testbench")
// End:
