module l1_data_cache_test;

	reg 				clk = 0;
	reg[31:0] 			cache_addr = 0;
	wire[511:0]			data_from_l1;
	reg[511:0]			data_to_l1 = 0;
	reg					cache_write = 0;
	reg					cache_access = 0;
	reg[63:0]			write_mask = 64'hffffffffffffffff;
	wire				cache_hit;
	wire				pci0_valid;
	reg					pci0_ack = 0;
	wire[3:0]			pci0_id;
	wire[1:0]			pci0_op;
	wire[1:0]			pci0_way;
	wire[25:0]			pci0_address;
	wire[511:0]			pci0_data;
	wire[63:0]			pci0_mask;
	wire				pci1_valid;
	reg					pci1_ack = 0;
	wire[3:0]			pci1_id;
	wire[1:0]			pci1_op;
	wire[1:0]			pci1_way;
	wire[25:0]			pci1_address;
	wire[511:0]			pci1_data;
	wire[63:0]			pci1_mask;
	reg 				cpi_valid = 0;
	reg[3:0]			cpi_id = 0;
	reg[1:0]			cpi_op = 0;
	reg[1:0]			cpi_way = 0;
	reg[511:0]			cpi_data = 0;
	reg					cpi_allocate = 0;
	reg[1:0]			requested_way = 0;
	integer				i;

	l1_data_cache cache(
		.clk(clk),
		.strand_i(2'b00),		// FIXME add multi-strand tests
		.address_i(cache_addr),
		.data_o(data_from_l1),
		.data_i(data_to_l1),
		.write_i(cache_write),
		.access_i(cache_access),
		.write_mask_i(write_mask),
		.cache_hit_o(cache_hit),
		.pci0_valid_o(pci0_valid),
		.pci0_ack_i(pci0_ack),
		.pci0_id_o(pci0_id),
		.pci0_op_o(pci0_op),
		.pci0_way_o(pci0_way),
		.pci0_address_o(pci0_address),
		.pci0_data_o(pci0_data),
		.pci0_mask_o(pci0_mask),
		.pci1_valid_o(pci1_valid),
		.pci1_ack_i(pci1_ack),
		.pci1_id_o(pci1_id),
		.pci1_op_o(pci1_op),
		.pci1_way_o(pci1_way),
		.pci1_address_o(pci1_address),
		.pci1_data_o(pci1_data),
		.pci1_mask_o(pci1_mask),
		.cpi_valid_i(cpi_valid),
		.cpi_id_i(cpi_id),
		.cpi_op_i(cpi_op),
		.cpi_way_i(cpi_way),
		.cpi_allocate_i(cpi_allocate),
		.cpi_data_i(cpi_data));

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
		if (pci0_valid)
		begin
			$display("error: premature l2 cache access");
			$finish;
		end
		
		// Wait a few cycles to acknowledge the transfer
		for (i = 0; i < 3; i = i + 1)
		begin
			#5 clk = 1;
			#5 clk = 0;

			if (cache_hit !== 0)
			begin
				$display("error: should not be cache hit");
				$finish;
			end

			if (!pci0_valid || pci0_op !== 0 || pci0_id[3:2] !== 1)
			begin
				$display("error: No l2 cache read access %d %d %d", 
					pci0_valid, pci0_op, pci0_id);
				$finish;
			end
			
			if (pci0_address !== (address >> 6))
			begin
				$display("error: bad l2 read address %08x cycle %d", pci0_address, i);
				$finish;
			end
		end
		
		requested_way = pci0_way;
		pci0_ack = 1;
		#5 clk = 1;
		#5 clk = 0;
		pci0_ack = 0;

		// After L2 has acknowledged the request, it should no longer be
		// asserted (even though it is still pending)
		for (i = 0; i < 3; i = i + 1)
		begin
			if (pci0_valid)
			begin
				$display("duplicate L2 request");
				$finish;
			end

			#5 clk = 1;
			#5 clk = 0;
		end

		// Then send a response from L2 cache
		cpi_valid = 1;
		cpi_id = 4;
		cpi_op = 0;	// Load ack
		cpi_way = requested_way;		
		cpi_data = {16{expected}};
		
		#5 clk = 1;
		#5 clk = 0;
		
		cpi_valid = 0;

		if (pci0_valid)
		begin
			$display("error: l2 read not complete %b", pci0_valid);
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
		if (pci0_valid)
		begin
			$display("error: unexpected l2 cache access 1 %b", pci0_valid);
			$finish;
		end
		
		#5 clk = 1;
		#5 clk = 0;
		if (pci0_valid)
		begin
			$display("error: unexpected l2 cache access 2 %b", pci0_valid);
			$finish;
		end
	end
	endtask

	task do_cache_write_miss;
		input[31:0] address;
		input[31:0] value_to_write;
	begin
		$display("do_cache_write_miss %x", address);
	
		cache_addr = address;
		cache_access = 1;
		#5 clk = 1;
		#5 clk = 0;

		data_to_l1 = {16{value_to_write}};
		cache_write = 1;
		cache_access = 0;
		if (pci1_valid)
		begin
			$display("error: unexpected l2 cache access 1");
			$finish;
		end
		
		#5 clk = 1;
		#5 clk = 0;
		
		cache_write = 0;

		// Wait a few cycles to acknowledge the transfer
		for (i = 0; i < 3; i = i + 1)
		begin
			#5 clk = 1;
			#5 clk = 0;

			if (cache_hit !== 0)	
			begin
				$display("error: should not be cache hit");
				$finish;
			end

			if (!pci1_valid || pci1_op !== 1 || pci1_id[3:2] !== 2)
			begin
				$display("error: No l2 cache write access %d %d %d", 
					pci1_valid, pci1_op, pci1_id);
				$finish;
			end
			
			if (pci1_address !== (address >> 6))
			begin
				$display("error: bad l2 read address %08x cycle %d", pci0_address, i);
				$finish;
			end
		end
		
		requested_way = pci1_way;
		pci1_ack = 1;
		#5 clk = 1;
		#5 clk = 0;
		pci1_ack = 0;

		// After L2 has acknowledged the request, it should no longer be
		// asserted (even though it is still pending)
		for (i = 0; i < 3; i = i + 1)
		begin
			if (pci1_valid)
			begin
				$display("duplicate L2 request");
				$finish;
			end

			#5 clk = 1;
			#5 clk = 0;
		end

		// Then send a response from L2 cache
		cpi_valid = 1;
		cpi_id = 8;
		cpi_op = 1;	// Load ack
		cpi_way = requested_way;		
		
		#5 clk = 1;
		#5 clk = 0;
		
		cpi_valid = 0;

		if (pci1_valid)
		begin
			$display("error: l2 read not complete %b", pci0_valid);
			$finish;
		end
	end
	endtask	


	// NOTE: this must be called after an allocating read miss, since it
	// checks requested_way.
	task do_cache_write_hit;
		input[31:0] address;
		input[31:0] value_to_write;
	begin
		$display("do_cache_write_hit %x", address);
	
		cache_addr = address;
		cache_access = 1;
		#5 clk = 1;
		#5 clk = 0;

		data_to_l1 = {16{value_to_write}};
		cache_write = 1;
		cache_access = 0;
		if (pci1_valid)
		begin
			$display("error: unexpected l2 cache access 1");
			$finish;
		end

		if (cache_hit !== 1)
		begin
			$display("error: should be cache hit");
			$finish;
		end

		#5 clk = 1;
		#5 clk = 0;

		cache_write = 0;

		// Wait a few cycles to acknowledge the transfer
		for (i = 0; i < 3; i = i + 1)
		begin
			#5 clk = 1;
			#5 clk = 0;

			if (!pci1_valid || pci1_op !== 1 || pci1_id[3:2] !== 2)
			begin
				$display("error: No l2 cache write access %d %d %d", 
					pci1_valid, pci1_op, pci1_id);
				$finish;
			end
			
			if (pci1_address !== (address >> 6))
			begin
				$display("error: bad l2 write address %08x cycle %d", pci0_address, i);
				$finish;
			end
		end
		
		pci1_ack = 1;
		#5 clk = 1;
		#5 clk = 0;
		pci1_ack = 0;

		// After L2 has acknowledged the request, it should no longer be
		// asserted (even though it is still pending)
		for (i = 0; i < 3; i = i + 1)
		begin
			if (pci1_valid)
			begin
				$display("duplicate L2 request");
				$finish;
			end

			#5 clk = 1;
			#5 clk = 0;
		end

		// Then send a response from L2 cache
		cpi_allocate = 1;
		cpi_data = {16{value_to_write}};
		cpi_valid = 1;
		cpi_id = 8;
		cpi_op = 1;	// store ACK	
		cpi_way = requested_way;		
		
		#5 clk = 1;
		#5 clk = 0;
		
		cpi_valid = 0;

		if (pci1_valid)
		begin
			$display("error: l2 read not complete %b", pci0_valid);
			$finish;
		end
	end
	endtask	


	initial
	begin
		$dumpfile("trace.vcd");
		$dumpvars;
		
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

		// Cache write miss (which will not allocate).  Verify subsequent
		// read gets the dirtied data from the store buffer and not the
		// data that was read back from L2.
		do_cache_write_miss('h1080, 32'hbeebbeeb);
		do_cache_read_miss('h1080, 32'hbeebbeeb);
		do_cache_write_hit('h1080, 32'h31323334);
		do_cache_read_hit('h1080, 32'h31323334);

		$display("test complete");
	end
endmodule
