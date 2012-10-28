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
	(input				clk,
	output 				l2req_valid,
	input				l2req_ack,
	output [1:0]		l2req_strand,
	output [1:0]		l2req_unit,
	output [2:0]		l2req_op,
	output [1:0]		l2req_way,
	output [25:0]		l2req_address,
	output [511:0]		l2req_data,
	output [63:0]		l2req_mask,
	input 				l2rsp_valid,
	input				l2rsp_status,
	input [1:0]			l2rsp_unit,
	input [1:0]			l2rsp_strand,
	input [1:0]			l2rsp_op,
	input 				l2rsp_update,
	input [1:0]			l2rsp_way,
	input [511:0]		l2rsp_data,
	output				halt_o);

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
	wire[`L1_SET_INDEX_WIDTH - 1:0] store_update_set;
	wire				store_update;
	wire[511:0]			stbuf_data;
	wire[63:0]			stbuf_mask;
	wire				dcache_load_collision;
	wire				icache_load_collision;
	wire[511:0]			l1i_data;
	reg[3:0]			l1i_lane_latched = 0;

	/*AUTOWIRE*/
	// Beginning of automatic wires (for undeclared instantiated-module outputs)
	wire [511:0]	data_to_dcache;		// From pipeline of pipeline.v
	wire [31:0]	dcache_addr;		// From pipeline of pipeline.v
	wire		dcache_flush;		// From pipeline of pipeline.v
	wire		dcache_l2req_selected;	// From l2req_arbiter_mux of l2req_arbiter_mux.v
	wire		dcache_load;		// From pipeline of pipeline.v
	wire		dcache_req_sync;	// From pipeline of pipeline.v
	wire		dcache_stbar;		// From pipeline of pipeline.v
	wire		dcache_store;		// From pipeline of pipeline.v
	wire [63:0]	dcache_store_mask;	// From pipeline of pipeline.v
	wire [31:0]	icache_addr;		// From pipeline of pipeline.v
	wire		icache_l2req_selected;	// From l2req_arbiter_mux of l2req_arbiter_mux.v
	wire [1:0]	icache_req_strand;	// From pipeline of pipeline.v
	wire		icache_request;		// From pipeline of pipeline.v
	wire		stbuf_l2req_selected;	// From l2req_arbiter_mux of l2req_arbiter_mux.v
	// End of automatics

	l1_cache #(`UNIT_ICACHE) icache(
		.clk(clk),
		.synchronized_i(0),
		.store_update_set_i(5'd0),
		.store_update_i(0),
		.address_i(icache_addr),
		.access_i(icache_request),
		.data_o(l1i_data),
		.cache_hit_o(icache_hit),
		.load_complete_strands_o(icache_load_complete_strands),
		.load_collision_o(icache_load_collision),
		.strand_i(icache_req_strand),
		.l2req_valid(icache_l2req_valid), 
		.l2req_ack(l2req_ack && icache_l2req_selected),
		.l2req_unit(icache_l2req_unit),
		.l2req_strand(icache_l2req_strand),
		.l2req_op(icache_l2req_op),
		.l2req_way(icache_l2req_way),
		.l2req_address(icache_l2req_address),
		.l2req_data(icache_l2req_data),
		.l2req_mask(icache_l2req_mask),
		/*AUTOINST*/
					// Inputs
					.l2rsp_valid	(l2rsp_valid),
					.l2rsp_unit	(l2rsp_unit[1:0]),
					.l2rsp_strand	(l2rsp_strand[1:0]),
					.l2rsp_way	(l2rsp_way[1:0]),
					.l2rsp_data	(l2rsp_data[511:0]));
	
	always @(posedge clk)
		l1i_lane_latched <= #1 icache_addr[5:2];

	lane_select_mux #(1) instruction_select_mux(
		.value_i(l1i_data),
		.lane_select_i(l1i_lane_latched),
		.value_o(icache_data));

	l1_cache #(`UNIT_DCACHE) dcache(
		.clk(clk),
		.synchronized_i(dcache_req_sync),
		.address_i(dcache_addr),
		.data_o(cache_data),
		.access_i(dcache_load),
		.strand_i(dcache_req_strand),
		.cache_hit_o(dcache_hit),
		.load_complete_strands_o(dcache_load_complete_strands),
		.load_collision_o(dcache_load_collision),
		.store_update_set_i(store_update_set),
		.store_update_i(store_update),
		.l2req_valid(dcache_l2req_valid),
		.l2req_ack(l2req_ack && dcache_l2req_selected),
		.l2req_unit(dcache_l2req_unit),
		.l2req_strand(dcache_l2req_strand),
		.l2req_op(dcache_l2req_op),
		.l2req_way(dcache_l2req_way),
		.l2req_address(dcache_l2req_address),
		.l2req_data(dcache_l2req_data),
		.l2req_mask(dcache_l2req_mask),
		/*AUTOINST*/
					// Inputs
					.l2rsp_valid	(l2rsp_valid),
					.l2rsp_unit	(l2rsp_unit[1:0]),
					.l2rsp_strand	(l2rsp_strand[1:0]),
					.l2rsp_way	(l2rsp_way[1:0]),
					.l2rsp_data	(l2rsp_data[511:0]));

	wire[`L1_SET_INDEX_WIDTH - 1:0] requested_set = dcache_addr[10:6];
	wire[`L1_TAG_WIDTH - 1:0] 		requested_tag = dcache_addr[31:11];

	store_buffer store_buffer(
		.clk(clk),
		.strand_i(dcache_req_strand),
		.synchronized_i(dcache_req_sync),
		.data_o(stbuf_data),
		.mask_o(stbuf_mask),
		.rollback_o(stbuf_rollback),
		.l2req_valid(stbuf_l2req_valid),
		.l2req_ack(l2req_ack && stbuf_l2req_selected),
		.l2req_unit(stbuf_l2req_unit),
		.l2req_strand(stbuf_l2req_strand),
		.l2req_op(stbuf_l2req_op),
		.l2req_way(stbuf_l2req_way),
		.l2req_address(stbuf_l2req_address),
		.l2req_data(stbuf_l2req_data),
		.l2req_mask(stbuf_l2req_mask),
		/*AUTOINST*/
				  // Outputs
				  .store_resume_strands	(store_resume_strands[3:0]),
				  .store_update		(store_update),
				  .store_update_set	(store_update_set[`L1_SET_INDEX_WIDTH-1:0]),
				  // Inputs
				  .requested_tag	(requested_tag[`L1_TAG_WIDTH-1:0]),
				  .requested_set	(requested_set[`L1_SET_INDEX_WIDTH-1:0]),
				  .data_to_dcache	(data_to_dcache[511:0]),
				  .dcache_store		(dcache_store),
				  .dcache_flush		(dcache_flush),
				  .dcache_stbar		(dcache_stbar),
				  .dcache_store_mask	(dcache_store_mask[63:0]),
				  .l2rsp_valid		(l2rsp_valid),
				  .l2rsp_status		(l2rsp_status),
				  .l2rsp_unit		(l2rsp_unit[1:0]),
				  .l2rsp_strand		(l2rsp_strand[1:0]),
				  .l2rsp_update		(l2rsp_update));

	mask_unit store_buffer_raw_mux(
		.mask_i(stbuf_mask),
		.data0_i(cache_data),
		.data1_i(stbuf_data),
		.result_o(data_from_dcache));

	wire[3:0] dcache_resume_strands = dcache_load_complete_strands | store_resume_strands;

	pipeline pipeline(/*AUTOINST*/
			  // Outputs
			  .icache_addr		(icache_addr[31:0]),
			  .icache_request	(icache_request),
			  .icache_req_strand	(icache_req_strand[1:0]),
			  .dcache_addr		(dcache_addr[31:0]),
			  .dcache_load		(dcache_load),
			  .dcache_req_sync	(dcache_req_sync),
			  .dcache_store		(dcache_store),
			  .dcache_flush		(dcache_flush),
			  .dcache_stbar		(dcache_stbar),
			  .dcache_req_strand	(dcache_req_strand[1:0]),
			  .dcache_store_mask	(dcache_store_mask[63:0]),
			  .data_to_dcache	(data_to_dcache[511:0]),
			  .halt_o		(halt_o),
			  // Inputs
			  .clk			(clk),
			  .icache_data		(icache_data[31:0]),
			  .icache_hit		(icache_hit),
			  .icache_load_complete_strands(icache_load_complete_strands[3:0]),
			  .icache_load_collision(icache_load_collision),
			  .dcache_hit		(dcache_hit),
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
					    .icache_l2req_selected(icache_l2req_selected),
					    .dcache_l2req_selected(dcache_l2req_selected),
					    .stbuf_l2req_selected(stbuf_l2req_selected),
					    // Inputs
					    .clk		(clk),
					    .l2req_ack		(l2req_ack),
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
