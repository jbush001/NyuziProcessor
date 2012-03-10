module sim_l2cache
	#(parameter MEM_SIZE = 'h100000)

	(input						clk,
	input						pci_valid_i,
	output reg					pci_ack_o = 0,
	input [1:0]					pci_unit_i,
	input [1:0]					pci_strand_i,
	input [1:0]					pci_op_i,
	input [1:0]					pci_way_i,
	input [25:0]				pci_address_i,
	input [511:0]				pci_data_i,
	input [63:0]				pci_mask_i,
	output reg					cpi_valid_o = 0,
	output reg[1:0]				cpi_unit_o = 0,
	output reg[1:0]				cpi_strand_o = 0,
	output reg[1:0]				cpi_op_o = 0,
	output reg					cpi_update_o = 0,
	output reg[1:0]				cpi_way_o = 0,
	output reg[511:0]			cpi_data_o = 0);

	reg[31:0]					data[0:MEM_SIZE - 1];
	reg							cpi_valid_tmp = 0;
	reg[1:0]					cpi_unit_tmp = 0;
	reg[1:0]					cpi_strand_tmp = 0;
	reg[1:0]					cpi_op_tmp = 0;
	reg[1:0]					cpi_way_tmp = 0;
	reg[511:0]					cpi_data_tmp = 0;
	wire[1:0]					l1_way;
	wire						l1_has_line;
	integer						i;
	
	initial
	begin
		for (i = 0; i < MEM_SIZE; i = i + 1)
			data[i] = 0;
	end
	
	// Keep a copy of the L1D cache tag memory. 
	// In the final implementation with an inclusive L2 cache, this information
	// will be stored in a different format.
	cache_tag_mem l1d_tag_copy(
		.clk(clk),
		.address_i({ pci_address_i, 6'd0 }),
		.access_i(pci_valid_i),
		.hit_way_o(l1_way),
		.cache_hit_o(l1_has_line),
		.update_i(pci_valid_i && pci_op_i == 0 && pci_unit_i == 1),
		.invalidate_i(0),
		.update_way_i(pci_way_i),
		.update_tag_i(pci_address_i[25:5]),
		.update_set_i(pci_address_i[4:0]));

	parameter PCI_OP_LOAD = 0;
	parameter PCI_OP_STORE = 1;
	parameter PCI_OP_FLUSH = 2;
	parameter PCI_OP_INVALIDATE = 3;
	
	parameter CPI_OP_LOAD = 0;
	parameter CPI_OP_STORE = 1;
	parameter CPI_OP_WRITE_VALIDATE = 2;

	wire[25:0] cache_addr = { pci_address_i, 4'd0 };

	wire[511:0] orig_data = {
		data[cache_addr],
		data[cache_addr + 1],
		data[cache_addr + 2],
		data[cache_addr + 3],
		data[cache_addr + 4],
		data[cache_addr + 5],
		data[cache_addr + 6],
		data[cache_addr + 7],
		data[cache_addr + 8],
		data[cache_addr + 9],
		data[cache_addr + 10],
		data[cache_addr + 11],
		data[cache_addr + 12],
		data[cache_addr + 13],
		data[cache_addr + 14],
		data[cache_addr + 15]
	};

	wire[511:0] new_data = {
		pci_mask_i[63] ? pci_data_i[511:504] : orig_data[511:504],
		pci_mask_i[62] ? pci_data_i[503:496] : orig_data[503:496],
		pci_mask_i[61] ? pci_data_i[495:488] : orig_data[495:488],
		pci_mask_i[60] ? pci_data_i[487:480] : orig_data[487:480],
		pci_mask_i[59] ? pci_data_i[479:472] : orig_data[479:472],
		pci_mask_i[58] ? pci_data_i[471:464] : orig_data[471:464],
		pci_mask_i[57] ? pci_data_i[463:456] : orig_data[463:456],
		pci_mask_i[56] ? pci_data_i[455:448] : orig_data[455:448],
		pci_mask_i[55] ? pci_data_i[447:440] : orig_data[447:440],
		pci_mask_i[54] ? pci_data_i[439:432] : orig_data[439:432],
		pci_mask_i[53] ? pci_data_i[431:424] : orig_data[431:424],
		pci_mask_i[52] ? pci_data_i[423:416] : orig_data[423:416],
		pci_mask_i[51] ? pci_data_i[415:408] : orig_data[415:408],
		pci_mask_i[50] ? pci_data_i[407:400] : orig_data[407:400],
		pci_mask_i[49] ? pci_data_i[399:392] : orig_data[399:392],
		pci_mask_i[48] ? pci_data_i[391:384] : orig_data[391:384],
		pci_mask_i[47] ? pci_data_i[383:376] : orig_data[383:376],
		pci_mask_i[46] ? pci_data_i[375:368] : orig_data[375:368],
		pci_mask_i[45] ? pci_data_i[367:360] : orig_data[367:360],
		pci_mask_i[44] ? pci_data_i[359:352] : orig_data[359:352],
		pci_mask_i[43] ? pci_data_i[351:344] : orig_data[351:344],
		pci_mask_i[42] ? pci_data_i[343:336] : orig_data[343:336],
		pci_mask_i[41] ? pci_data_i[335:328] : orig_data[335:328],
		pci_mask_i[40] ? pci_data_i[327:320] : orig_data[327:320],
		pci_mask_i[39] ? pci_data_i[319:312] : orig_data[319:312],
		pci_mask_i[38] ? pci_data_i[311:304] : orig_data[311:304],
		pci_mask_i[37] ? pci_data_i[303:296] : orig_data[303:296],
		pci_mask_i[36] ? pci_data_i[295:288] : orig_data[295:288],
		pci_mask_i[35] ? pci_data_i[287:280] : orig_data[287:280],
		pci_mask_i[34] ? pci_data_i[279:272] : orig_data[279:272],
		pci_mask_i[33] ? pci_data_i[271:264] : orig_data[271:264],
		pci_mask_i[32] ? pci_data_i[263:256] : orig_data[263:256],
		pci_mask_i[31] ? pci_data_i[255:248] : orig_data[255:248],
		pci_mask_i[30] ? pci_data_i[247:240] : orig_data[247:240],
		pci_mask_i[29] ? pci_data_i[239:232] : orig_data[239:232],
		pci_mask_i[28] ? pci_data_i[231:224] : orig_data[231:224],
		pci_mask_i[27] ? pci_data_i[223:216] : orig_data[223:216],
		pci_mask_i[26] ? pci_data_i[215:208] : orig_data[215:208],
		pci_mask_i[25] ? pci_data_i[207:200] : orig_data[207:200],
		pci_mask_i[24] ? pci_data_i[199:192] : orig_data[199:192],
		pci_mask_i[23] ? pci_data_i[191:184] : orig_data[191:184],
		pci_mask_i[22] ? pci_data_i[183:176] : orig_data[183:176],
		pci_mask_i[21] ? pci_data_i[175:168] : orig_data[175:168],
		pci_mask_i[20] ? pci_data_i[167:160] : orig_data[167:160],
		pci_mask_i[19] ? pci_data_i[159:152] : orig_data[159:152],
		pci_mask_i[18] ? pci_data_i[151:144] : orig_data[151:144],
		pci_mask_i[17] ? pci_data_i[143:136] : orig_data[143:136],
		pci_mask_i[16] ? pci_data_i[135:128] : orig_data[135:128],
		pci_mask_i[15] ? pci_data_i[127:120] : orig_data[127:120],
		pci_mask_i[14] ? pci_data_i[119:112] : orig_data[119:112],
		pci_mask_i[13] ? pci_data_i[111:104] : orig_data[111:104],
		pci_mask_i[12] ? pci_data_i[103:96] : orig_data[103:96],
		pci_mask_i[11] ? pci_data_i[95:88] : orig_data[95:88],
		pci_mask_i[10] ? pci_data_i[87:80] : orig_data[87:80],
		pci_mask_i[9] ? pci_data_i[79:72] : orig_data[79:72],
		pci_mask_i[8] ? pci_data_i[71:64] : orig_data[71:64],
		pci_mask_i[7] ? pci_data_i[63:56] : orig_data[63:56],
		pci_mask_i[6] ? pci_data_i[55:48] : orig_data[55:48],
		pci_mask_i[5] ? pci_data_i[47:40] : orig_data[47:40],
		pci_mask_i[4] ? pci_data_i[39:32] : orig_data[39:32],
		pci_mask_i[3] ? pci_data_i[31:24] : orig_data[31:24],
		pci_mask_i[2] ? pci_data_i[23:16] : orig_data[23:16],
		pci_mask_i[1] ? pci_data_i[15:8] : orig_data[15:8],
		pci_mask_i[0] ? pci_data_i[7:0] : orig_data[7:0]	
	};

	always @(posedge clk)
	begin
		pci_ack_o <= #1 pci_valid_i;
		cpi_valid_tmp <= #1 pci_valid_i;

		// This comes one cycle later...
		if (cpi_valid_tmp)
			cpi_update_o <= #1 l1_has_line;		
		else
			cpi_update_o <= #1 0;
		
		if (cpi_op_tmp == CPI_OP_LOAD)
			cpi_way_o <= #1 cpi_way_tmp;
		else if (cpi_op_tmp == CPI_OP_STORE)
			cpi_way_o <= #1 l1_way;	  // Note, this was already delayed a cycle
		
		if (pci_valid_i)
		begin
			if (pci_op_i == PCI_OP_LOAD)
			begin
				cpi_data_tmp <= #1 orig_data;
				cpi_way_tmp <= #1 pci_way_i;
			end
			else if (pci_op_i == PCI_OP_STORE)
				cpi_data_tmp <= #1 new_data;	// store update (only if line is already allocated)
			
			cpi_unit_tmp <= #1 pci_unit_i;
			cpi_strand_tmp <= #1 pci_strand_i;
			case (pci_op_i)
				PCI_OP_LOAD: cpi_op_tmp <= #1 CPI_OP_LOAD;
				PCI_OP_STORE: cpi_op_tmp <= #1 CPI_OP_STORE;
				default: cpi_op_tmp <= #1 0;	// XXX ignore for now
			endcase

			cpi_valid_tmp <= #1 pci_valid_i;
		end
		else
		begin
			cpi_valid_tmp 		<= #1 0;
			cpi_unit_tmp 		<= #1 0;
			cpi_strand_tmp		<= #1 0;
			cpi_op_tmp 			<= #1 0;
			cpi_way_tmp 		<= #1 0;
			cpi_data_tmp 		<= #1 0;
		end

		
		// delay a cycle
		cpi_valid_o 	<= #1 cpi_valid_tmp;
		cpi_strand_o	<= #1 cpi_strand_tmp;
		cpi_unit_o		<= #1 cpi_unit_tmp;
		cpi_op_o 		<= #1 cpi_op_tmp;
		cpi_data_o 		<= #1 cpi_data_tmp;
	end


	always @(posedge clk)
	begin
		if (pci_op_i == PCI_OP_STORE && pci_valid_i)
		begin
//			$display("cache store address %x mask %x data %x",
//				cache_addr * 4, pci_mask_i, pci_data_i);
		
			data[cache_addr] <= #1 new_data[511:480];
			data[cache_addr + 1] <= #1 new_data[479:448];
			data[cache_addr + 2] <= #1 new_data[447:416];
			data[cache_addr + 3] <= #1 new_data[415:384];
			data[cache_addr + 4] <= #1 new_data[383:352];
			data[cache_addr + 5] <= #1 new_data[351:320];
			data[cache_addr + 6] <= #1 new_data[319:288];
			data[cache_addr + 7] <= #1 new_data[287:256];
			data[cache_addr + 8] <= #1 new_data[255:224];
			data[cache_addr + 9] <= #1 new_data[223:192];
			data[cache_addr + 10] <= #1 new_data[191:160];
			data[cache_addr + 11] <= #1 new_data[159:128];
			data[cache_addr + 12] <= #1 new_data[127:96];
			data[cache_addr + 13] <= #1 new_data[95:64];
			data[cache_addr + 14] <= #1 new_data[63:32];
			data[cache_addr + 15] <= #1 new_data[31:0];
		end
	end	
endmodule
