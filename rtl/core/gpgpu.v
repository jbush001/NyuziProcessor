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

//
// Top level block for GPGPU
//

module gpgpu(
	input 					clk,
	input					reset,
	output					processor_halt,

	// AXI external memory interface
	output [31:0]			axi_awaddr, 
	output [7:0]			axi_awlen,
	output 					axi_awvalid,
	input					axi_awready,
	output [31:0]			axi_wdata,
	output					axi_wlast,
	output 					axi_wvalid,
	input					axi_wready,
	input					axi_bvalid,
	output					axi_bready,
	output [31:0]			axi_araddr,
	output [7:0]			axi_arlen,
	output 					axi_arvalid,
	input					axi_arready,
	output 					axi_rready, 
	input					axi_rvalid,         
	input [31:0]			axi_rdata,
	
	// Non-cacheable memory signals
	output					io_write_en,
	output					io_read_en,
	output[31:0]			io_address,
	output[31:0]			io_write_data,
	input [31:0]			io_read_data);

	assign processor_halt = halt0 && halt1;

	/*AUTOWIRE*/
	// Beginning of automatic wires (for undeclared instantiated-module outputs)
	wire [25:0]	l2rsp_address;		// From l2_cache of l2_cache.v
	wire [`CORE_INDEX_WIDTH-1:0] l2rsp_core;// From l2_cache of l2_cache.v
	wire [511:0]	l2rsp_data;		// From l2_cache of l2_cache.v
	wire [1:0]	l2rsp_op;		// From l2_cache of l2_cache.v
	wire		l2rsp_status;		// From l2_cache of l2_cache.v
	wire [1:0]	l2rsp_strand;		// From l2_cache of l2_cache.v
	wire [1:0]	l2rsp_unit;		// From l2_cache of l2_cache.v
	wire		l2rsp_valid;		// From l2_cache of l2_cache.v
	wire		pc_event_cond_branch_not_taken;// From core0 of core.v
	wire		pc_event_cond_branch_taken;// From core0 of core.v
	wire [3:0]	pc_event_dcache_wait;	// From core0 of core.v
	wire [3:0]	pc_event_icache_wait;	// From core0 of core.v
	wire		pc_event_instruction_issue;// From core0 of core.v
	wire		pc_event_instruction_retire;// From core0 of core.v
	wire		pc_event_l1d_hit;	// From core0 of core.v
	wire		pc_event_l1d_miss;	// From core0 of core.v
	wire		pc_event_l1i_hit;	// From core0 of core.v
	wire		pc_event_l1i_miss;	// From core0 of core.v
	wire		pc_event_l2_hit;	// From l2_cache of l2_cache.v
	wire		pc_event_l2_miss;	// From l2_cache of l2_cache.v
	wire		pc_event_l2_wait;	// From l2_cache of l2_cache.v
	wire		pc_event_l2_writeback;	// From l2_cache of l2_cache.v
	wire		pc_event_mispredicted_branch;// From core0 of core.v
	wire [3:0]	pc_event_raw_wait;	// From core0 of core.v
	wire		pc_event_store;		// From l2_cache of l2_cache.v
	wire		pc_event_uncond_branch;	// From core0 of core.v
	// End of automatics
	
	wire[25:0] l2req_address;
	wire[`CORE_INDEX_WIDTH - 1:0] l2req_core;
	wire[`NUM_CORES - 1:0] l2rsp_update;
	wire[`NUM_CORES * 2 - 1:0] l2rsp_way;
	wire[63:0] l2req_mask;
	wire[2:0] l2req_op;	
	wire l2req_ready;
	wire[1:0] l2req_strand;	
	wire[1:0] l2req_unit;
	wire l2req_valid;
	wire[511:0] l2req_data;
	wire[1:0] l2req_way;
	wire[25:0] l2req_address0;
	wire[63:0] l2req_mask0;
	wire[2:0] l2req_op0;	
	wire l2req_ready0;
	wire[1:0] l2req_strand0;	
	wire[1:0] l2req_unit0;
	wire l2req_valid0;
	wire[1:0] l2req_way0;
	wire[511:0] l2req_data0;
	wire[25:0] l2req_address1;
	wire[63:0] l2req_mask1;
	wire[2:0] l2req_op1;	
	wire l2req_ready1;
	wire[1:0] l2req_strand1;	
	wire[1:0] l2req_unit1;
	wire l2req_valid1;
	wire[1:0] l2req_way1;
	wire[511:0] l2req_data1;
	wire halt0;
	wire halt1;

	core #(4'd0) core0(
		.halt_o(halt0),
		.l2rsp_update(l2rsp_update[0]),
		.l2rsp_way(l2rsp_way[1:0]),
		.l2req_valid(l2req_valid0),
		.l2req_strand(l2req_strand0),
		.l2req_unit(l2req_unit0),
		.l2req_op(l2req_op0),
		.l2req_way(l2req_way0),
		.l2req_address(l2req_address0),
		.l2req_data(l2req_data0),
		.l2req_mask(l2req_mask0),
		.l2req_ready(l2req_ready0),
		/*AUTOINST*/
			   // Outputs
			   .io_write_en		(io_write_en),
			   .io_read_en		(io_read_en),
			   .io_address		(io_address[31:0]),
			   .io_write_data	(io_write_data[31:0]),
			   .pc_event_raw_wait	(pc_event_raw_wait[3:0]),
			   .pc_event_dcache_wait(pc_event_dcache_wait[3:0]),
			   .pc_event_icache_wait(pc_event_icache_wait[3:0]),
			   .pc_event_l1d_hit	(pc_event_l1d_hit),
			   .pc_event_l1d_miss	(pc_event_l1d_miss),
			   .pc_event_l1i_hit	(pc_event_l1i_hit),
			   .pc_event_l1i_miss	(pc_event_l1i_miss),
			   .pc_event_mispredicted_branch(pc_event_mispredicted_branch),
			   .pc_event_instruction_issue(pc_event_instruction_issue),
			   .pc_event_instruction_retire(pc_event_instruction_retire),
			   .pc_event_uncond_branch(pc_event_uncond_branch),
			   .pc_event_cond_branch_taken(pc_event_cond_branch_taken),
			   .pc_event_cond_branch_not_taken(pc_event_cond_branch_not_taken),
			   // Inputs
			   .clk			(clk),
			   .reset		(reset),
			   .io_read_data	(io_read_data[31:0]),
			   .l2rsp_valid		(l2rsp_valid),
			   .l2rsp_core		(l2rsp_core[`CORE_INDEX_WIDTH-1:0]),
			   .l2rsp_status	(l2rsp_status),
			   .l2rsp_unit		(l2rsp_unit[1:0]),
			   .l2rsp_strand	(l2rsp_strand[1:0]),
			   .l2rsp_op		(l2rsp_op[1:0]),
			   .l2rsp_address	(l2rsp_address[25:0]),
			   .l2rsp_data		(l2rsp_data[511:0]));

`ifdef ENABLE_CORE1
	core #(4'd1) core1(
		.halt_o(halt1),
		.l2rsp_update(l2rsp_update[1]),
		.l2rsp_way(l2rsp_way[3:2]),
		.io_write_en(),	// XXX no IO access for second core currently
		.io_read_en(),
		.io_address(),
		.io_write_data(),
		.l2req_valid(l2req_valid1),
		.l2req_strand(l2req_strand1),
		.l2req_unit(l2req_unit1),
		.l2req_op(l2req_op1),
		.l2req_way(l2req_way1),
		.l2req_address(l2req_address1),
		.l2req_data(l2req_data1),
		.l2req_mask(l2req_mask1),
		.l2req_ready(l2req_ready1),
		.io_read_data(32'd0),
		.pc_event_raw_wait(),
		.pc_event_dcache_wait(),
		.pc_event_icache_wait(),
		.pc_event_l1d_hit(),
		.pc_event_l1d_miss(),
		.pc_event_l1d_collided_load(),
		.pc_event_l1i_hit(),
		.pc_event_l1i_miss(),
		.pc_event_l1i_collided_load(),
		.pc_event_mispredicted_branch(),
		.pc_event_instruction_issue(),
		.pc_event_instruction_retire(),
		.pc_event_uncond_branch(),
		.pc_event_cond_branch_taken(),
		.pc_event_cond_branch_not_taken(),
		/*AUTOINST*/
			   // Inputs
			   .clk			(clk),
			   .reset		(reset),
			   .l2rsp_valid		(l2rsp_valid),
			   .l2rsp_core		(l2rsp_core[`CORE_INDEX_WIDTH-1:0]),
			   .l2rsp_status	(l2rsp_status),
			   .l2rsp_unit		(l2rsp_unit[1:0]),
			   .l2rsp_strand	(l2rsp_strand[1:0]),
			   .l2rsp_op		(l2rsp_op[1:0]),
			   .l2rsp_address	(l2rsp_address[25:0]),
			   .l2rsp_data		(l2rsp_data[511:0]));

	// Simple arbiter for cores
	reg select_core0 = 0;
	assign { l2req_core, l2req_valid, l2req_strand, l2req_op, l2req_way, l2req_address,
		l2req_data, l2req_mask, l2req_unit } = select_core0
		? { 1'b0, l2req_valid0, l2req_strand0, l2req_op0, l2req_way0, l2req_address0,
			l2req_data0, l2req_mask0, l2req_unit0 }
		: { 1'b1, l2req_valid1, l2req_strand1, l2req_op1, l2req_way1, l2req_address1,
			l2req_data1, l2req_mask1, l2req_unit1 };
	assign l2req_ready0 = select_core0 && l2req_ready;
	assign l2req_ready1 = !select_core0 && l2req_ready;
	
	always @(posedge reset, posedge clk)
	begin
		if (reset)
			select_core0 = 0;
		else if (l2req_ready)
			select_core0 = !select_core0;
	end
`else
	assign halt1 = 1;
	assign l2req_valid = l2req_valid0;
	assign l2req_core = 0;
	assign l2req_strand = l2req_strand0;
	assign l2req_op = l2req_op0;
	assign l2req_way = l2req_way0;
	assign l2req_address = l2req_address0;
	assign l2req_data = l2req_data0;
	assign l2req_mask = l2req_mask0;
	assign l2req_unit = l2req_unit0;
	assign l2req_ready0 = l2req_ready;
`endif

	l2_cache l2_cache(
				/*AUTOINST*/
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
			  .pc_event_l2_wait	(pc_event_l2_wait),
			  .pc_event_l2_writeback(pc_event_l2_writeback),
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

`ifdef ENABLE_PERFORMANCE_COUNTERS
	performance_counters #(.NUM_COUNTERS(15)) performance_counters(
		.pc_event({
			pc_event_l2_writeback,
			pc_event_l2_wait,
			pc_event_l2_hit,
			pc_event_l2_miss,
			pc_event_l1d_hit,
			pc_event_l1d_miss,
			pc_event_l1i_hit,
			pc_event_l1i_miss,
			pc_event_store,
			pc_event_instruction_issue,
			pc_event_instruction_retire,
			pc_event_mispredicted_branch,
			pc_event_uncond_branch,
			pc_event_cond_branch_taken,
			pc_event_cond_branch_not_taken
		}),
						/*AUTOINST*/
								       // Inputs
								       .clk		(clk),
								       .reset		(reset),
								       .pc_event_raw_wait(pc_event_raw_wait[3:0]),
								       .pc_event_dcache_wait(pc_event_dcache_wait[3:0]),
								       .pc_event_icache_wait(pc_event_icache_wait[3:0]));
`endif
	
endmodule
