//
// The pipeline, store buffer, L1 instruction/data caches, and L2 arbiter.
// The idea (eventually) is that this can be instantiated multiple times
// for multi-processing.
//

`include "l2_cache.h"

module core
	(input				clk,
	output 				pci_valid,
	input				pci_ack,
	output [1:0]		pci_strand,
	output [1:0]		pci_unit,
	output [2:0]		pci_op,
	output [1:0]		pci_way,
	output [25:0]		pci_address,
	output [511:0]		pci_data,
	output [63:0]		pci_mask,
	input 				cpi_valid,
	input				cpi_status,
	input [1:0]			cpi_unit,
	input [1:0]			cpi_strand,
	input [1:0]			cpi_op,
	input 				cpi_update,
	input [1:0]			cpi_way,
	input [511:0]		cpi_data,
	output				halt_o);

	wire[31:0] 			icache_addr;
	wire[31:0] 			icache_data;
	wire 				icache_request;
	wire 				icache_hit;
	wire [1:0]			icache_req_strand;
	wire [3:0]			icache_load_complete_strands;
	wire[31:0] 			dcache_addr;
	wire[511:0] 		data_to_dcache;
	wire[511:0] 		data_from_dcache;
	wire[63:0] 			dcache_store_mask;
	wire 				dcache_hit;
	wire 				dcache_store;
	wire				dcache_req_sync;
	wire[3:0]			dcache_resume_strand;
	wire[1:0]			cache_load_strand;
	wire				stbuf_rollback;
	wire[1:0]			dcache_req_strand;
	wire				icache_pci_valid;
	wire[1:0]			icache_pci_unit;
	wire[1:0]			icache_pci_strand;
	wire[2:0]			icache_pci_op;
	wire[1:0]			icache_pci_way;
	wire[25:0]			icache_pci_address;
	wire[511:0]			icache_pci_data;
	wire[63:0]			icache_pci_mask;
	wire				dcache_pci_valid;
	wire[1:0]			dcache_pci_unit;
	wire[1:0]			dcache_pci_strand;
	wire[2:0]			dcache_pci_op;
	wire[1:0]			dcache_pci_way;
	wire[25:0]			dcache_pci_address;
	wire[511:0]			dcache_pci_data;
	wire[63:0]			dcache_pci_mask;
	wire				stbuf_pci_valid;
	wire[1:0]			stbuf_pci_unit;
	wire[1:0]			stbuf_pci_strand;
	wire[2:0]			stbuf_pci_op;
	wire[1:0]			stbuf_pci_way;
	wire[25:0]			stbuf_pci_address;
	wire[511:0]			stbuf_pci_data;
	wire[63:0]			stbuf_pci_mask;
	wire[3:0]			dcache_load_complete_strands;
	wire[3:0]			store_resume_strands;
	wire[511:0]			cache_data;
	wire[`L1_SET_INDEX_WIDTH - 1:0] store_update_set;
	wire				store_update;
	wire[511:0]			stbuf_data;
	wire[63:0]			stbuf_mask;
	wire				icache_pci_selected;
	wire				dcache_pci_selected;
	wire				stbuf_pci_selected;
	wire				dcache_load_collision;
	wire				icache_load_collision;
	wire[511:0]			l1i_data;
	reg[3:0]			l1i_lane_latched = 0;

	/*AUTOWIRE*/
	// Beginning of automatic wires (for undeclared instantiated-module outputs)
	wire		dcache_request;		// From pipeline of pipeline.v
	// End of automatics

	l1_cache #(`UNIT_ICACHE) icache(
		.clk(clk),
		.synchronized_i(0),
		.store_update_set_i(5'd0),
		.store_update_i(0),
		.cpi_update(0),
		.address_i(icache_addr),
		.access_i(icache_request),
		.data_o(l1i_data),
		.cache_hit_o(icache_hit),
		.load_complete_strands_o(icache_load_complete_strands),
		.load_collision_o(icache_load_collision),
		.strand_i(icache_req_strand),
		.pci_valid(icache_pci_valid), 
		.pci_ack(pci_ack && icache_pci_selected),
		.pci_unit(icache_pci_unit),
		.pci_strand(icache_pci_strand),
		.pci_op(icache_pci_op),
		.pci_way(icache_pci_way),
		.pci_address(icache_pci_address),
		.pci_data(icache_pci_data),
		.pci_mask(icache_pci_mask),
		/*AUTOINST*/
					// Inputs
					.cpi_valid	(cpi_valid),
					.cpi_unit	(cpi_unit[1:0]),
					.cpi_strand	(cpi_strand[1:0]),
					.cpi_op		(cpi_op[1:0]),
					.cpi_way	(cpi_way[1:0]),
					.cpi_data	(cpi_data[511:0]));
	
	always @(posedge clk)
		l1i_lane_latched <= #1 icache_addr[5:2];

	lane_select_mux instruction_select_mux(
		.value_i(l1i_data),
		.lane_select_i(4'd15 - l1i_lane_latched),
		.value_o(icache_data));

	// Note: because we are no-write-allocate, we only set the access flag
	// if we are reading from the data cache.

	l1_cache #(`UNIT_DCACHE) dcache(
		.clk(clk),
		.synchronized_i(dcache_req_sync),
		.address_i(dcache_addr),
		.data_o(cache_data),
		.access_i(dcache_request & ~dcache_store),
		.strand_i(dcache_req_strand),
		.cache_hit_o(dcache_hit),
		.load_complete_strands_o(dcache_load_complete_strands),
		.load_collision_o(dcache_load_collision),
		.store_update_set_i(store_update_set),
		.store_update_i(store_update),
		.pci_valid(dcache_pci_valid),
		.pci_ack(pci_ack && dcache_pci_selected),
		.pci_unit(dcache_pci_unit),
		.pci_strand(dcache_pci_strand),
		.pci_op(dcache_pci_op),
		.pci_way(dcache_pci_way),
		.pci_address(dcache_pci_address),
		.pci_data(dcache_pci_data),
		.pci_mask(dcache_pci_mask),
		/*AUTOINST*/
					// Inputs
					.cpi_valid	(cpi_valid),
					.cpi_unit	(cpi_unit[1:0]),
					.cpi_strand	(cpi_strand[1:0]),
					.cpi_op		(cpi_op[1:0]),
					.cpi_update	(cpi_update),
					.cpi_way	(cpi_way[1:0]),
					.cpi_data	(cpi_data[511:0]));

	wire[`L1_SET_INDEX_WIDTH - 1:0] requested_set = dcache_addr[10:6];
	wire[`L1_TAG_WIDTH - 1:0] 		requested_tag = dcache_addr[31:11];

	store_buffer store_buffer(
		.clk(clk),
		.strand_i(dcache_req_strand),
		.synchronized_i(dcache_req_sync),
		.data_o(stbuf_data),
		.mask_o(stbuf_mask),
		.rollback_o(stbuf_rollback),
		.pci_valid(stbuf_pci_valid),
		.pci_ack(pci_ack && stbuf_pci_selected),
		.pci_unit(stbuf_pci_unit),
		.pci_strand(stbuf_pci_strand),
		.pci_op(stbuf_pci_op),
		.pci_way(stbuf_pci_way),
		.pci_address(stbuf_pci_address),
		.pci_data(stbuf_pci_data),
		.pci_mask(stbuf_pci_mask),
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
				  .dcache_store_mask	(dcache_store_mask[63:0]),
				  .cpi_valid		(cpi_valid),
				  .cpi_status		(cpi_status),
				  .cpi_unit		(cpi_unit[1:0]),
				  .cpi_strand		(cpi_strand[1:0]),
				  .cpi_op		(cpi_op[1:0]),
				  .cpi_update		(cpi_update),
				  .cpi_way		(cpi_way[1:0]),
				  .cpi_data		(cpi_data[511:0]));

	mask_unit store_buffer_raw_mux(
		.mask_i(stbuf_mask),
		.data0_i(stbuf_data),
		.data1_i(cache_data),
		.result_o(data_from_dcache));

	wire[3:0] dcache_resume_strands = dcache_load_complete_strands | store_resume_strands;

	pipeline pipeline(/*AUTOINST*/
			  // Outputs
			  .icache_addr		(icache_addr[31:0]),
			  .icache_request	(icache_request),
			  .icache_req_strand	(icache_req_strand[1:0]),
			  .dcache_addr		(dcache_addr[31:0]),
			  .dcache_request	(dcache_request),
			  .dcache_req_sync	(dcache_req_sync),
			  .dcache_store		(dcache_store),
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

	l2_arbiter_mux l2_arbiter_mux(/*AUTOINST*/
				      // Outputs
				      .pci_valid	(pci_valid),
				      .pci_strand	(pci_strand[1:0]),
				      .pci_unit		(pci_unit[1:0]),
				      .pci_op		(pci_op[2:0]),
				      .pci_way		(pci_way[1:0]),
				      .pci_address	(pci_address[25:0]),
				      .pci_data		(pci_data[511:0]),
				      .pci_mask		(pci_mask[63:0]),
				      .icache_pci_selected(icache_pci_selected),
				      .dcache_pci_selected(dcache_pci_selected),
				      .stbuf_pci_selected(stbuf_pci_selected),
				      // Inputs
				      .clk		(clk),
				      .pci_ack		(pci_ack),
				      .icache_pci_valid	(icache_pci_valid),
				      .icache_pci_strand(icache_pci_strand[1:0]),
				      .icache_pci_unit	(icache_pci_unit[1:0]),
				      .icache_pci_op	(icache_pci_op[2:0]),
				      .icache_pci_way	(icache_pci_way[1:0]),
				      .icache_pci_address(icache_pci_address[25:0]),
				      .icache_pci_data	(icache_pci_data[511:0]),
				      .icache_pci_mask	(icache_pci_mask[63:0]),
				      .dcache_pci_valid	(dcache_pci_valid),
				      .dcache_pci_strand(dcache_pci_strand[1:0]),
				      .dcache_pci_unit	(dcache_pci_unit[1:0]),
				      .dcache_pci_op	(dcache_pci_op[2:0]),
				      .dcache_pci_way	(dcache_pci_way[1:0]),
				      .dcache_pci_address(dcache_pci_address[25:0]),
				      .dcache_pci_data	(dcache_pci_data[511:0]),
				      .dcache_pci_mask	(dcache_pci_mask[63:0]),
				      .stbuf_pci_valid	(stbuf_pci_valid),
				      .stbuf_pci_strand	(stbuf_pci_strand[1:0]),
				      .stbuf_pci_unit	(stbuf_pci_unit[1:0]),
				      .stbuf_pci_op	(stbuf_pci_op[2:0]),
				      .stbuf_pci_way	(stbuf_pci_way[1:0]),
				      .stbuf_pci_address(stbuf_pci_address[25:0]),
				      .stbuf_pci_data	(stbuf_pci_data[511:0]),
				      .stbuf_pci_mask	(stbuf_pci_mask[63:0]));
endmodule
