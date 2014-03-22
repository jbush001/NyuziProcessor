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

	(input                               clk,
	input                                reset,
	output                               halt_o,
	
	// Non-cacheable memory signals
	output                               io_write_en,
	output                               io_read_en,
	output[31:0]                         io_address,
	output[31:0]                         io_write_data,
	input [31:0]                         io_read_data,
	
	// L2 request interface
	input                                l2req_ready,
	output l2req_packet_t                l2req_packet,
	
	// L2 response interface
	input l2rsp_packet_t                 l2rsp_packet,
	
	// Performance counter events
	output                               pc_event_l1d_hit,
	output                               pc_event_l1d_miss,
	output                               pc_event_l1i_hit,
	output                               pc_event_l1i_miss,
	output                               pc_event_mispredicted_branch,
	output                               pc_event_instruction_issue,
	output                               pc_event_instruction_retire,
	output                               pc_event_uncond_branch,
	output                               pc_event_cond_branch_taken,
	output                               pc_event_cond_branch_not_taken,
	output                               pc_event_vector_ins_issue,
	output                               pc_event_mem_ins_issue);

	logic [`CACHE_LINE_BITS - 1:0] data_from_dcache;
	logic [`CACHE_LINE_BITS - 1:0] cache_data;
	logic [`CACHE_LINE_BITS - 1:0] stbuf_data;
	logic[31:0] icache_data;
	l2req_packet_t icache_l2req_packet;
	l2req_packet_t dcache_l2req_packet;
	l2req_packet_t stbuf_l2req_packet;
	logic dcache_hit;
	logic dcache_load_collision;

	/*AUTOWIRE*/
	// Beginning of automatic wires (for undeclared instantiated-module outputs)
	wire [`CACHE_LINE_BITS-1:0] data_to_dcache;// From pipeline of pipeline.v
	wire [25:0]	dcache_addr;		// From pipeline of pipeline.v
	wire		dcache_dinvalidate;	// From pipeline of pipeline.v
	wire		dcache_flush;		// From pipeline of pipeline.v
	wire		dcache_iinvalidate;	// From pipeline of pipeline.v
	wire		dcache_l2req_ready;	// From l2req_arbiter_mux of l2req_arbiter_mux.v
	wire		dcache_load;		// From pipeline of pipeline.v
	wire [`STRAND_INDEX_WIDTH-1:0] dcache_req_strand;// From pipeline of pipeline.v
	wire		dcache_req_sync;	// From pipeline of pipeline.v
	wire		dcache_stbar;		// From pipeline of pipeline.v
	wire		dcache_store;		// From pipeline of pipeline.v
	wire [`CACHE_LINE_BYTES-1:0] dcache_store_mask;// From pipeline of pipeline.v
	wire [31:0]	icache_addr;		// From pipeline of pipeline.v
	wire		icache_l2req_ready;	// From l2req_arbiter_mux of l2req_arbiter_mux.v
	wire [`STRAND_INDEX_WIDTH-1:0] icache_req_strand;// From pipeline of pipeline.v
	wire		icache_request;		// From pipeline of pipeline.v
	wire		stbuf_l2req_ready;	// From l2req_arbiter_mux of l2req_arbiter_mux.v
	logic [`STRANDS_PER_CORE-1:0] store_resume_strands;// From store_buffer of store_buffer.v
	// End of automatics

	logic[`CACHE_LINE_BITS - 1:0] l1i_data;
	logic icache_hit;
	logic icache_load_collision;
	logic [`STRANDS_PER_CORE - 1:0] icache_load_complete_strands;
	logic [`STRANDS_PER_CORE - 1:0] dcache_load_complete_strands;
	logic [`CACHE_LINE_BYTES - 1:0] stbuf_mask;
	logic stbuf_rollback;

	logic[3:0] l1i_lane_latched;

	l1_cache #(.UNIT_ID(UNIT_ICACHE), .CORE_ID(CORE_ID)) icache(
	    .l2req_packet(icache_l2req_packet),
	    .l2rsp_packet(l2rsp_packet),
	    .data_o(l1i_data),
	    .cache_hit_o(icache_hit),
	    .load_collision_o(icache_load_collision),
	    .load_complete_strands_o(icache_load_complete_strands), 
	    .pc_event_cache_hit	(pc_event_l1i_hit), 
	    .pc_event_cache_miss(pc_event_l1i_miss),
	    .access_i(icache_request),
	    .request_addr(icache_addr[31:6]),
		.strand_i(icache_req_strand),
	    .synchronized_i(1'b0),
	    .l2req_ready(icache_l2req_ready),
		.*);
	
	always_ff @(posedge clk, posedge reset)
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

	/* multiplexer AUTO_TEMPLATE(
		.in(l1i_data),
		.select(l1i_lane_latched),
		.out(icache_data));
	*/
	multiplexer #(.WIDTH(32), .NUM_INPUTS(16), .ASCENDING_INDEX(1)) instruction_select_mux(
		/*AUTOINST*/
											       // Outputs
											       .out		(icache_data),	 // Templated
											       // Inputs
											       .in		(l1i_data),	 // Templated
											       .select		(l1i_lane_latched)); // Templated


	l1_cache #(.UNIT_ID(UNIT_DCACHE), .CORE_ID(CORE_ID)) dcache(
	    .l2req_packet(dcache_l2req_packet),
	    .data_o(cache_data), 
	    .cache_hit_o(dcache_hit),
	    .load_collision_o(dcache_load_collision),
	 	.load_complete_strands_o(dcache_load_complete_strands),
	    .pc_event_cache_hit	(pc_event_l1d_hit),
	    .pc_event_cache_miss(pc_event_l1d_miss),
	    .access_i(dcache_load),
	    .request_addr(dcache_addr[25:0]),
	    .strand_i(dcache_req_strand[`STRAND_INDEX_WIDTH-1:0]),
	    .synchronized_i(dcache_req_sync),
	    .l2req_ready(dcache_l2req_ready),
		.*);

	store_buffer #(.CORE_ID(CORE_ID)) store_buffer(
		.l2req_packet(stbuf_l2req_packet),
		.l2rsp_packet(l2rsp_packet),
		.data_o(stbuf_data),
		.mask_o(stbuf_mask),
		.rollback_o(stbuf_rollback),
		.request_addr(dcache_addr),
		.synchronized_i(dcache_req_sync), 
		.strand_i(dcache_req_strand[`STRAND_INDEX_WIDTH-1:0]), 
		.l2req_ready(stbuf_l2req_ready),
		.*);

	// Note: don't use [] in params because array instantiation confuses
	// AUTO_TEMPLATE.
	/* mask_unit AUTO_TEMPLATE(
		.mask_i(stbuf_mask),
		.data0_i(cache_data),
		.data1_i(stbuf_data),
		.result_o(data_from_dcache));
	*/
	mask_unit store_buffer_raw_mux[`CACHE_LINE_BYTES - 1:0] (
		/*AUTOINST*/
								 // Outputs
								 .result_o		(data_from_dcache), // Templated
								 // Inputs
								 .mask_i		(stbuf_mask),	 // Templated
								 .data0_i		(cache_data),	 // Templated
								 .data1_i		(stbuf_data));	 // Templated

	wire[`STRANDS_PER_CORE - 1:0] dcache_resume_strands = dcache_load_complete_strands | store_resume_strands;

	pipeline #(.CORE_ID(CORE_ID)) pipeline(/*AUTOINST*/
					       // Outputs
					       .halt_o		(halt_o),
					       .icache_addr	(icache_addr[31:0]),
					       .icache_request	(icache_request),
					       .icache_req_strand(icache_req_strand[`STRAND_INDEX_WIDTH-1:0]),
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
					       .dcache_req_strand(dcache_req_strand[`STRAND_INDEX_WIDTH-1:0]),
					       .dcache_store_mask(dcache_store_mask[`CACHE_LINE_BYTES-1:0]),
					       .data_to_dcache	(data_to_dcache[`CACHE_LINE_BITS-1:0]),
					       .pc_event_mispredicted_branch(pc_event_mispredicted_branch),
					       .pc_event_instruction_issue(pc_event_instruction_issue),
					       .pc_event_instruction_retire(pc_event_instruction_retire),
					       .pc_event_uncond_branch(pc_event_uncond_branch),
					       .pc_event_cond_branch_taken(pc_event_cond_branch_taken),
					       .pc_event_cond_branch_not_taken(pc_event_cond_branch_not_taken),
					       .pc_event_vector_ins_issue(pc_event_vector_ins_issue),
					       .pc_event_mem_ins_issue(pc_event_mem_ins_issue),
					       // Inputs
					       .clk		(clk),
					       .reset		(reset),
					       .icache_data	(icache_data[31:0]),
					       .icache_hit	(icache_hit),
					       .icache_load_complete_strands(icache_load_complete_strands[`STRANDS_PER_CORE-1:0]),
					       .icache_load_collision(icache_load_collision),
					       .io_read_data	(io_read_data[31:0]),
					       .dcache_hit	(dcache_hit),
					       .stbuf_rollback	(stbuf_rollback),
					       .data_from_dcache(data_from_dcache[`CACHE_LINE_BITS-1:0]),
					       .dcache_resume_strands(dcache_resume_strands[`STRANDS_PER_CORE-1:0]),
					       .dcache_load_collision(dcache_load_collision));

	l2req_arbiter_mux l2req_arbiter_mux(/*AUTOINST*/
					    // Outputs
					    .l2req_packet	(l2req_packet),
					    .icache_l2req_ready	(icache_l2req_ready),
					    .dcache_l2req_ready	(dcache_l2req_ready),
					    .stbuf_l2req_ready	(stbuf_l2req_ready),
					    // Inputs
					    .clk		(clk),
					    .reset		(reset),
					    .l2req_ready	(l2req_ready),
					    .icache_l2req_packet(icache_l2req_packet),
					    .dcache_l2req_packet(dcache_l2req_packet),
					    .stbuf_l2req_packet	(stbuf_l2req_packet));
endmodule

// Local Variables:
// verilog-typedef-regexp:"_t$"
// End:

