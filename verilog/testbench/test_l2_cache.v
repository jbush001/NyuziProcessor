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
		
		while (pci_ack != 1)
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
		if (cpi_data != expected)
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
		
		while (pci_ack != 1)
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
		if (cpi_data != expected)
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

		while (pci_ack != 1)
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

		if (cpi_update != 1)
		begin
			$display("no update");
			$finish;
		end

		// Make sure new data is reflected
		if (cpi_data != expected)
		begin
			$display("data update mismatch want \n\t%x\n got \n\t%x",
				expected, cpi_data);
			$finish;
		end

		#5 clk = 1;
		#5 clk = 0;
	end
	endtask

	localparam PAT1 = 512'h00000000_11111111_22222222_33333333_44444444_55555555_66666666_77777777_88888888_99999999_aaaaaaaa_bbbbbbbb_cccccccc_dddddddd_eeeeeeee_ffffffff;
	localparam PAT2 = 512'h01234567_12345678_23456789_3456789a_456789ab_56789abc_6789abcd_789abcde_89abcdef_9abcdef0_abcdef01_bcdef012_cdef0123_def01234_ef012345_f0123456;
	localparam PAT3 = 512'habcabcab_cabcabca_bcabcabc_abcabcab_cabcabca_bcabcabc_abcabcab_cabcabca_bcabcabc_abcabcab_cabcabca_bcabcabc_abcabcab_cabcabca_bcabcabc_abcabcab;
	localparam PAT4 = 512'h1234abcd_1234abcd_1234abcd_1234abcd_1234abcd_1234abcd_1234abcd_1234abcd_1234abcd_1234abcd_1234abcd_1234abcd_1234abcd_1234abcd_1234abcd_1234abcd;
	localparam PAT5 = 512'h12345678_12345678_12345678_12345678_12345678_12345678_12345678_12345678_12345678_12345678_12345678_12345678_12345678_12345678_12345678_12345678;
	localparam PAT1PAT5 = 512'h00000000_12345678_22222222_12345678_44444444_12345678_66666666_12345678_88888888_12345678_aaaaaaaa_12345678_cccccccc_12345678_eeeeeeee_12345678;
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


