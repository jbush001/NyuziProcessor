module l1_instruction_cache_test;

	reg 				clk;
	reg[31:0] 			cache_addr;
	wire[511:0]			data_from_l1;
	reg					cache_access;
	wire				cache_hit;
	wire				l2_port0_read;
	reg					l2_port0_ack;
	wire[25:0]			l2_port0_addr;
	reg[511:0]			data_from_l2_port0;

	l1_instruction_cache cache(
		.clk(clk),
		.address_i(cache_addr),
		.access_i(cache_access),
		.data_o(data_from_l1),
		.cache_hit_o(cache_hit),
		.l2_read_o(l2_port0_read),
		.l2_ack_i(l2_port0_ack),
		.l2_addr_o(l2_port0_addr),
		.l2_data_i(data_from_l2_port0));

	task do_cache_read_miss;
		input[31:0] address;
		input[31:0] expected;
	begin
		$display("do_cache_read_miss %x", address);

		cache_addr = address;
		cache_access = 1;
		#5 clk = 1;
		#5 clk = 0;
		if (cache_hit !== 0)
		begin
			$display("error: should not be cache hit");
			$finish;
		end
		
		cache_access = 0;
		if (l2_port0_read)
		begin
			$display("error: premature l2 cache access");
			$finish;
		end
		
		#5 clk = 1;
		#5 clk = 0;

		#5 clk = 1;
		#5 clk = 0;

		if (!l2_port0_read)
		begin
			$display("error: No l2 cache read access %b", l2_port0_read);
			$finish;
		end
		
		if (l2_port0_addr !== (address >> 6))
		begin
			$display("error: bad l2 read address %08x", l2_port0_addr);
			$finish;
		end
		
		// Wait a few cycles for l2 acknowledgement
		#5 clk = 1;
		#5 clk = 0;

		#5 clk = 1;
		#5 clk = 0;

		#5 clk = 1;
		#5 clk = 0;

		l2_port0_ack = 1;
		data_from_l2_port0 = {16{expected}};
		
		#5 clk = 1;
		#5 clk = 0;

		l2_port0_ack = 0;
		if (l2_port0_read)
		begin
			$display("error: l2 read not complete %b", l2_port0_read);
			$finish;
		end
	end
	endtask

	task do_cache_read_hit;
		input[31:0] address;
		input[31:0] expected;
	begin
		$display("do_cache_read_hit %x", address);
	
		cache_addr = address;
		cache_access = 1;
		#5 clk = 1;
		#5 clk = 0;
		if (cache_hit !== 1)
		begin
			$display("error: no cache hit");
			$finish;
		end

		if (data_from_l1 !== {16{expected}})
		begin
			$display("error: bad data from L1 cache %x", data_from_l1);
			$finish;
		end
		
		cache_access = 0;
		if (l2_port0_read)
		begin
			$display("error: unexpected l2 cache access 1 %b", l2_port0_read);
			$finish;
		end
		
		#5 clk = 1;
		#5 clk = 0;
		if (l2_port0_read)
		begin
			$display("error: unexpected l2 cache access 2 %b", l2_port0_read);
			$finish;
		end
	end
	endtask

	initial
	begin
		// Preliminaries, set up variables
		clk = 0;	
		cache_addr = 0;
		cache_access = 0;
		l2_port0_ack = 0;
		data_from_l2_port0 = 0;

		$dumpfile("trace.vcd");
		$dumpvars(100, cache);
		
		// Load into set 1
		do_cache_read_miss('h1040, 32'hcc339966);
		
		// Load items into set 0
		do_cache_read_miss('h1000, 32'hdeadbeef);
		do_cache_read_miss('h2000, 32'h12345678);
		do_cache_read_miss('h3000, 32'ha5a5a5a5);
		do_cache_read_miss('h4000, 32'hbcde0123);

		// These will all be hits
		do_cache_read_hit('h1000, 32'hdeadbeef);
		do_cache_read_hit('h2000, 32'h12345678);
		do_cache_read_hit('h3000, 32'ha5a5a5a5);
		do_cache_read_hit('h4000, 32'hbcde0123);

		// Force eviction of one of the lines
		do_cache_read_miss('h5000, 32'hcdef1234);

		// Verify the line in set1 is still okay
		do_cache_read_hit('h1040, 32'hcc339966);
		
		$display("test complete");
	end
endmodule
