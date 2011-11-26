module store_buffer_test;

	reg 				clk;
	reg[25:0] 			store_addr;
	reg[511:0] 			store_data_i;
	reg 				store_enable;
	reg[63:0] 			store_mask_i;
	wire[511:0]			store_data_o;
	wire[63:0]			store_mask_o;
	wire				full;
	wire				l2_write;
	reg					l2_ack;
	wire[25:0]			l2_addr;
	wire[511:0]			l2_data;
	wire[63:0]			l2_mask;
	integer				i;

	store_buffer stbuf(
		.clk(clk),
		.addr_i(store_addr),
		.data_i(store_data_i),
		.write_i(store_enable),
		.mask_i(store_mask_i),
		.data_o(store_data_o),
		.mask_o(store_mask_o),
		.full_o(full),
		.l2_write_o(l2_write),
		.l2_ack_i(l2_ack),
		.l2_addr_o(l2_addr),
		.l2_data_o(l2_data),
		.l2_mask_o(l2_mask));

	// Initiate a store
	task do_store;
		input[25:0]		addr;
		input[511:0]	value;
		input[63:0]		mask;
	begin
		store_addr = addr;
		store_data_i = value;
		store_enable = 1;
		store_mask_i = mask;
	end
	endtask
	
	// Will check that L2 write is asserted, but won't acknowledge it.
	task check_l2_write;
		input[25:0]	expect_addr;
		input[511:0]expect_value;
		input[63:0]	expect_mask;
	begin
		if (l2_write != 1)
		begin
			$display("FAIL: did not initiate L2 writeback");
			$finish;
		end
		
		if (l2_addr != expect_addr)
		begin
			$display("FAIL: bad L2 writeback address", l2_addr);
			$finish;
		end
		
		if (l2_data != expect_value)
		begin
			$display("FAIL: bad L2 writeback data %x", l2_data);
			$finish;
		end

		if (l2_mask != expect_mask)
		begin
			$display("FAIL: bad L2 writeback mask %x", l2_mask);
			$finish;
		end
	end
	endtask
	
	// Does one clock pulse, then resets all registers to their initial
	// state
	task do_clk;
	begin
		#5 clk = 1;
		#5 clk = 0;
		
		clk = 0;
		store_addr = 0;
		store_data_i = 0;
		store_enable = 0;
		store_mask_i = 0;
		l2_ack = 0;
	end
	endtask

	initial
	begin
		clk = 0;
		store_addr = 0;
		store_data_i = 0;
		store_enable = 0;
		store_mask_i = 0;
		l2_ack = 0;
		
		#5 $dumpfile("trace.vcd");
		$dumpvars(100, stbuf);

		if (l2_write != 0)
		begin
			$display("FAIL: unexpected L2 write at start");
			$finish;
		end

		//
		// Test #1: add and remove one item at a time.  Make sure pointers
		// wrap correctly.
		//
		do_store(1, {16{32'h12345678}}, 64'hfafafafafafafafa);
		do_clk;
		check_l2_write(1, {16{32'h12345678}}, 64'hfafafafafafafafa);
		if (!full)
		begin
			$display("FAIL: full signal not asserted");
			$finish;
		end
		
		l2_ack = 1;

		do_clk;
		if (full)
		begin
			$display("FAIL: full signal asserted 1");
			$finish;
		end

		if (l2_write)
		begin
			$display("FAIL: extra L2 writeback 1");
			$finish;
		end

		//
		// Test #2: overlapped write/writeback
		//
		do_store(1, {16{32'he14efe00}}, 64'haa55aa55aa55aa55);
		do_clk;
		l2_ack = 1;
		#1 if (full)
		begin
			$display("FAIL: full signal asserted 2");
			$finish;
		end

		do_store(1, {16{32'hfaceface}}, 64'h9988998899889988);
		check_l2_write(1, {16{32'he14efe00}}, 64'haa55aa55aa55aa55);
		do_clk;
		check_l2_write(1, {16{32'hfaceface}}, 64'h9988998899889988);
		l2_ack = 1;
		if (full)
		begin
			$display("FAIL: full signal asserted 3");
			$finish;
		end

		do_clk;

		if (l2_write)
		begin
			$display("FAIL: extra L2 writeback 2");
			$finish;
		end
		
		$display("tests complete");
	end
endmodule
