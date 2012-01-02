module core(
	input				clk,
	output 				pci_valid_o,
	input				pci_ack_i,
	output reg[3:0]		pci_id_o,
	output reg[1:0]		pci_op_o,
	output reg[1:0]		pci_way_o,
	output reg[25:0]	pci_address_o,
	output reg[511:0]	pci_data_o,
	output reg[63:0]	pci_mask_o,
	input 				cpi_valid_i,
	input [3:0]			cpi_id_i,
	input [1:0]			cpi_op_i,
	input 				cpi_allocate_i,
	input [1:0]			cpi_way_i,
	input [511:0]		cpi_data_i,
	output				halt_o);

	wire[31:0] 			iaddr;
	wire[31:0] 			idata;
	wire 				iaccess;
	wire 				icache_hit;
	wire[31:0] 			daddr;
	wire[511:0] 		ddata_to_mem;
	wire[511:0] 		ddata_from_mem;
	wire[63:0] 			dwrite_mask;
	wire 				dcache_hit;
	wire 				dwrite;
	wire 				daccess;
	wire[3:0]			dcache_resume_strand;
	wire[1:0]			cache_load_strand;
	wire 				stbuf_full;
	wire[1:0]			dstrand;
	reg[1:0]			selected_unit = 0;
	reg 				unit_selected = 0;
	wire				unit0_valid;
	wire[3:0]			unit0_id;
	wire[1:0]			unit0_op;
	wire[1:0]			unit0_way;
	wire[25:0]			unit0_address;
	wire[511:0]			unit0_data;
	wire[63:0]			unit0_mask;
	wire				unit1_valid;
	wire[3:0]			unit1_id;
	wire[1:0]			unit1_op;
	wire[1:0]			unit1_way;
	wire[25:0]			unit1_address;
	wire[511:0]			unit1_data;
	wire[63:0]			unit1_mask;
	wire				unit2_valid;
	wire[3:0]			unit2_id;
	wire[1:0]			unit2_op;
	wire[1:0]			unit2_way;
	wire[25:0]			unit2_address;
	wire[511:0]			unit2_data;
	wire[63:0]			unit2_mask;

	l1_instruction_cache icache(
		.clk(clk),
		.address_i(iaddr),
		.access_i(iaccess),
		.data_o(idata),
		.cache_hit_o(icache_hit),
		.cache_load_complete_o(),
		.pci_valid_o(unit0_valid),
		.pci_ack_i(pci_ack_i && selected_unit == 0 && unit_selected),
		.pci_id_o(unit0_id),
		.pci_op_o(unit0_op),
		.pci_way_o(unit0_way),
		.pci_address_o(unit0_address),
		.pci_data_o(unit0_data),
		.pci_mask_o(unit0_mask),
		.cpi_valid_i(cpi_valid_i),
		.cpi_id_i(cpi_id_i),
		.cpi_op_i(cpi_op_i),
		.cpi_way_i(cpi_way_i),
		.cpi_data_i(cpi_data_i));

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
		.resume_strand_o(dcache_resume_strand),

		// Load miss queue
		.pci0_valid_o(unit1_valid),
		.pci0_ack_i(pci_ack_i && selected_unit == 1 && unit_selected),
		.pci0_id_o(unit1_id),
		.pci0_op_o(unit1_op),
		.pci0_way_o(unit1_way),
		.pci0_address_o(unit1_address),
		.pci0_data_o(unit1_data),
		.pci0_mask_o(unit1_mask),

		// Store buffer
		.pci1_valid_o(unit2_valid),
		.pci1_ack_i(pci_ack_i && selected_unit == 2 && unit_selected),
		.pci1_id_o(unit2_id),
		.pci1_op_o(unit2_op),
		.pci1_way_o(unit2_way),
		.pci1_address_o(unit2_address),
		.pci1_data_o(unit2_data),
		.pci1_mask_o(unit2_mask),

		.cpi_valid_i(cpi_valid_i),
		.cpi_id_i(cpi_id_i),
		.cpi_op_i(cpi_op_i),
		.cpi_allocate_i(cpi_allocate_i),
		.cpi_way_i(cpi_way_i),
		.cpi_data_i(cpi_data_i));

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
		.dcache_resume_strand_i(dcache_resume_strand),
		.halt_o(halt_o));

	// L2 arbiter
	always @*
	begin
		case (selected_unit)
			2'd0:
			begin
				pci_id_o = unit0_id;
				pci_op_o = unit0_op;
				pci_way_o = unit0_way;
				pci_address_o = unit0_address;
				pci_data_o = unit0_data;
				pci_mask_o = unit0_mask;
			end

			2'd1:
			begin
				pci_id_o = unit1_id;
				pci_op_o = unit1_op;
				pci_way_o = unit1_way;
				pci_address_o = unit1_address;
				pci_data_o = unit1_data;
				pci_mask_o = unit1_mask;
			end

			2'd2:
			begin
				pci_id_o = unit2_id;
				pci_op_o = unit2_op;
				pci_way_o = unit2_way;
				pci_address_o = unit2_address;
				pci_data_o = unit2_data;
				pci_mask_o = unit2_mask;
			end
			
			default:
			begin
				pci_id_o = 0;
				pci_op_o = 0;
				pci_way_o = 0;
				pci_address_o = 0;
				pci_data_o = 0;
				pci_mask_o = 0;
			end
		endcase
	end
	
	assign pci_valid_o = unit_selected && !pci_ack_i;
	
	always @(posedge clk)
	begin
		if (unit_selected)
		begin
			// Check for end of send
			if (pci_ack_i)
				unit_selected <= #1 0;
		end
		else
		begin
			// Chose a new unit		
			unit_selected <= #1 (unit0_valid || unit1_valid || unit2_valid);
			if (unit0_valid)
				selected_unit <= #1 0;
			else if (unit1_valid)
				selected_unit <= #1 1;
			else if (unit2_valid)
				selected_unit <= #1 2;
		end
	end

endmodule