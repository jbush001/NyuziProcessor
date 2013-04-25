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

`include "l2_cache.h"

//
// The pipeline, store buffer, L1 instruction/data caches, and L2 arbiter.
// This would be instantiated multiple times for multi-processing.
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
	output				pc_event_l1d_collided_load,
	output				pc_event_l1i_hit,
	output				pc_event_l1i_miss,
	output				pc_event_l1i_collided_load,
	output				pc_event_mispredicted_branch,
	output				pc_event_instruction_issue,
	output				pc_event_instruction_retire);

	wire[31:0] 			icache_data;
	wire 				icache_hit;
	wire [3:0]			icache_load_complete_strands;
	wire[511:0] 		data_from_dcache;
	wire 				dcache_hit;
	wire				stbuf_rollback;
	wire[1:0]			dcache_req_strand;
	wire				icache_l2req_valid;
	wire[1:0]			icache_l2req_unit;
	wire[1:0]			icache_l2req_strand;
	wire[2:0]			icache_l2req_op;
	wire[1:0]			icache_l2req_way;
	wire[25:0]			icache_l2req_address;
	wire[511:0]			icache_l2req_data;
	wire[63:0]			icache_l2req_mask;
	wire				dcache_l2req_valid;
	wire[1:0]			dcache_l2req_unit;
	wire[1:0]			dcache_l2req_strand;
	wire[2:0]			dcache_l2req_op;
	wire[1:0]			dcache_l2req_way;
	wire[25:0]			dcache_l2req_address;
	wire[511:0]			dcache_l2req_data;
	wire[63:0]			dcache_l2req_mask;
	wire				stbuf_l2req_valid;
	wire[1:0]			stbuf_l2req_unit;
	wire[1:0]			stbuf_l2req_strand;
	wire[2:0]			stbuf_l2req_op;
	wire[1:0]			stbuf_l2req_way;
	wire[25:0]			stbuf_l2req_address;
	wire[511:0]			stbuf_l2req_data;
	wire[63:0]			stbuf_l2req_mask;
	wire[3:0]			dcache_load_complete_strands;
	wire[3:0]			store_resume_strands;
	wire[511:0]			cache_data;
	wire[511:0]			stbuf_data;
	wire[63:0]			stbuf_mask;
	wire				dcache_load_collision;
	wire				icache_load_collision;
	wire[511:0]			l1i_data;
	reg[3:0]			l1i_lane_latched;

	/*AUTOWIRE*/
	// Beginning of automatic wires (for undeclared instantiated-module outputs)
	wire [511:0]	data_to_dcache;		// From pipeline of pipeline.v
	wire [25:0]	dcache_addr;		// From pipeline of pipeline.v
	wire		dcache_dinvalidate;	// From pipeline of pipeline.v
	wire		dcache_flush;		// From pipeline of pipeline.v
	wire		dcache_iinvalidate;	// From pipeline of pipeline.v
	wire		dcache_l2req_ready;	// From l2req_arbiter_mux of l2req_arbiter_mux.v
	wire		dcache_load;		// From pipeline of pipeline.v
	wire		dcache_req_sync;	// From pipeline of pipeline.v
	wire		dcache_stbar;		// From pipeline of pipeline.v
	wire		dcache_store;		// From pipeline of pipeline.v
	wire [63:0]	dcache_store_mask;	// From pipeline of pipeline.v
	wire [31:0]	icache_addr;		// From pipeline of pipeline.v
	wire		icache_l2req_ready;	// From l2req_arbiter_mux of l2req_arbiter_mux.v
	wire [1:0]	icache_req_strand;	// From pipeline of pipeline.v
	wire		icache_request;		// From pipeline of pipeline.v
	wire		stbuf_l2req_ready;	// From l2req_arbiter_mux of l2req_arbiter_mux.v
	// End of automatics

	wire l2rsp_valid_for_me = l2rsp_valid && l2rsp_core == CORE_ID;

	l1_cache #(.UNIT_ID(`UNIT_ICACHE), .CORE_ID(CORE_ID)) icache(
		.synchronized_i(0),
		.request_addr(icache_addr[31:6]),
		.access_i(icache_request),
		.data_o(l1i_data),
		.cache_hit_o(icache_hit),
		.load_complete_strands_o(icache_load_complete_strands),
		.load_collision_o(icache_load_collision),
		.strand_i(icache_req_strand),
		.l2req_valid(icache_l2req_valid), 
		.l2req_ready(icache_l2req_ready),
		.l2req_unit(icache_l2req_unit),
		.l2req_strand(icache_l2req_strand),
		.l2req_op(icache_l2req_op),
		.l2req_way(icache_l2req_way),
		.l2req_address(icache_l2req_address),
		.l2req_data(icache_l2req_data),
		.l2req_mask(icache_l2req_mask),
		.pc_event_cache_hit(pc_event_l1i_hit),
		.pc_event_cache_miss(pc_event_l1i_miss),
		.pc_event_collided_load(pc_event_l1i_collided_load),
		/*AUTOINST*/
								     // Inputs
								     .clk		(clk),
								     .reset		(reset),
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

	lane_select_mux #(.ASCENDING_INDEX(1)) instruction_select_mux(
		.value_i(l1i_data),
		.lane_select_i(l1i_lane_latched),
		.value_o(icache_data));

	l1_cache #(.UNIT_ID(`UNIT_DCACHE), .CORE_ID(CORE_ID)) dcache(
		.synchronized_i(dcache_req_sync),
		.request_addr(dcache_addr),
		.data_o(cache_data),
		.access_i(dcache_load),
		.strand_i(dcache_req_strand),
		.cache_hit_o(dcache_hit),
		.load_complete_strands_o(dcache_load_complete_strands),
		.load_collision_o(dcache_load_collision),
		.l2req_valid(dcache_l2req_valid),
		.l2req_ready(dcache_l2req_ready),
		.l2req_unit(dcache_l2req_unit),
		.l2req_strand(dcache_l2req_strand),
		.l2req_op(dcache_l2req_op),
		.l2req_way(dcache_l2req_way),
		.l2req_address(dcache_l2req_address),
		.l2req_data(dcache_l2req_data),
		.l2req_mask(dcache_l2req_mask),
		.pc_event_cache_hit(pc_event_l1d_hit),
		.pc_event_cache_miss(pc_event_l1d_miss),
		.pc_event_collided_load(pc_event_l1d_collided_load),
		/*AUTOINST*/
								     // Inputs
								     .clk		(clk),
								     .reset		(reset),
								     .l2rsp_valid	(l2rsp_valid),
								     .l2rsp_core	(l2rsp_core[`CORE_INDEX_WIDTH-1:0]),
								     .l2rsp_unit	(l2rsp_unit[1:0]),
								     .l2rsp_strand	(l2rsp_strand[1:0]),
								     .l2rsp_way		(l2rsp_way[1:0]),
								     .l2rsp_op		(l2rsp_op[1:0]),
								     .l2rsp_address	(l2rsp_address[25:0]),
								     .l2rsp_update	(l2rsp_update),
								     .l2rsp_data	(l2rsp_data[511:0]));

	store_buffer store_buffer(
		.strand_i(dcache_req_strand),
		.synchronized_i(dcache_req_sync),
		.request_addr(dcache_addr),
		.data_o(stbuf_data),
		.mask_o(stbuf_mask),
		.rollback_o(stbuf_rollback),
		.l2req_valid(stbuf_l2req_valid),
		.l2req_ready(stbuf_l2req_ready),
		.l2req_unit(stbuf_l2req_unit),
		.l2req_strand(stbuf_l2req_strand),
		.l2req_op(stbuf_l2req_op),
		.l2req_way(stbuf_l2req_way),
		.l2req_address(stbuf_l2req_address),
		.l2req_data(stbuf_l2req_data),
		.l2req_mask(stbuf_l2req_mask),
		.l2rsp_valid(l2rsp_valid_for_me),
		/*AUTOINST*/
				  // Outputs
				  .store_resume_strands	(store_resume_strands[3:0]),
				  // Inputs
				  .clk			(clk),
				  .reset		(reset),
				  .data_to_dcache	(data_to_dcache[511:0]),
				  .dcache_store		(dcache_store),
				  .dcache_flush		(dcache_flush),
				  .dcache_dinvalidate	(dcache_dinvalidate),
				  .dcache_iinvalidate	(dcache_iinvalidate),
				  .dcache_stbar		(dcache_stbar),
				  .dcache_store_mask	(dcache_store_mask[63:0]),
				  .l2rsp_status		(l2rsp_status),
				  .l2rsp_unit		(l2rsp_unit[1:0]),
				  .l2rsp_strand		(l2rsp_strand[1:0]));

	mask_unit store_buffer_raw_mux(
		.mask_i(stbuf_mask),
		.data0_i(cache_data),
		.data1_i(stbuf_data),
		.result_o(data_from_dcache));

	wire[3:0] dcache_resume_strands = dcache_load_complete_strands | store_resume_strands;

	pipeline #(.CORE_ID(CORE_ID)) pipeline(/*AUTOINST*/
				     // Outputs
				     .halt_o		(halt_o),
				     .icache_addr	(icache_addr[31:0]),
				     .icache_request	(icache_request),
				     .icache_req_strand	(icache_req_strand[1:0]),
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
				     .dcache_req_strand	(dcache_req_strand[1:0]),
				     .dcache_store_mask	(dcache_store_mask[63:0]),
				     .data_to_dcache	(data_to_dcache[511:0]),
				     .pc_event_raw_wait	(pc_event_raw_wait[3:0]),
				     .pc_event_dcache_wait(pc_event_dcache_wait[3:0]),
				     .pc_event_icache_wait(pc_event_icache_wait[3:0]),
				     .pc_event_mispredicted_branch(pc_event_mispredicted_branch),
				     .pc_event_instruction_issue(pc_event_instruction_issue),
				     .pc_event_instruction_retire(pc_event_instruction_retire),
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
				     .data_from_dcache	(data_from_dcache[511:0]),
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
