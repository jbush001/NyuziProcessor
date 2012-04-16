//
// The pipeline, store buffer, L1 instruction/data caches, and L2 arbiter.
// The idea (eventually) is that this can be instantiated multiple times
// for multi-processing.
//

module core
	#(parameter					TAG_WIDTH = 21,
	parameter					SET_INDEX_WIDTH = 5)

	(input				clk,
	output 				pci_valid_o,
	input				pci_ack_i,
	output [1:0]		pci_strand_o,
	output [1:0]		pci_unit_o,
	output [2:0]		pci_op_o,
	output [1:0]		pci_way_o,
	output [25:0]		pci_address_o,
	output [511:0]		pci_data_o,
	output [63:0]		pci_mask_o,
	input 				cpi_valid_i,
	input				cpi_status_i,
	input [1:0]			cpi_unit_i,
	input [1:0]			cpi_strand_i,
	input [1:0]			cpi_op_i,
	input 				cpi_update_i,
	input [1:0]			cpi_way_i,
	input [511:0]		cpi_data_i,
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
	wire[63:0] 			dcache_write_mask;
	wire 				dcache_hit;
	wire 				dcache_write;
	wire				dcache_req_sync;
	wire[3:0]			dcache_resume_strand;
	wire[1:0]			cache_load_strand;
	wire				stbuf_rollback;
	wire[1:0]			dcache_req_strand;
	wire				unit0_valid;
	wire[1:0]			unit0_unit;
	wire[1:0]			unit0_strand;
	wire[2:0]			unit0_op;
	wire[1:0]			unit0_way;
	wire[25:0]			unit0_address;
	wire[511:0]			unit0_data;
	wire[63:0]			unit0_mask;
	wire				unit1_valid;
	wire[1:0]			unit1_unit;
	wire[1:0]			unit1_strand;
	wire[2:0]			unit1_op;
	wire[1:0]			unit1_way;
	wire[25:0]			unit1_address;
	wire[511:0]			unit1_data;
	wire[63:0]			unit1_mask;
	wire				unit2_valid;
	wire[1:0]			unit2_unit;
	wire[1:0]			unit2_strand;
	wire[2:0]			unit2_op;
	wire[1:0]			unit2_way;
	wire[25:0]			unit2_address;
	wire[511:0]			unit2_data;
	wire[63:0]			unit2_mask;
	wire[3:0]			load_complete_strands;
	wire[3:0]			store_resume_strands;
	wire[511:0]			cache_data;
	wire[SET_INDEX_WIDTH - 1:0] store_update_set;
	wire				store_update;
	wire[511:0]			stbuf_data;
	wire[63:0]			stbuf_mask;
	wire				unit0_selected;
	wire				unit1_selected;
	wire				unit2_selected;
	wire				dcache_load_collision;
	wire				icache_load_collision;
	wire[511:0]			l1i_data;
	reg[3:0]			l1i_lane_latched = 0;

	/*AUTOWIRE*/
	// Beginning of automatic wires (for undeclared instantiated-module outputs)
	wire		dcache_request;		// From p of pipeline.v
	// End of automatics

	l1_cache icache(
		.clk(clk),
		.synchronized_i(0),
		.store_update_set_i(5'd0),
		.store_update_i(0),
		.cpi_update_i(0),
		.address_i(icache_addr),
		.access_i(icache_request),
		.data_o(l1i_data),
		.cache_hit_o(icache_hit),
		.icache_load_collision(icache_load_complete_strands),
		.load_collision_o(icache_load_collision),
		.strand_i(icache_req_strand),
		.pci_valid_o(unit0_valid), 
		.pci_ack_i(pci_ack_i && unit0_selected),
		.pci_unit_o(unit0_unit),
		.pci_strand_o(unit0_strand),
		.pci_op_o(unit0_op),
		.pci_way_o(unit0_way),
		.pci_address_o(unit0_address),
		.pci_data_o(unit0_data),
		.pci_mask_o(unit0_mask),
		.cpi_valid_i(cpi_valid_i),
		.cpi_unit_i(cpi_unit_i),
		.cpi_strand_i(cpi_strand_i),
		.cpi_op_i(cpi_op_i),
		.cpi_way_i(cpi_way_i),
		.cpi_data_i(cpi_data_i));
	defparam icache.UNIT_ID = 2'd0;
	
	always @(posedge clk)
		l1i_lane_latched <= icache_addr[5:2];

	lane_select_mux lsm(
		.value_i(l1i_data),
		.lane_select_i(l1i_lane_latched),
		.value_o(icache_data));

	// Note: because we are no-write-allocate, we only set the access flag
	// if we are reading from the data cache.

	l1_cache dcache(
		.clk(clk),
		.synchronized_i(dcache_req_sync),
		.address_i(dcache_addr),
		.data_o(cache_data),
		.access_i(dcache_request & ~dcache_write),
		.strand_i(dcache_req_strand),
		.cache_hit_o(dcache_hit),
		.icache_load_collision(load_complete_strands),
		.load_collision_o(dcache_load_collision),
		.store_update_set_i(store_update_set),
		.store_update_i(store_update),
		.pci_valid_o(unit1_valid),
		.pci_ack_i(pci_ack_i && unit1_selected),
		.pci_unit_o(unit1_unit),
		.pci_strand_o(unit1_strand),
		.pci_op_o(unit1_op),
		.pci_way_o(unit1_way),
		.pci_address_o(unit1_address),
		.pci_data_o(unit1_data),
		.pci_mask_o(unit1_mask),
		.cpi_valid_i(cpi_valid_i),
		.cpi_unit_i(cpi_unit_i),
		.cpi_strand_i(cpi_strand_i),
		.cpi_op_i(cpi_op_i),
		.cpi_update_i(cpi_update_i),
		.cpi_way_i(cpi_way_i),
		.cpi_data_i(cpi_data_i));
	defparam dcache.UNIT_ID = 2'd1;

	wire[SET_INDEX_WIDTH - 1:0] requested_set = dcache_addr[10:6];
	wire[TAG_WIDTH - 1:0] 		requested_tag = dcache_addr[31:11];

	store_buffer stbuf(
		.clk(clk),
		.resume_strands_o(store_resume_strands),
		.strand_i(dcache_req_strand),
		.store_update_o(store_update),
		.store_update_set_o(store_update_set),
		.set_i(requested_set),
		.tag_i(requested_tag),
		.data_i(data_to_dcache),
		.write_i(dcache_write),
		.synchronized_i(dcache_req_sync),
		.mask_i(dcache_write_mask),
		.data_o(stbuf_data),
		.mask_o(stbuf_mask),
		.rollback_o(stbuf_rollback),
		.pci_valid_o(unit2_valid),
		.pci_ack_i(pci_ack_i && unit2_selected),
		.pci_unit_o(unit2_unit),
		.pci_strand_o(unit2_strand),
		.pci_op_o(unit2_op),
		.pci_way_o(unit2_way),
		.pci_address_o(unit2_address),
		.pci_data_o(unit2_data),
		.pci_mask_o(unit2_mask),
		.cpi_valid_i(cpi_valid_i),
		.cpi_status_i(cpi_status_i),
		.cpi_unit_i(cpi_unit_i),
		.cpi_strand_i(cpi_strand_i),
		.cpi_op_i(cpi_op_i),
		.cpi_update_i(cpi_update_i),
		.cpi_way_i(cpi_way_i),
		.cpi_data_i(cpi_data_i));

	mask_unit mu(
		.mask_i(stbuf_mask),
		.data0_i(stbuf_data),
		.data1_i(cache_data),
		.result_o(data_from_dcache));

	wire[3:0] dcache_resume_strands = load_complete_strands | store_resume_strands;

	pipeline p(/*AUTOINST*/
		   // Outputs
		   .icache_addr		(icache_addr[31:0]),
		   .icache_request	(icache_request),
		   .icache_req_strand	(icache_req_strand[1:0]),
		   .dcache_addr		(dcache_addr[31:0]),
		   .dcache_request	(dcache_request),
		   .dcache_req_sync	(dcache_req_sync),
		   .dcache_write	(dcache_write),
		   .dcache_req_strand	(dcache_req_strand[1:0]),
		   .dcache_write_mask	(dcache_write_mask[63:0]),
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

	l2_arbiter_mux l2arb(/*AUTOINST*/
			     // Outputs
			     .pci_valid_o	(pci_valid_o),
			     .pci_strand_o	(pci_strand_o[1:0]),
			     .pci_unit_o	(pci_unit_o[1:0]),
			     .pci_op_o		(pci_op_o[2:0]),
			     .pci_way_o		(pci_way_o[1:0]),
			     .pci_address_o	(pci_address_o[25:0]),
			     .pci_data_o	(pci_data_o[511:0]),
			     .pci_mask_o	(pci_mask_o[63:0]),
			     .unit0_selected	(unit0_selected),
			     .unit1_selected	(unit1_selected),
			     .unit2_selected	(unit2_selected),
			     // Inputs
			     .clk		(clk),
			     .pci_ack_i		(pci_ack_i),
			     .unit0_valid	(unit0_valid),
			     .unit0_strand	(unit0_strand[1:0]),
			     .unit0_unit	(unit0_unit[1:0]),
			     .unit0_op		(unit0_op[2:0]),
			     .unit0_way		(unit0_way[1:0]),
			     .unit0_address	(unit0_address[25:0]),
			     .unit0_data	(unit0_data[511:0]),
			     .unit0_mask	(unit0_mask[63:0]),
			     .unit1_valid	(unit1_valid),
			     .unit1_strand	(unit1_strand[1:0]),
			     .unit1_unit	(unit1_unit[1:0]),
			     .unit1_op		(unit1_op[2:0]),
			     .unit1_way		(unit1_way[1:0]),
			     .unit1_address	(unit1_address[25:0]),
			     .unit1_data	(unit1_data[511:0]),
			     .unit1_mask	(unit1_mask[63:0]),
			     .unit2_valid	(unit2_valid),
			     .unit2_strand	(unit2_strand[1:0]),
			     .unit2_unit	(unit2_unit[1:0]),
			     .unit2_op		(unit2_op[2:0]),
			     .unit2_way		(unit2_way[1:0]),
			     .unit2_address	(unit2_address[25:0]),
			     .unit2_data	(unit2_data[511:0]),
			     .unit2_mask	(unit2_mask[63:0]));
endmodule
