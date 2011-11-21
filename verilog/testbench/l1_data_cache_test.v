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


	task do_cache_read_miss;
		input[31:0] address;
		input[31:0] expected;
		input writeback;
		input[31:0] writeback_addr;
		input[31:0] writeback_data;
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
		if (l2_write || l2_read)
		begin
			$display("error: premature l2 cache access");
			$finish;
		end
		
		#5 clk = 1;
		#5 clk = 0;

		#5 clk = 1;
		#5 clk = 0;

		if (writeback)
		begin
			if (!l2_write || l2_read)
			begin
				$display("error: No l2 cache write access");
				$finish;
			end
			
			if (l2_addr !== writeback_addr)
			begin
				$display("error: bad l2 write address %08x", l2_addr);
				$finish;
			end
		
			#5 clk = 1;
			#5 clk = 0;
		
			l2_ack = 1;
		
			if (data_to_l2 !== {16{writeback_data}})
			begin
				$display("error: bad data written back to L2 cache %x", data_to_l2);
				$finish;
			end

			#5 clk = 1;
			#5 clk = 0;

			l2_ack = 0;

			#5 clk = 1;
			#5 clk = 0;
		end

		if (!l2_read || l2_write)
		begin
			$display("error: No l2 cache read access %b%b", l2_read, l2_write);
			$finish;
		end
		
		if (l2_addr !== address)
		begin
			$display("error: bad l2 read address %08x", l2_addr);
			$finish;
		end
		
		// Wait a few cycles for l2 acknowledgement
		#5 clk = 1;
		#5 clk = 0;

		#5 clk = 1;
		#5 clk = 0;

		#5 clk = 1;
		#5 clk = 0;

		l2_ack = 1;
		data_from_l2 = {16{expected}};
		
		#5 clk = 1;
		#5 clk = 0;

		l2_ack = 0;
		if (l2_read || l2_write)
		begin
			$display("error: l2 read not complete %b%b", l2_read, l2_write);
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
		
		#5 clk = 1;
		#5 clk = 0;

		if (data_from_l1 !== {16{expected}})
		begin
			$display("error: bad data from L1 cache %x", data_from_l1);
			$finish;
		end
		
		cache_access = 0;
		if (l2_write || l2_read)
		begin
			$display("error: unexpected l2 cache access 1 %b%b", l2_write, l2_read);
			$finish;
		end
		
		#5 clk = 1;
		#5 clk = 0;
		if (l2_write || l2_read)
		begin
			$display("error: unexpected l2 cache access 2 %b%b", l2_write, l2_read);
			$finish;
		end
	end
	endtask

	task do_cache_write_hit;
		input[31:0] address;
		input[31:0] value_to_write;
	begin
		$display("do_cache_write_hit %x", address);
	
		cache_addr = address;
		cache_access = 1;
		#5 clk = 1;
		#5 clk = 0;
		if (cache_hit !== 1)
		begin
			$display("error: no cache hit");
			$finish;
		end
		
		#5 clk = 1;
		#5 clk = 0;

		data_to_l1 = {16{value_to_write}};
		cache_write = 1;
		cache_access = 0;
		if (l2_write || l2_read)
		begin
			$display("error: unexpected l2 cache access 1 %b%b", l2_write, l2_read);
			$finish;
		end
		
		#5 clk = 1;
		#5 clk = 0;
		
		cache_write = 0;
		if (l2_write || l2_read)
		begin
			$display("error: unexpected l2 cache access 2 %b%b", l2_write, l2_read);
			$finish;
		end
	end
	endtask	


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
		write_mask = 64'hffffffffffffffff;

		$dumpfile("trace.vcd");
		$dumpvars(100, cache);
		
		// Load into set 1
		do_cache_read_miss('h1040, 32'hcc339966, 0, 0, 0);
		
		// Load items into set 0
		do_cache_read_miss('h1000, 32'hdeadbeef, 0, 0, 0);
		do_cache_read_miss('h2000, 32'h12345678, 0, 0, 0);
		do_cache_read_miss('h3000, 32'ha5a5a5a5, 0, 0, 0);
		do_cache_read_miss('h4000, 32'hbcde0123, 0, 0, 0);

		// These will all be hits
		do_cache_read_hit('h1000, 32'hdeadbeef);
		do_cache_read_hit('h2000, 32'h12345678);
		do_cache_read_hit('h3000, 32'ha5a5a5a5);
		do_cache_read_hit('h4000, 32'hbcde0123);

		// Force eviction of one of the lines
		do_cache_read_miss('h5000, 32'hcdef1234, 0, 0, 0);

		// Verify the line in set1 is still okay
		do_cache_read_hit('h1040, 32'hcc339966);
		
		// Dirty a line, then flush it.
		do_cache_write_hit('h2000, 'hf00dd00d);
		do_cache_read_miss('h6000, 32'h12345678, 0, 0, 0);
		do_cache_read_miss('h7000, 32'ha5a5a5a5, 0, 0, 0);
		do_cache_read_miss('h8000, 32'ha5a5a5a5, 0, 0, 0);
		do_cache_read_miss('h9000, 32'hbcde0123, 1, 'h2000, 'hf00dd00d);

		// Make sure these dirty bit has been cleared.  These should
		// not cause a writeback
		do_cache_read_miss('ha000, 32'h0a0a0a0a, 0, 0, 0);
		do_cache_read_miss('hb000, 32'h0b0b0b0b, 0, 0, 0);
		do_cache_read_miss('hc000, 32'h0c0c0c0c, 0, 0, 0);
		do_cache_read_miss('hd000, 32'h0d0d0d0d, 0, 0, 0);
		
		$display("test complete");
	end
endmodule
