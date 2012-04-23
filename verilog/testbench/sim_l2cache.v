`include "l2_cache.h"

module sim_l2cache
	#(parameter MEM_SIZE = 'h100000)

	(input						clk,
	input						pci_valid,
	output reg					pci_ack = 0,
	input [1:0]					pci_unit,
	input [1:0]					pci_strand,
	input [2:0]					pci_op,
	input [1:0]					pci_way,
	input [25:0]				pci_address,
	input [511:0]				pci_data,
	input [63:0]				pci_mask,
	output reg					cpi_valid = 0,
	output reg					cpi_status = 0,
	output reg[1:0]				cpi_unit = 0,
	output reg[1:0]				cpi_strand = 0,
	output reg[1:0]				cpi_op = 0,
	output reg					cpi_update = 0,
	output reg[1:0]				cpi_way = 0,
	output reg[511:0]			cpi_data = 0);

	reg[31:0]					data[0:MEM_SIZE - 1];
	reg							cpi_valid_tmp = 0;
	reg[1:0]					cpi_unit_tmp = 0;
	reg[1:0]					cpi_strand_tmp = 0;
	reg[1:0]					cpi_op_tmp = 0;
	reg[1:0]					cpi_way_tmp = 0;
	reg[511:0]					cpi_data_tmp = 0;
	wire[1:0]					l1_way;
	wire						l1_has_line;
	reg[25:0]					sync_load_address[0:3]; 
	reg							sync_load_address_valid[0:3];
	reg							cpi_status_tmp = 0;
	integer						i;
	integer						j;
	
	initial
	begin
		for (i = 0; i < MEM_SIZE; i = i + 1)
			data[i] = 0;
			
		for (i = 0; i < 4; i = i + 1)
		begin
			sync_load_address[i] = 26'h3ffffff;	
			sync_load_address_valid[i] = 0;
		end
	end

	wire update_directory = pci_valid 
		&& (pci_op == `PCI_LOAD || pci_op == `PCI_LOAD_SYNC)
		&& pci_unit == 1;
	
	// Keep a copy of the L1D cache tag memory. 
	// In the final implementation with an inclusive L2 cache, this information
	// will be stored in a different format.
	cache_tag_mem l1d_tag_copy(
		.clk(clk),
		.address_i({ pci_address, 6'd0 }),
		.access_i(pci_valid),
		.hit_way_o(l1_way),
		.cache_hit_o(l1_has_line),
		.update_i(update_directory),
		.invalidate_i(0),
		.update_way_i(pci_way),
		.update_tag_i(pci_address[25:5]),
		.update_set_i(pci_address[4:0]));


	wire[25:0] cache_addr = { pci_address, 4'd0 };

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
		pci_mask[63] ? pci_data[511:504] : orig_data[511:504],
		pci_mask[62] ? pci_data[503:496] : orig_data[503:496],
		pci_mask[61] ? pci_data[495:488] : orig_data[495:488],
		pci_mask[60] ? pci_data[487:480] : orig_data[487:480],
		pci_mask[59] ? pci_data[479:472] : orig_data[479:472],
		pci_mask[58] ? pci_data[471:464] : orig_data[471:464],
		pci_mask[57] ? pci_data[463:456] : orig_data[463:456],
		pci_mask[56] ? pci_data[455:448] : orig_data[455:448],
		pci_mask[55] ? pci_data[447:440] : orig_data[447:440],
		pci_mask[54] ? pci_data[439:432] : orig_data[439:432],
		pci_mask[53] ? pci_data[431:424] : orig_data[431:424],
		pci_mask[52] ? pci_data[423:416] : orig_data[423:416],
		pci_mask[51] ? pci_data[415:408] : orig_data[415:408],
		pci_mask[50] ? pci_data[407:400] : orig_data[407:400],
		pci_mask[49] ? pci_data[399:392] : orig_data[399:392],
		pci_mask[48] ? pci_data[391:384] : orig_data[391:384],
		pci_mask[47] ? pci_data[383:376] : orig_data[383:376],
		pci_mask[46] ? pci_data[375:368] : orig_data[375:368],
		pci_mask[45] ? pci_data[367:360] : orig_data[367:360],
		pci_mask[44] ? pci_data[359:352] : orig_data[359:352],
		pci_mask[43] ? pci_data[351:344] : orig_data[351:344],
		pci_mask[42] ? pci_data[343:336] : orig_data[343:336],
		pci_mask[41] ? pci_data[335:328] : orig_data[335:328],
		pci_mask[40] ? pci_data[327:320] : orig_data[327:320],
		pci_mask[39] ? pci_data[319:312] : orig_data[319:312],
		pci_mask[38] ? pci_data[311:304] : orig_data[311:304],
		pci_mask[37] ? pci_data[303:296] : orig_data[303:296],
		pci_mask[36] ? pci_data[295:288] : orig_data[295:288],
		pci_mask[35] ? pci_data[287:280] : orig_data[287:280],
		pci_mask[34] ? pci_data[279:272] : orig_data[279:272],
		pci_mask[33] ? pci_data[271:264] : orig_data[271:264],
		pci_mask[32] ? pci_data[263:256] : orig_data[263:256],
		pci_mask[31] ? pci_data[255:248] : orig_data[255:248],
		pci_mask[30] ? pci_data[247:240] : orig_data[247:240],
		pci_mask[29] ? pci_data[239:232] : orig_data[239:232],
		pci_mask[28] ? pci_data[231:224] : orig_data[231:224],
		pci_mask[27] ? pci_data[223:216] : orig_data[223:216],
		pci_mask[26] ? pci_data[215:208] : orig_data[215:208],
		pci_mask[25] ? pci_data[207:200] : orig_data[207:200],
		pci_mask[24] ? pci_data[199:192] : orig_data[199:192],
		pci_mask[23] ? pci_data[191:184] : orig_data[191:184],
		pci_mask[22] ? pci_data[183:176] : orig_data[183:176],
		pci_mask[21] ? pci_data[175:168] : orig_data[175:168],
		pci_mask[20] ? pci_data[167:160] : orig_data[167:160],
		pci_mask[19] ? pci_data[159:152] : orig_data[159:152],
		pci_mask[18] ? pci_data[151:144] : orig_data[151:144],
		pci_mask[17] ? pci_data[143:136] : orig_data[143:136],
		pci_mask[16] ? pci_data[135:128] : orig_data[135:128],
		pci_mask[15] ? pci_data[127:120] : orig_data[127:120],
		pci_mask[14] ? pci_data[119:112] : orig_data[119:112],
		pci_mask[13] ? pci_data[111:104] : orig_data[111:104],
		pci_mask[12] ? pci_data[103:96] : orig_data[103:96],
		pci_mask[11] ? pci_data[95:88] : orig_data[95:88],
		pci_mask[10] ? pci_data[87:80] : orig_data[87:80],
		pci_mask[9] ? pci_data[79:72] : orig_data[79:72],
		pci_mask[8] ? pci_data[71:64] : orig_data[71:64],
		pci_mask[7] ? pci_data[63:56] : orig_data[63:56],
		pci_mask[6] ? pci_data[55:48] : orig_data[55:48],
		pci_mask[5] ? pci_data[47:40] : orig_data[47:40],
		pci_mask[4] ? pci_data[39:32] : orig_data[39:32],
		pci_mask[3] ? pci_data[31:24] : orig_data[31:24],
		pci_mask[2] ? pci_data[23:16] : orig_data[23:16],
		pci_mask[1] ? pci_data[15:8] : orig_data[15:8],
		pci_mask[0] ? pci_data[7:0] : orig_data[7:0]	
	};

	wire store_sync_success = sync_load_address[pci_strand] == pci_address
		&& sync_load_address_valid[pci_strand];

	always @(posedge clk)
	begin
		pci_ack <= #1 pci_valid;
		cpi_valid_tmp <= #1 pci_valid;

		// This comes one cycle later...
		if (cpi_valid_tmp)
			cpi_update <= #1 l1_has_line;		
		else
			cpi_update <= #1 0;
		
		if (cpi_op_tmp == `CPI_LOAD_ACK)
			cpi_way <= #1 cpi_way_tmp;
		else if (cpi_op_tmp == `CPI_STORE_ACK)
			cpi_way <= #1 l1_way;	  // Note, this was already delayed a cycle
		
		if (pci_valid)
		begin
			if (pci_op == `PCI_LOAD || pci_op == `PCI_LOAD_SYNC)
			begin
				if (cache_addr > MEM_SIZE)
				begin
					$display("Bus error: L2 cache read to invalid address %x", cache_addr);
					$finish;
				end
			
				cpi_data_tmp <= #1 orig_data;
				cpi_way_tmp <= #1 pci_way;
			end
			else if (pci_op == `PCI_STORE || pci_op == `PCI_STORE_SYNC)
				cpi_data_tmp <= #1 new_data;	// store update (only if line is already allocated)
			
			cpi_unit_tmp <= #1 pci_unit;
			cpi_strand_tmp <= #1 pci_strand;
			case (pci_op)
				`PCI_LOAD: cpi_op_tmp <= #1 `CPI_LOAD_ACK;
				`PCI_LOAD_SYNC:
				begin
					cpi_op_tmp <= #1 `CPI_LOAD_ACK;
					sync_load_address[pci_strand] <= #1 pci_address;
					sync_load_address_valid[pci_strand] <= #1 1;
				end
				`PCI_STORE, `PCI_STORE_SYNC:
				begin
					cpi_op_tmp <= #1 `CPI_STORE_ACK;
					
					// Invalidate
					for (j = 0; j < 4; j = j + 1)
					begin
						if (sync_load_address[j] == pci_address)
							sync_load_address_valid[j] <= #1 0;
					end
				end

				default: cpi_op_tmp <= #1 0;	// XXX ignore for now
			endcase

			cpi_valid_tmp <= #1 pci_valid;
			
			if (pci_op == `PCI_STORE_SYNC)
				cpi_status_tmp <= #1 store_sync_success;
			else
				cpi_status_tmp <= #1 1;
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
		cpi_valid 	<= #1 cpi_valid_tmp;
		cpi_strand	<= #1 cpi_strand_tmp;
		cpi_unit		<= #1 cpi_unit_tmp;
		cpi_op 		<= #1 cpi_op_tmp;
		cpi_data 		<= #1 cpi_data_tmp;
		cpi_status	<= #1 cpi_status_tmp;
	end

	always @(posedge clk)
	begin
		if ((pci_op == `PCI_STORE && pci_valid)
			|| (pci_op == `PCI_STORE_SYNC && pci_valid && store_sync_success))
		begin
//			$display("cache store strand %d address %x mask %x data %x",
//				pci_strand, cache_addr * 4, pci_mask, pci_data);
		
			if (cache_addr > MEM_SIZE)
			begin
				$display("Bus error: L2 cache write to invalid address %x", cache_addr);
				$finish;
			end
		
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
