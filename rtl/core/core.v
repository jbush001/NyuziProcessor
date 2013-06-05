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

`include "defines.v"

//
// The instruction pipeline, store buffer, L1 instruction/data caches, and L2 arbiter.
// This is instantiated multiple times for multi-processing.
//

module core
	#(parameter	CORE_ID = 4'd0)

	(input				clk,
	input				reset,
	output				halt_o,
	
	// Non-cacheable memory signals
	output				io_write_en,
	output				io_read_en,
	output[31:0]		io_address,
	output[31:0]		io_write_data,
	input [31:0]		io_read_data,
	
	// L2 request interface
	output 				l2req_valid,
	input				l2req_ready,
	output [1:0]		l2req_strand,
	output [1:0]		l2req_unit,
	output [2:0]		l2req_op,
	output [1:0]		l2req_way,
	output [25:0]		l2req_address,
	output [511:0]		l2req_data,
	output [63:0]		l2req_mask,
	
	// L2 response interface
	input 				l2rsp_valid,
	input  [`CORE_INDEX_WIDTH - 1:0] l2rsp_core,
	input				l2rsp_status,
	input [1:0]			l2rsp_unit,
	input [1:0]			l2rsp_strand,
	input [1:0]			l2rsp_op,
	input 				l2rsp_update,
	input [25:0] 		l2rsp_address,
	input [1:0]			l2rsp_way,
	input [511:0]		l2rsp_data,
	
	// Performance counter events
	output [3:0]		pc_event_raw_wait,
	output [3:0]		pc_event_dcache_wait,
	output [3:0]		pc_event_icache_wait,
	output				pc_event_l1d_hit,
	output				pc_event_l1d_miss,
	output				pc_event_l1i_hit,
	output				pc_event_l1i_miss,
	output				pc_event_mispredicted_branch,
	output				pc_event_instruction_issue,
	output				pc_event_instruction_retire,
	output				pc_event_uncond_branch,
	output				pc_event_cond_branch_taken,
	output				pc_event_cond_branch_not_taken);

	wire [511:0] data_from_dcache;

	/*AUTOWIRE*/
	// Beginning of automatic wires (for undeclared instantiated-module outputs)
	wire [511:0]	cache_data;		// From dcache of l1_cache.v
	wire [511:0]	data_to_dcache;		// From pipeline of pipeline.v
	wire [25:0]	dcache_addr;		// From pipeline of pipeline.v
	wire		dcache_dinvalidate;	// From pipeline of pipeline.v
	wire		dcache_flush;		// From pipeline of pipeline.v
	wire		dcache_hit;		// From dcache of l1_cache.v
	wire		dcache_iinvalidate;	// From pipeline of pipeline.v
	wire [25:0]	dcache_l2req_address;	// From dcache of l1_cache.v
	wire [511:0]	dcache_l2req_data;	// From dcache of l1_cache.v
	wire [63:0]	dcache_l2req_mask;	// From dcache of l1_cache.v
	wire [2:0]	dcache_l2req_op;	// From dcache of l1_cache.v
	wire		dcache_l2req_ready;	// From l2req_arbiter_mux of l2req_arbiter_mux.v
	wire [1:0]	dcache_l2req_strand;	// From dcache of l1_cache.v
	wire [1:0]	dcache_l2req_unit;	// From dcache of l1_cache.v
	wire		dcache_l2req_valid;	// From dcache of l1_cache.v
	wire [1:0]	dcache_l2req_way;	// From dcache of l1_cache.v
	wire		dcache_load;		// From pipeline of pipeline.v
	wire		dcache_load_collision;	// From dcache of l1_cache.v
	wire [3:0]	dcache_load_complete_strands;// From dcache of l1_cache.v
	wire [1:0]	dcache_req_strand;	// From pipeline of pipeline.v
	wire		dcache_req_sync;	// From pipeline of pipeline.v
	wire		dcache_stbar;		// From pipeline of pipeline.v
	wire		dcache_store;		// From pipeline of pipeline.v
	wire [63:0]	dcache_store_mask;	// From pipeline of pipeline.v
	wire [31:0]	icache_addr;		// From pipeline of pipeline.v
	wire [31:0]	icache_data;		// From instruction_select_mux of lane_select_mux.v
	wire		icache_hit;		// From icache of l1_cache.v
	wire [25:0]	icache_l2req_address;	// From icache of l1_cache.v
	wire [511:0]	icache_l2req_data;	// From icache of l1_cache.v
	wire [63:0]	icache_l2req_mask;	// From icache of l1_cache.v
	wire [2:0]	icache_l2req_op;	// From icache of l1_cache.v
	wire		icache_l2req_ready;	// From l2req_arbiter_mux of l2req_arbiter_mux.v
	wire [1:0]	icache_l2req_strand;	// From icache of l1_cache.v
	wire [1:0]	icache_l2req_unit;	// From icache of l1_cache.v
	wire		icache_l2req_valid;	// From icache of l1_cache.v
	wire [1:0]	icache_l2req_way;	// From icache of l1_cache.v
	wire		icache_load_collision;	// From icache of l1_cache.v
	wire [3:0]	icache_load_complete_strands;// From icache of l1_cache.v
	wire [1:0]	icache_req_strand;	// From pipeline of pipeline.v
	wire		icache_request;		// From pipeline of pipeline.v
	wire [511:0]	l1i_data;		// From icache of l1_cache.v
	wire [511:0]	stbuf_data;		// From store_buffer of store_buffer.v
	wire [25:0]	stbuf_l2req_address;	// From store_buffer of store_buffer.v
	wire [511:0]	stbuf_l2req_data;	// From store_buffer of store_buffer.v
	wire [63:0]	stbuf_l2req_mask;	// From store_buffer of store_buffer.v
	wire [2:0]	stbuf_l2req_op;		// From store_buffer of store_buffer.v
	wire		stbuf_l2req_ready;	// From l2req_arbiter_mux of l2req_arbiter_mux.v
	wire [1:0]	stbuf_l2req_strand;	// From store_buffer of store_buffer.v
	wire [1:0]	stbuf_l2req_unit;	// From store_buffer of store_buffer.v
	wire		stbuf_l2req_valid;	// From store_buffer of store_buffer.v
	wire [1:0]	stbuf_l2req_way;	// From store_buffer of store_buffer.v
	wire [63:0]	stbuf_mask;		// From store_buffer of store_buffer.v
	wire		stbuf_rollback;		// From store_buffer of store_buffer.v
	wire [3:0]	store_resume_strands;	// From store_buffer of store_buffer.v
	// End of automatics

	reg[3:0] l1i_lane_latched;
	wire l2rsp_valid_for_me = l2rsp_valid && l2rsp_core == CORE_ID;

	/* l1_cache AUTO_TEMPLATE(
		.synchronized_i(0),
		.request_addr(icache_addr[31:6]),
		.access_i(icache_request),
		.data_o(l1i_data[]),
		.cache_hit_o(icache_hit),
		.load_complete_strands_o(icache_load_complete_strands[]),
		.load_collision_o(icache_load_collision),
		.strand_i(icache_req_strand[]),
		.pc_event_cache_hit(pc_event_l1i_hit),
		.pc_event_cache_miss(pc_event_l1i_miss),
		.\(l2req_.*\)(icache_\1[]),
		);
	*/
	l1_cache #(.UNIT_ID(`UNIT_ICACHE), .CORE_ID(CORE_ID)) icache(
		/*AUTOINST*/
								     // Outputs
								     .data_o		(l1i_data[511:0]), // Templated
								     .cache_hit_o	(icache_hit),	 // Templated
								     .load_collision_o	(icache_load_collision), // Templated
								     .load_complete_strands_o(icache_load_complete_strands[3:0]), // Templated
								     .l2req_valid	(icache_l2req_valid), // Templated
								     .l2req_unit	(icache_l2req_unit[1:0]), // Templated
								     .l2req_strand	(icache_l2req_strand[1:0]), // Templated
								     .l2req_op		(icache_l2req_op[2:0]), // Templated
								     .l2req_way		(icache_l2req_way[1:0]), // Templated
								     .l2req_address	(icache_l2req_address[25:0]), // Templated
								     .l2req_data	(icache_l2req_data[511:0]), // Templated
								     .l2req_mask	(icache_l2req_mask[63:0]), // Templated
								     .pc_event_cache_hit(pc_event_l1i_hit), // Templated
								     .pc_event_cache_miss(pc_event_l1i_miss), // Templated
								     // Inputs
								     .clk		(clk),
								     .reset		(reset),
								     .access_i		(icache_request), // Templated
								     .request_addr	(icache_addr[31:6]), // Templated
								     .strand_i		(icache_req_strand[1:0]), // Templated
								     .synchronized_i	(0),		 // Templated
								     .l2req_ready	(icache_l2req_ready), // Templated
								     .l2rsp_valid	(l2rsp_valid),
								     .l2rsp_core	(l2rsp_core[`CORE_INDEX_WIDTH-1:0]),
								     .l2rsp_unit	(l2rsp_unit[1:0]),
								     .l2rsp_strand	(l2rsp_strand[1:0]),
								     .l2rsp_way		(l2rsp_way[1:0]),
								     .l2rsp_op		(l2rsp_op[1:0]),
								     .l2rsp_address	(l2rsp_address[25:0]),
								     .l2rsp_update	(l2rsp_update),
								     .l2rsp_data	(l2rsp_data[511:0]));
	
	always @(posedge clk, posedge reset)
	begin
		if (reset)
		begin
			/*AUTORESET*/
			// Beginning of autoreset for uninitialized flops
			l1i_lane_latched <= 4'h0;
			// End of automatics
		end
		else
			l1i_lane_latched <= icache_addr[5:2];
	end

	/* lane_select_mux AUTO_TEMPLATE(
		.value_i(l1i_data[]),
		.lane_select_i(l1i_lane_latched),
		.value_o(icache_data[]));
	*/
	lane_select_mux #(.ASCENDING_INDEX(1)) instruction_select_mux(
		/*AUTOINST*/
								      // Outputs
								      .value_o		(icache_data[31:0]), // Templated
								      // Inputs
								      .value_i		(l1i_data[511:0]), // Templated
								      .lane_select_i	(l1i_lane_latched)); // Templated

	/* l1_cache AUTO_TEMPLATE(
		.synchronized_i(dcache_req_sync),
		.request_addr(dcache_addr[]),
		.data_o(cache_data[]),
		.access_i(dcache_load),
		.strand_i(dcache_req_strand[]),
		.cache_hit_o(dcache_hit),
		.load_complete_strands_o(dcache_load_complete_strands[]),
		.load_collision_o(dcache_load_collision),
		.\(l2req_.*\)(dcache_\1[]),
		.pc_event_cache_hit(pc_event_l1d_hit),
		.pc_event_cache_miss(pc_event_l1d_miss),
		);
	*/
	l1_cache #(.UNIT_ID(`UNIT_DCACHE), .CORE_ID(CORE_ID)) dcache(
		/*AUTOINST*/
								     // Outputs
								     .data_o		(cache_data[511:0]), // Templated
								     .cache_hit_o	(dcache_hit),	 // Templated
								     .load_collision_o	(dcache_load_collision), // Templated
								     .load_complete_strands_o(dcache_load_complete_strands[3:0]), // Templated
								     .l2req_valid	(dcache_l2req_valid), // Templated
								     .l2req_unit	(dcache_l2req_unit[1:0]), // Templated
								     .l2req_strand	(dcache_l2req_strand[1:0]), // Templated
								     .l2req_op		(dcache_l2req_op[2:0]), // Templated
								     .l2req_way		(dcache_l2req_way[1:0]), // Templated
								     .l2req_address	(dcache_l2req_address[25:0]), // Templated
								     .l2req_data	(dcache_l2req_data[511:0]), // Templated
								     .l2req_mask	(dcache_l2req_mask[63:0]), // Templated
								     .pc_event_cache_hit(pc_event_l1d_hit), // Templated
								     .pc_event_cache_miss(pc_event_l1d_miss), // Templated
								     // Inputs
								     .clk		(clk),
								     .reset		(reset),
								     .access_i		(dcache_load),	 // Templated
								     .request_addr	(dcache_addr[25:0]), // Templated
								     .strand_i		(dcache_req_strand[1:0]), // Templated
								     .synchronized_i	(dcache_req_sync), // Templated
								     .l2req_ready	(dcache_l2req_ready), // Templated
								     .l2rsp_valid	(l2rsp_valid),
								     .l2rsp_core	(l2rsp_core[`CORE_INDEX_WIDTH-1:0]),
								     .l2rsp_unit	(l2rsp_unit[1:0]),
								     .l2rsp_strand	(l2rsp_strand[1:0]),
								     .l2rsp_way		(l2rsp_way[1:0]),
								     .l2rsp_op		(l2rsp_op[1:0]),
								     .l2rsp_address	(l2rsp_address[25:0]),
								     .l2rsp_update	(l2rsp_update),
								     .l2rsp_data	(l2rsp_data[511:0]));

	/* store_buffer AUTO_TEMPLATE(
		.strand_i(dcache_req_strand[]),
		.synchronized_i(dcache_req_sync),
		.request_addr(dcache_addr[]),
		.data_o(stbuf_data[]),
		.mask_o(stbuf_mask[]),
		.rollback_o(stbuf_rollback),
		.l2rsp_valid(l2rsp_valid_for_me),
		.\(l2req_.*\)(stbuf_\1[]),
		);
	*/
	store_buffer store_buffer(
		/*AUTOINST*/
				  // Outputs
				  .store_resume_strands	(store_resume_strands[3:0]),
				  .data_o		(stbuf_data[511:0]), // Templated
				  .mask_o		(stbuf_mask[63:0]), // Templated
				  .rollback_o		(stbuf_rollback), // Templated
				  .l2req_valid		(stbuf_l2req_valid), // Templated
				  .l2req_unit		(stbuf_l2req_unit[1:0]), // Templated
				  .l2req_strand		(stbuf_l2req_strand[1:0]), // Templated
				  .l2req_op		(stbuf_l2req_op[2:0]), // Templated
				  .l2req_way		(stbuf_l2req_way[1:0]), // Templated
				  .l2req_address	(stbuf_l2req_address[25:0]), // Templated
				  .l2req_data		(stbuf_l2req_data[511:0]), // Templated
				  .l2req_mask		(stbuf_l2req_mask[63:0]), // Templated
				  // Inputs
				  .clk			(clk),
				  .reset		(reset),
				  .request_addr		(dcache_addr[25:0]), // Templated
				  .data_to_dcache	(data_to_dcache[511:0]),
				  .dcache_store		(dcache_store),
				  .dcache_flush		(dcache_flush),
				  .dcache_dinvalidate	(dcache_dinvalidate),
				  .dcache_iinvalidate	(dcache_iinvalidate),
				  .dcache_stbar		(dcache_stbar),
				  .synchronized_i	(dcache_req_sync), // Templated
				  .dcache_store_mask	(dcache_store_mask[63:0]),
				  .strand_i		(dcache_req_strand[1:0]), // Templated
				  .l2req_ready		(stbuf_l2req_ready), // Templated
				  .l2rsp_valid		(l2rsp_valid_for_me), // Templated
				  .l2rsp_status		(l2rsp_status),
				  .l2rsp_unit		(l2rsp_unit[1:0]),
				  .l2rsp_strand		(l2rsp_strand[1:0]));

	// Note: don't use [] in params because array instantiation confuses
	// AUTO_TEMPLATE.
	/* mask_unit AUTO_TEMPLATE(
		.mask_i(stbuf_mask),
		.data0_i(cache_data),
		.data1_i(stbuf_data),
		.result_o(data_from_dcache));
	*/
	mask_unit store_buffer_raw_mux[63:0] (
		/*AUTOINST*/
					      // Outputs
					      .result_o		(data_from_dcache), // Templated
					      // Inputs
					      .mask_i		(stbuf_mask),	 // Templated
					      .data0_i		(cache_data),	 // Templated
					      .data1_i		(stbuf_data));	 // Templated

	wire[3:0] dcache_resume_strands = dcache_load_complete_strands | store_resume_strands;

	pipeline #(.CORE_ID(CORE_ID)) pipeline(/*AUTOINST*/
					       // Outputs
					       .halt_o		(halt_o),
					       .icache_addr	(icache_addr[31:0]),
					       .icache_request	(icache_request),
					       .icache_req_strand(icache_req_strand[1:0]),
					       .io_write_en	(io_write_en),
					       .io_read_en	(io_read_en),
					       .io_address	(io_address[31:0]),
					       .io_write_data	(io_write_data[31:0]),
					       .dcache_addr	(dcache_addr[25:0]),
					       .dcache_load	(dcache_load),
					       .dcache_req_sync	(dcache_req_sync),
					       .dcache_store	(dcache_store),
					       .dcache_flush	(dcache_flush),
					       .dcache_stbar	(dcache_stbar),
					       .dcache_dinvalidate(dcache_dinvalidate),
					       .dcache_iinvalidate(dcache_iinvalidate),
					       .dcache_req_strand(dcache_req_strand[1:0]),
					       .dcache_store_mask(dcache_store_mask[63:0]),
					       .data_to_dcache	(data_to_dcache[511:0]),
					       .pc_event_raw_wait(pc_event_raw_wait[3:0]),
					       .pc_event_dcache_wait(pc_event_dcache_wait[3:0]),
					       .pc_event_icache_wait(pc_event_icache_wait[3:0]),
					       .pc_event_mispredicted_branch(pc_event_mispredicted_branch),
					       .pc_event_instruction_issue(pc_event_instruction_issue),
					       .pc_event_instruction_retire(pc_event_instruction_retire),
					       .pc_event_uncond_branch(pc_event_uncond_branch),
					       .pc_event_cond_branch_taken(pc_event_cond_branch_taken),
					       .pc_event_cond_branch_not_taken(pc_event_cond_branch_not_taken),
					       // Inputs
					       .clk		(clk),
					       .reset		(reset),
					       .icache_data	(icache_data[31:0]),
					       .icache_hit	(icache_hit),
					       .icache_load_complete_strands(icache_load_complete_strands[3:0]),
					       .icache_load_collision(icache_load_collision),
					       .io_read_data	(io_read_data[31:0]),
					       .dcache_hit	(dcache_hit),
					       .stbuf_rollback	(stbuf_rollback),
					       .data_from_dcache(data_from_dcache[511:0]),
					       .dcache_resume_strands(dcache_resume_strands[3:0]),
					       .dcache_load_collision(dcache_load_collision));

	l2req_arbiter_mux l2req_arbiter_mux(/*AUTOINST*/
					    // Outputs
					    .l2req_valid	(l2req_valid),
					    .l2req_strand	(l2req_strand[1:0]),
					    .l2req_unit		(l2req_unit[1:0]),
					    .l2req_op		(l2req_op[2:0]),
					    .l2req_way		(l2req_way[1:0]),
					    .l2req_address	(l2req_address[25:0]),
					    .l2req_data		(l2req_data[511:0]),
					    .l2req_mask		(l2req_mask[63:0]),
					    .icache_l2req_ready	(icache_l2req_ready),
					    .dcache_l2req_ready	(dcache_l2req_ready),
					    .stbuf_l2req_ready	(stbuf_l2req_ready),
					    // Inputs
					    .clk		(clk),
					    .reset		(reset),
					    .l2req_ready	(l2req_ready),
					    .icache_l2req_valid	(icache_l2req_valid),
					    .icache_l2req_strand(icache_l2req_strand[1:0]),
					    .icache_l2req_unit	(icache_l2req_unit[1:0]),
					    .icache_l2req_op	(icache_l2req_op[2:0]),
					    .icache_l2req_way	(icache_l2req_way[1:0]),
					    .icache_l2req_address(icache_l2req_address[25:0]),
					    .icache_l2req_data	(icache_l2req_data[511:0]),
					    .icache_l2req_mask	(icache_l2req_mask[63:0]),
					    .dcache_l2req_valid	(dcache_l2req_valid),
					    .dcache_l2req_strand(dcache_l2req_strand[1:0]),
					    .dcache_l2req_unit	(dcache_l2req_unit[1:0]),
					    .dcache_l2req_op	(dcache_l2req_op[2:0]),
					    .dcache_l2req_way	(dcache_l2req_way[1:0]),
					    .dcache_l2req_address(dcache_l2req_address[25:0]),
					    .dcache_l2req_data	(dcache_l2req_data[511:0]),
					    .dcache_l2req_mask	(dcache_l2req_mask[63:0]),
					    .stbuf_l2req_valid	(stbuf_l2req_valid),
					    .stbuf_l2req_strand	(stbuf_l2req_strand[1:0]),
					    .stbuf_l2req_unit	(stbuf_l2req_unit[1:0]),
					    .stbuf_l2req_op	(stbuf_l2req_op[2:0]),
					    .stbuf_l2req_way	(stbuf_l2req_way[1:0]),
					    .stbuf_l2req_address(stbuf_l2req_address[25:0]),
					    .stbuf_l2req_data	(stbuf_l2req_data[511:0]),
					    .stbuf_l2req_mask	(stbuf_l2req_mask[63:0]));
endmodule
