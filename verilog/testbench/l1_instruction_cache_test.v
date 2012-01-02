module l1_instruction_cache_test;

	reg 				clk = 0;
	reg[31:0] 			cache_addr = 0;
	wire[31:0]			data_from_l1;
	reg					cache_access = 0;
	wire				cache_hit;
	wire				pci_valid;
	reg					pci_ack = 0;
	wire[3:0]			pci_id;
	wire[1:0]			pci_op;
	wire[1:0]			pci_way;
	wire[25:0]			pci_address;
	wire[511:0]			pci_data;
	wire[63:0]			pci_mask;
	reg 				cpi_valid = 0;
	reg[3:0]			cpi_id = 0;
	reg[1:0]			cpi_op = 0;
	reg[1:0]			cpi_way = 0;
	reg[511:0]			cpi_data = 0;
	reg[1:0]			requested_way = 0;
	integer				i;

	l1_instruction_cache cache(
		.clk(clk),
		.address_i(cache_addr),
		.access_i(cache_access),
		.data_o(data_from_l1),
		.cache_hit_o(cache_hit),
		.pci_valid_o(pci_valid),
		.pci_ack_i(pci_ack),
		.pci_id_o(pci_id),
		.pci_op_o(pci_op),
		.pci_way_o(pci_way),
		.pci_address_o(pci_address),
		.pci_data_o(pci_data),
		.pci_mask_o(pci_mask),
		.cpi_valid_i(cpi_valid),
		.cpi_id_i(cpi_id),
		.cpi_op_i(cpi_op),
		.cpi_way_i(cpi_way),
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
		if (pci_valid)
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

			if (!pci_valid || pci_op !== 0 || pci_id !== 0)
			begin
				$display("error: No l2 cache read access %d %d %d", pci_valid,
					pci_op, pci_id);
				$finish;
			end
			
			if (pci_address !== (address >> 6))
			begin
				$display("error: bad l2 read address %08x cycle %d", pci_address, i);
				$finish;
			end
		end
		
		requested_way = pci_way;
		pci_ack = 1;
		#5 clk = 1;
		#5 clk = 0;
		pci_ack = 0;

		// After L2 has acknowledged the request, it should no longer be
		// asserted (even though it is still pending)
		for (i = 0; i < 3; i = i + 1)
		begin
			if (pci_valid)
			begin
				$display("duplicate L2 request");
				$finish;
			end

			#5 clk = 1;
			#5 clk = 0;
		end

		// Then send a response from L2 cache
		cpi_valid = 1;
		cpi_id = 0;
		cpi_op = 0;	// Load ack
		cpi_way = requested_way;		
		cpi_data = {16{expected}};
		
		#5 clk = 1;
		#5 clk = 0;
		
		cpi_valid = 0;

		if (pci_valid)
		begin
			$display("error: l2 read not complete %b", pci_valid);
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

		if (data_from_l1 !== expected)
		begin
			$display("error: bad data from L1 cache %x", data_from_l1);
			$finish;
		end
		
		cache_access = 0;
		if (pci_valid)
		begin
			$display("error: unexpected l2 cache access 1 %b", pci_valid);
			$finish;
		end
		
		#5 clk = 1;
		#5 clk = 0;
		if (pci_valid)
		begin
			$display("error: unexpected l2 cache access 2 %b", pci_valid);
			$finish;
		end
	end
	endtask

	initial
	begin
		// Preliminaries, set up variables
		
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
