module core
	#(parameter					TAG_WIDTH = 21,
	parameter					SET_INDEX_WIDTH = 5)

	(input				clk,
	output 				pci_valid_o,
	input				pci_ack_i,
	output [3:0]		pci_id_o,
	output [1:0]		pci_op_o,
	output [1:0]		pci_way_o,
	output [25:0]		pci_address_o,
	output [511:0]		pci_data_o,
	output [63:0]		pci_mask_o,
	input 				cpi_valid_i,
	input [3:0]			cpi_id_i,
	input [1:0]			cpi_op_i,
	input 				cpi_update_i,
	input [1:0]			cpi_way_i,
	input [511:0]		cpi_data_i,
	output				halt_o);

	wire[31:0] 			iaddr;
	wire[31:0] 			idata;
	wire 				iaccess;
	wire 				icache_hit;
	wire[31:0] 			daddr;
	wire[511:0] 		ddata_to_mem;
	wire[511:0] 		ddata_from_mem;
	wire[63:0] 			dwrite_mask;
	wire 				dcache_hit;
	wire 				dwrite;
	wire 				daccess;
	wire[3:0]			dcache_resume_strand;
	wire[1:0]			cache_load_strand;
	wire				stbuf_full;
	wire[1:0]			dstrand;
	wire				unit0_valid;
	wire[3:0]			unit0_id;
	wire[1:0]			unit0_op;
	wire[1:0]			unit0_way;
	wire[25:0]			unit0_address;
	wire[511:0]			unit0_data;
	wire[63:0]			unit0_mask;
	wire				unit1_valid;
	wire[3:0]			unit1_id;
	wire[1:0]			unit1_op;
	wire[1:0]			unit1_way;
	wire[25:0]			unit1_address;
	wire[511:0]			unit1_data;
	wire[63:0]			unit1_mask;
	wire				unit2_valid;
	wire[3:0]			unit2_id;
	wire[1:0]			unit2_op;
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
	wire				load_collision;
	wire[511:0]			l1i_data;
	reg[3:0]			l1i_lane_latched = 0;

	l1_cache icache(
		.clk(clk),
		.write_i(0),
		.store_update_set_i(5'd0),
		.store_update_i(0),
		.cpi_update_i(0),
		.address_i(iaddr),
		.access_i(iaccess),
		.data_o(l1i_data),
		.cache_hit_o(icache_hit),
		.load_complete_strands_o(),
		.strand_i(2'd0), // XXX
		.pci_valid_o(unit0_valid),
		.pci_ack_i(pci_ack_i && unit0_selected),
		.pci_id_o(unit0_id),
		.pci_op_o(unit0_op),
		.pci_way_o(unit0_way),
		.pci_address_o(unit0_address),
		.pci_data_o(unit0_data),
		.pci_mask_o(unit0_mask),
		.cpi_valid_i(cpi_valid_i),
		.cpi_id_i(cpi_id_i),
		.cpi_op_i(cpi_op_i),
		.cpi_way_i(cpi_way_i),
		.cpi_data_i(cpi_data_i));
	defparam icache.UNIT_ID = 2'd0;
	
	always @(posedge clk)
		l1i_lane_latched <= iaddr[5:2];

	lane_select_mux lsm(
		.value_i(l1i_data),
		.lane_select_i(l1i_lane_latched),
		.value_o(idata));

	l1_cache dcache(
		.clk(clk),
		.address_i(daddr),
		.data_o(cache_data),
		.access_i(daccess),
		.write_i(dwrite),
		.strand_i(dstrand),
		.cache_hit_o(dcache_hit),
		.load_complete_strands_o(load_complete_strands),
		.load_collision_o(load_collision),
		.store_update_set_i(store_update_set),
		.store_update_i(store_update),
		.pci_valid_o(unit1_valid),
		.pci_ack_i(pci_ack_i && unit1_selected),
		.pci_id_o(unit1_id),
		.pci_op_o(unit1_op),
		.pci_way_o(unit1_way),
		.pci_address_o(unit1_address),
		.pci_data_o(unit1_data),
		.pci_mask_o(unit1_mask),
		.cpi_valid_i(cpi_valid_i),
		.cpi_id_i(cpi_id_i),
		.cpi_op_i(cpi_op_i),
		.cpi_update_i(cpi_update_i),
		.cpi_way_i(cpi_way_i),
		.cpi_data_i(cpi_data_i));
	defparam dcache.UNIT_ID = 2'd1;

	wire[SET_INDEX_WIDTH - 1:0] requested_set = daddr[10:6];
	wire[TAG_WIDTH - 1:0] 		requested_tag = daddr[31:11];

	store_buffer stbuf(
		.clk(clk),
		.resume_strands_o(store_resume_strands),
		.strand_id_i(dstrand),
		.store_update_o(store_update),
		.store_update_set_o(store_update_set),
		.set_i(requested_set),
		.tag_i(requested_tag),
		.data_i(ddata_to_mem),
		.write_i(dwrite),
		.mask_i(dwrite_mask),
		.data_o(stbuf_data),
		.mask_o(stbuf_mask),
		.full_o(stbuf_full),
		.pci_valid_o(unit2_valid),
		.pci_ack_i(pci_ack_i && unit2_selected),
		.pci_id_o(unit2_id),
		.pci_op_o(unit2_op),
		.pci_way_o(unit2_way),
		.pci_address_o(unit2_address),
		.pci_data_o(unit2_data),
		.pci_mask_o(unit2_mask),
		.cpi_valid_i(cpi_valid_i),
		.cpi_id_i(cpi_id_i),
		.cpi_op_i(cpi_op_i),
		.cpi_update_i(cpi_update_i),
		.cpi_way_i(cpi_way_i),
		.cpi_data_i(cpi_data_i));

	mask_unit mu(
		.mask_i(stbuf_mask),
		.data0_i(stbuf_data),
		.data1_i(cache_data),
		.result_o(ddata_from_mem));

	wire[3:0] dcache_resume_strands = load_complete_strands | store_resume_strands;

	pipeline p(
		.clk(clk),
		.iaddress_o(iaddr),
		.idata_i(idata),
		.iaccess_o(iaccess),
		.icache_hit_i(icache_hit),
		.dcache_hit_i(dcache_hit),
		.daddress_o(daddr),
		.ddata_i(ddata_from_mem),
		.ddata_o(ddata_to_mem),
		.dstrand_o(dstrand),
		.dwrite_o(dwrite),
		.daccess_o(daccess),
		.dwrite_mask_o(dwrite_mask),
		.dstbuf_full_i(stbuf_full),
		.dcache_resume_strands_i(dcache_resume_strands),
		.dload_collision_i(load_collision),
		.halt_o(halt_o));

	l2_arbiter_mux l2arb(
		.clk(clk),
		.unit0_selected(unit0_selected),
		.unit1_selected(unit1_selected),
		.unit2_selected(unit2_selected),
		.pci_valid_o(pci_valid_o),
		.pci_ack_i(pci_ack_i),
		.pci_id_o(pci_id_o),
		.pci_op_o(pci_op_o),
		.pci_way_o(pci_way_o),
		.pci_address_o(pci_address_o),
		.pci_data_o(pci_data_o),
		.pci_mask_o(pci_mask_o),
		.unit0_valid(unit0_valid),
		.unit0_id(unit0_id),
		.unit0_op(unit0_op),
		.unit0_way(unit0_way),
		.unit0_address(unit0_address),
		.unit0_data(unit0_data),
		.unit0_mask(unit0_mask),
		.unit1_valid(unit1_valid),
		.unit1_id(unit1_id),
		.unit1_op(unit1_op),
		.unit1_way(unit1_way),
		.unit1_address(unit1_address),
		.unit1_data(unit1_data),
		.unit1_mask(unit1_mask),
		.unit2_valid(unit2_valid),
		.unit2_id(unit2_id),
		.unit2_op(unit2_op),
		.unit2_way(unit2_way),
		.unit2_address(unit2_address),
		.unit2_data(unit2_data),
		.unit2_mask(unit2_mask));
endmodule