module l1_data_cache_test;

	reg 				clk;
	reg[31:0] 			cache_addr;
	wire[511:0]			data_from_l1;
	reg[511:0]			data_to_l1;
	reg					cache_write;
	reg					cache_access;
	reg[63:0]			write_mask;
	wire				cache_hit;
	wire 				l2_write;
	wire				l2_read;
	reg					l2_ack;
	wire[31:0]			l2_addr;
	reg[511:0]			data_from_l2;
	wire[511:0]			data_to_l2;

	data_cache cache(
		.clk(clk),
		.address_i(cache_addr),
		.data_o(data_from_l1),
		.data_i(data_to_l1),
		.write_i(cache_write),
		.access_i(cache_access),
		.write_mask_i(write_mask),
		.cache_hit_o(cache_hit),
		.l2_write_o(l2_write),
		.l2_read_o(l2_read),
		.l2_ack_i(l2_ack),
		.l2_addr_o(l2_addr),
		.l2_data_i(data_from_l2),
		.l2_data_o(data_to_l2));

	initial
	begin
		// Preliminaries, set up variables
		clk = 0;	
		cache_addr = 0;
		data_to_l1 = 0;
		cache_write = 0;
		cache_access = 0;
		write_mask = 0;
		l2_ack = 0;
		data_from_l2 = 0;
		
		// Test proper
		
	
	
		$display("test complete");
	end
endmodule
