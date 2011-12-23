module core(
	input			clk,
	output 			port0_read_o,
	input 			port0_ack_i,
	output [25:0] 	port0_addr_o,
	input [511:0] 	port0_data_i,
	output 			port1_write_o,
	input 			port1_ack_i,
	output [25:0] 	port1_addr_o,
	output [511:0] 	port1_data_o,
	output [63:0] 	port1_mask_o,
	output 			port2_read_o,
	input 			port2_ack_i,
	output [25:0] 	port2_addr_o,
	input [511:0] 	port2_data_i,
	output			halt_o);

	wire[31:0] 		iaddr;
	wire[31:0] 		idata;
	wire 			iaccess;
	wire 			icache_hit;
	wire[31:0] 		daddr;
	wire[511:0] 	ddata_to_mem;
	wire[511:0] 	ddata_from_mem;
	wire[63:0] 		dwrite_mask;
	wire 			dcache_hit;
	wire 			dwrite;
	wire 			daccess;
	wire[3:0]		dcache_load_complete;
	wire[1:0]		cache_load_strand;
	wire 			stbuf_full;
	wire[1:0]		dstrand;

	l1_instruction_cache icache(
		.clk(clk),
		.address_i(iaddr),
		.access_i(iaccess),
		.data_o(idata),
		.cache_hit_o(icache_hit),
		.cache_load_complete_o(),
		.l2_read_o(port2_read_o),
		.l2_ack_i(port2_ack_i),
		.l2_addr_o(port2_addr_o),
		.l2_data_i(port2_data_i));

	l1_data_cache dcache(
		.clk(clk),
		.address_i(daddr),
		.data_o(ddata_from_mem),
		.data_i(ddata_to_mem),
		.write_i(dwrite),
		.access_i(daccess),
		.strand_i(dstrand),
		.write_mask_i(dwrite_mask),
		.cache_hit_o(dcache_hit),
		.stbuf_full_o(stbuf_full),
		.cache_load_complete_o(dcache_load_complete),
		.l2port0_read_o(port0_read_o),
		.l2port0_ack_i(port0_ack_i),
		.l2port0_addr_o(port0_addr_o),
		.l2port0_data_i(port0_data_i),
		.l2port1_write_o(port1_write_o),
		.l2port1_ack_i(port1_ack_i),
		.l2port1_addr_o(port1_addr_o),
		.l2port1_data_o(port1_data_o),
		.l2port1_mask_o(port1_mask_o));

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
		.dcache_load_complete_i(dcache_load_complete),
		.halt_o(halt_o));

endmodule