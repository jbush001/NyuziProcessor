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

	l2_cache l2c(
		.clk(clk),
		.pci_valid_i(pci_valid),
		.pci_ack_o(pci_ack),
		.pci_unit_i(pci_unit),
		.pci_strand_i(pci_strand),
		.pci_op_i(pci_op),
		.pci_way_i(pci_way),
		.pci_address_i(pci_address),
		.pci_data_i(pci_data),
		.pci_mask_i(pci_mask),
		.cpi_valid_o(cpi_valid),
		.cpi_status_o(cpi_status),
		.cpi_unit_o(cpi_unit),
		.cpi_strand_o(cpi_strand),
		.cpi_op_o(cpi_op),
		.cpi_update_o(cpi_update),
		.cpi_way_o(cpi_way),
		.cpi_data_o(cpi_data),
		.addr_o(sm_addr),
		.request_o(sm_request),
		.ack_i(sm_ack),
		.write_o(sm_write),
		.data_i(data_from_sm),
		.data_o(data_to_sm));

	task l2_load_miss_no_dirty;
		input [31:0] address;
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

		while (!cpi_valid)		
		begin
			#5 clk = 1;
			#5 clk = 0;
			if (sm_request)
				sm_ack = 1;
		end

		sm_ack = 0;
		#5 clk = 1;
		#5 clk = 0;
	end
	endtask

	task l2_load_hit;
		input [31:0] address;
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

		#5 clk = 1;
		#5 clk = 0;
	end
	endtask

	task l2_store_hit;
		input [31:0] address;
	begin
		$display("test store hit");

		pci_valid = 1;
		pci_unit = 0;
		pci_strand = 0;
		pci_op = `PCI_STORE;
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

		if (cpi_update != 1)
		begin
			$display("no update");
			$finish;
		end

		#5 clk = 1;
		#5 clk = 0;
	end
	endtask

	initial
	begin
		#5 clk = 1;
		#5 clk = 0;

		$dumpfile("trace.vcd");
		$dumpvars;

		l2_load_miss_no_dirty(32'ha000);
		l2_load_hit(32'ha000);
		l2_load_miss_no_dirty(32'hb000);
		l2_load_hit(32'hb000);
		l2_store_hit(32'ha000);

		$display("test complete");
	end
endmodule


