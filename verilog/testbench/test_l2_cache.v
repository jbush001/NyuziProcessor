`include "l2_cache.h"

module l2_cache_test;
	reg 					clk = 0;
	reg						pci_valid = 0;
	wire					pci_ack;
	reg [1:0]				pci_unit = 0;
	reg [1:0]				pci_strand = 0;
	reg [2:0]				pci_op = 0;
	reg [1:0]				pci_way = 0;
	reg [25:0]				pci_address = 0;
	reg [511:0]				pci_data = 0;
	reg [63:0]				pci_mask = 0;
	wire					cpi_valid;
	wire					cpi_status;
	wire[1:0]				cpi_unit;
	wire[1:0]				cpi_strand;
	wire[1:0]				cpi_op;
	wire					cpi_update;
	wire[1:0]				cpi_way;
	wire[511:0]				cpi_data;

	wire[31:0]				sm_addr;
	wire					sm_request;
	reg						sm_ack = 0;
	wire					sm_write;
	reg[31:0]				data_from_sm = 32'h12345678;
	wire[31:0]				data_to_sm;
	integer					i;
	integer					j;

	l2_cache l2c(
		.clk(clk),
		.pci_valid(pci_valid),
		.pci_ack_o(pci_ack),
		.pci_unit(pci_unit),
		.pci_strand(pci_strand),
		.pci_op(pci_op),
		.pci_way(pci_way),
		.pci_address(pci_address),
		.pci_data(pci_data),
		.pci_mask(pci_mask),
		.cpi_valid(cpi_valid),
		.cpi_status(cpi_status),
		.cpi_unit(cpi_unit),
		.cpi_strand(cpi_strand),
		.cpi_op(cpi_op),
		.cpi_update(cpi_update),
		.cpi_way(cpi_way),
		.cpi_data(cpi_data),
		.addr_o(sm_addr),
		.request_o(sm_request),
		.ack_i(sm_ack),
		.write_o(sm_write),
		.data_i(data_from_sm),
		.data_o(data_to_sm));

	reg[511:0] expected;

	task l2_load_miss_no_dirty;
		input [31:0] address;
		input [511:0] expected;
	begin
		$display("test miss no dirty");

		pci_valid = 1;
		pci_unit = 0;
		pci_strand = 0;
		pci_op = `PCI_LOAD;
		pci_way = 0;
		pci_address = address;
		
		while (pci_ack !== 1)
		begin
			#5 clk = 1;
			#5 clk = 0;
		end

		pci_valid = 0;

		while (!sm_request)
		begin
			#5 clk = 1;
			#5 clk = 0;
		end

		sm_ack = 1;
		for (j = 0; j < 16; j = j + 1)
		begin
			data_from_sm = (expected >> (15 - i));
			#5 clk = 1;
			#5 clk = 0;
		end

		sm_ack = 0;

		while (!cpi_valid)		
		begin
			#5 clk = 1;
			#5 clk = 0;
		end

		// Check result
		if (cpi_data !== expected)
		begin
			$display("load mismatch want \n\t%x\n got \n\t%x",
				expected, cpi_data);
			$finish;
		end
	end
	endtask

	task l2_load_hit;
		input [31:0] address;
		input [511:0] expected;
	begin
		$display("test load hit");

		pci_valid = 1;
		pci_unit = 0;
		pci_strand = 0;
		pci_op = `PCI_LOAD;
		pci_way = 0;
		pci_address = address;
		
		while (pci_ack !== 1)
		begin
			#5 clk = 1;
			#5 clk = 0;
		end

		pci_valid = 0;

		while (!cpi_valid)		
		begin
			#5 clk = 1;
			#5 clk = 0;
			if (sm_request)
			begin
				$display("unexpected sm request");
				$finish;
			end
		end

		// Check result
		if (cpi_data !== expected)
		begin
			$display("load mismatch want \n\t%x\n got \n\t%x",
				expected, cpi_data);
			$finish;
		end

		#5 clk = 1;
		#5 clk = 0;
	end
	endtask

	task l2_store_hit;
		input [31:0] address;
		input [63:0] mask;
		input [511:0] write_data;
		input [511:0] expected;
	begin
		$display("test store hit");

		pci_valid = 1;
		pci_unit = 0;
		pci_strand = 0;
		pci_op = `PCI_STORE;
		pci_way = 0;
		pci_address = address;
		pci_mask = mask;
		pci_data = write_data;

		while (pci_ack !== 1)
		begin
			#5 clk = 1;
			#5 clk = 0;
		end

		pci_valid = 0;

		while (!cpi_valid)		
		begin
			#5 clk = 1;
			#5 clk = 0;
			if (sm_request)
			begin
				$display("unexpected sm request");
				$finish;
			end
		end

		if (cpi_update !== 1)
		begin
			$display("no update");
			$finish;
		end

		// Make sure new data is reflected
		if (cpi_data !== expected)
		begin
			$display("data update mismatch want \n\t%x\n got \n\t%x",
				expected, cpi_data);
			$finish;
		end

		#5 clk = 1;
		#5 clk = 0;
	end
	endtask

	localparam PAT1 = 512'he557b78b_d40df4cd_e9ffa5eb_f868c1cf_7068c30a_7587ddb3_7ad4cd9e_db1d8751_e885f505_a44997b8_86a76f8a_7caba015_171b4022_bc9b761e_e23a11e0_0f19f338;
	localparam PAT2 = 512'he6c17f8f_e83fce2b_441752d7_754ab59e_073efaac_c228c3c2_690616fb_798c2dec_b02c0a26_0867862c_d0053170_75dd9bae_fef44d27_2475f817_30883ef9_7843afb7;
	localparam PAT3 = 512'h3b163cf2_2c8bb48e_758bd67a_2b43553e_0ca7b1e0_50e3ee5d_85c91d0e_4b9b5700_c54108ec_b6a76fb3_b9a097d1_0e96a9e8_868b9ca0_fd8cbf95_7d5738db_d1e481a2;
	localparam PAT4 = 512'h95ffd554_d65f92f7_b44c0c68_70b298b7_2b852287_8b2a3311_b55ee570_c4603787_0cb78e49_c3bfb6de_b65f42e7_2a80ae2c_df8fb98d_71a2ecc1_e495ec5d_941d9c6f;
	localparam PAT5 = 512'h2610d695_8316f1e8_12c733e5_636488fd_d31db139_4410e9c9_8d57003d_61bcf849_fc26c1e1_303516bd_532828a1_546b0c87_1228c78b_c404f1f8_5d505827_e4923f13;
	localparam PAT1PAT5 = 512'he557b78b_8316f1e8_e9ffa5eb_636488fd_7068c30a_4410e9c9_7ad4cd9e_61bcf849_e885f505_303516bd_86a76f8a_546b0c87_171b4022_c404f1f8_e23a11e0_e4923f1;
	localparam MASK1 = 64'h0f0f0f0f0f0f0f0f;

	initial
	begin
		#5 clk = 1;
		#5 clk = 0;

		$dumpfile("trace.vcd");
		$dumpvars;

		l2_load_miss_no_dirty(32'ha000, PAT1);
		l2_load_miss_no_dirty(32'hb000, PAT2);
		l2_load_miss_no_dirty(32'ha040, PAT3);
		l2_load_miss_no_dirty(32'hb040, PAT4);

		l2_load_hit(32'ha000, PAT1);
		l2_load_hit(32'hb000, PAT2);
		l2_load_hit(32'ha040, PAT3);
		l2_load_hit(32'hb040, PAT4);

		l2_store_hit(32'ha000, MASK1, PAT5, PAT1PAT5);
		l2_load_hit(32'ha000, PAT1PAT5);

		l2_load_hit(32'hb000, PAT2);
		l2_load_hit(32'ha040, PAT3);
		l2_load_hit(32'hb040, PAT4);

		$display("test complete");
	end
endmodule


