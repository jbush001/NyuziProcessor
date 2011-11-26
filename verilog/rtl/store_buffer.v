//
// Queue pending stores.
// If a read is attempted of a non-committed write in the store buffer,
// we'll need to determine that and return the value from here.  Also,
// if a write is queued where a write is already pending, update
// the existing entry. 
// Note that, if the L2 cache does not acknowledge the entry in a specific
// cycle, the lines may change if that entry is updated. If this is a problem,
// an additional register may be added.
//

module store_buffer
	#(parameter DEPTH = 4,
	parameter INDEX_WIDTH = 2, 
	parameter ADDR_SIZE = 26)
	(input 						clk,
	input [ADDR_SIZE - 1:0]		addr_i,
	input [511:0]				data_i,
	input						write_i,
	input [63:0]				mask_i,
	output reg[511:0]			data_o,
	output reg[63:0]			mask_o,
	output 						full_o,
	
	output reg					l2_write_o,
	input						l2_ack_i,
	output [ADDR_SIZE - 1:0] 	l2_addr_o,
	output reg[511:0]			l2_data_o,
	output [63:0]				l2_mask_o);

	reg[DEPTH - 1:0] 			fifo_valid_ff;	
	reg[DEPTH - 1:0] 			fifo_valid_nxt;	
	reg[ADDR_SIZE - 1:0]		fifo_addr[0:DEPTH - 1];
	reg[63:0]					fifo_mask[0:DEPTH - 1];
	reg							addr_in_fifo;
	reg[INDEX_WIDTH - 1:0]		hit_entry;
	reg[INDEX_WIDTH - 1:0]		head_ptr_nxt;
	reg[INDEX_WIDTH - 1:0]		head_ptr_ff;
	reg[INDEX_WIDTH - 1:0]		tail_ptr;
	reg[INDEX_WIDTH - 1:0]		port0_addr;
	wire						l2_write_nxt;
	integer						i;

	initial
	begin
		mask_o = 0;
		l2_write_o = 0;
		addr_in_fifo = 0;
		hit_entry = 0;
		head_ptr_nxt = 0;
		head_ptr_ff = 0;
		tail_ptr = 0;
		port0_addr = 0;
		fifo_valid_ff = 0;
		fifo_valid_nxt = 0;
		for (i = 0; i < DEPTH; i = i + 1)
		begin
			fifo_addr[i] = 0;
			fifo_mask[i] = 0;
		end
	end

	assign full_o = &fifo_valid_ff;
	assign l2_write_nxt = |fifo_valid_nxt;
	assign l2_addr_o = fifo_addr[head_ptr_ff];
	assign l2_mask_o = fifo_mask[head_ptr_ff];


	// synthesis translate_off
	always @(posedge clk)
	begin
		// We rely on the client not to make an invalid action.
		if (full_o && write_i)
		begin
			$display("Error: attempt to write into full store buffer");
			$finish;
		end
	end
	// synthesis translate_on

	//
	// CAM lookup.  Determine if the requested address is already in the
	// store buffer.  Note that we check fifo_valid_nxt to make sure
	// we don't return an entry that will be invalidated this cycle.
	//
	always @*
	begin
		addr_in_fifo = 0;
		hit_entry = 0;

		for (i = 0; i < DEPTH; i = i + 1)
		begin
			if (fifo_valid_nxt[i] && fifo_addr[i] === addr_i)
			begin
				addr_in_fifo = 1;
				hit_entry = i;
			end
		end
	end

	// Determine whether we are updating/reading an existing entry or
	// adding to the tail.
	always @*
	begin
		if (addr_in_fifo)
			port0_addr = hit_entry;	
		else
			port0_addr = tail_ptr;	
	end

	always @(posedge clk)
	begin
		if (addr_in_fifo)
			mask_o <= #1 fifo_mask[port0_addr];
		else
			mask_o <= #1 0;
	end

	always @(posedge clk)
	begin
		if (write_i)
		begin
			if (addr_in_fifo) 
			begin
				// Update existing FIFO item
				fifo_mask[port0_addr] 	<= #1 fifo_mask[port0_addr] | mask_i;
			end
			else
			begin
				fifo_addr[port0_addr] 	<= #1 addr_i;
				fifo_mask[port0_addr] 	<= #1 mask_i;
				tail_ptr 				<= #1 tail_ptr + 1;
			end
		end
	end

	always @*
	begin
		fifo_valid_nxt = fifo_valid_ff;
		if (write_i)
			fifo_valid_nxt = fifo_valid_nxt | (1 << port0_addr);
		
		if (l2_ack_i)
			fifo_valid_nxt = fifo_valid_nxt & ~(1 << head_ptr_ff);
	end

	always @(posedge clk)
	begin
		fifo_valid_ff <= #1 fifo_valid_nxt;
	end

	always @*
	begin
		if (l2_ack_i && l2_write_o)
			head_ptr_nxt = head_ptr_ff + 1;	
		else
			head_ptr_nxt = head_ptr_ff;
	end

	always @(posedge clk)
	begin
		head_ptr_ff 		<= #1 head_ptr_nxt;
		l2_write_o			<= #1 l2_write_nxt;
	end

	// We need to arrange this in byte lanes in order to do masking properly
	reg[7:0]					fifo_data63[0:DEPTH - 1];
	reg[7:0]					fifo_data62[0:DEPTH - 1];
	reg[7:0]					fifo_data61[0:DEPTH - 1];
	reg[7:0]					fifo_data60[0:DEPTH - 1];
	reg[7:0]					fifo_data59[0:DEPTH - 1];
	reg[7:0]					fifo_data58[0:DEPTH - 1];
	reg[7:0]					fifo_data57[0:DEPTH - 1];
	reg[7:0]					fifo_data56[0:DEPTH - 1];
	reg[7:0]					fifo_data55[0:DEPTH - 1];
	reg[7:0]					fifo_data54[0:DEPTH - 1];
	reg[7:0]					fifo_data53[0:DEPTH - 1];
	reg[7:0]					fifo_data52[0:DEPTH - 1];
	reg[7:0]					fifo_data51[0:DEPTH - 1];
	reg[7:0]					fifo_data50[0:DEPTH - 1];
	reg[7:0]					fifo_data49[0:DEPTH - 1];
	reg[7:0]					fifo_data48[0:DEPTH - 1];
	reg[7:0]					fifo_data47[0:DEPTH - 1];
	reg[7:0]					fifo_data46[0:DEPTH - 1];
	reg[7:0]					fifo_data45[0:DEPTH - 1];
	reg[7:0]					fifo_data44[0:DEPTH - 1];
	reg[7:0]					fifo_data43[0:DEPTH - 1];
	reg[7:0]					fifo_data42[0:DEPTH - 1];
	reg[7:0]					fifo_data41[0:DEPTH - 1];
	reg[7:0]					fifo_data40[0:DEPTH - 1];
	reg[7:0]					fifo_data39[0:DEPTH - 1];
	reg[7:0]					fifo_data38[0:DEPTH - 1];
	reg[7:0]					fifo_data37[0:DEPTH - 1];
	reg[7:0]					fifo_data36[0:DEPTH - 1];
	reg[7:0]					fifo_data35[0:DEPTH - 1];
	reg[7:0]					fifo_data34[0:DEPTH - 1];
	reg[7:0]					fifo_data33[0:DEPTH - 1];
	reg[7:0]					fifo_data32[0:DEPTH - 1];
	reg[7:0]					fifo_data31[0:DEPTH - 1];
	reg[7:0]					fifo_data30[0:DEPTH - 1];
	reg[7:0]					fifo_data29[0:DEPTH - 1];
	reg[7:0]					fifo_data28[0:DEPTH - 1];
	reg[7:0]					fifo_data27[0:DEPTH - 1];
	reg[7:0]					fifo_data26[0:DEPTH - 1];
	reg[7:0]					fifo_data25[0:DEPTH - 1];
	reg[7:0]					fifo_data24[0:DEPTH - 1];
	reg[7:0]					fifo_data23[0:DEPTH - 1];
	reg[7:0]					fifo_data22[0:DEPTH - 1];
	reg[7:0]					fifo_data21[0:DEPTH - 1];
	reg[7:0]					fifo_data20[0:DEPTH - 1];
	reg[7:0]					fifo_data19[0:DEPTH - 1];
	reg[7:0]					fifo_data18[0:DEPTH - 1];
	reg[7:0]					fifo_data17[0:DEPTH - 1];
	reg[7:0]					fifo_data16[0:DEPTH - 1];
	reg[7:0]					fifo_data15[0:DEPTH - 1];
	reg[7:0]					fifo_data14[0:DEPTH - 1];
	reg[7:0]					fifo_data13[0:DEPTH - 1];
	reg[7:0]					fifo_data12[0:DEPTH - 1];
	reg[7:0]					fifo_data11[0:DEPTH - 1];
	reg[7:0]					fifo_data10[0:DEPTH - 1];
	reg[7:0]					fifo_data9[0:DEPTH - 1];
	reg[7:0]					fifo_data8[0:DEPTH - 1];
	reg[7:0]					fifo_data7[0:DEPTH - 1];
	reg[7:0]					fifo_data6[0:DEPTH - 1];
	reg[7:0]					fifo_data5[0:DEPTH - 1];
	reg[7:0]					fifo_data4[0:DEPTH - 1];
	reg[7:0]					fifo_data3[0:DEPTH - 1];
	reg[7:0]					fifo_data2[0:DEPTH - 1];
	reg[7:0]					fifo_data1[0:DEPTH - 1];
	reg[7:0]					fifo_data0[0:DEPTH - 1];

	initial
	begin
		for (i = 0; i < DEPTH; i = i + 1)
		begin
			fifo_data0[i] = 0;
			fifo_data1[i] = 0;
			fifo_data2[i] = 0;
			fifo_data3[i] = 0;
			fifo_data4[i] = 0;
			fifo_data5[i] = 0;
			fifo_data6[i] = 0;
			fifo_data7[i] = 0;
			fifo_data8[i] = 0;
			fifo_data9[i] = 0;
			fifo_data10[i] = 0;
			fifo_data11[i] = 0;
			fifo_data12[i] = 0;
			fifo_data13[i] = 0;
			fifo_data14[i] = 0;
			fifo_data15[i] = 0;
			fifo_data16[i] = 0;
			fifo_data17[i] = 0;
			fifo_data18[i] = 0;
			fifo_data19[i] = 0;
			fifo_data20[i] = 0;
			fifo_data21[i] = 0;
			fifo_data22[i] = 0;
			fifo_data23[i] = 0;
			fifo_data24[i] = 0;
			fifo_data25[i] = 0;
			fifo_data26[i] = 0;
			fifo_data27[i] = 0;
			fifo_data28[i] = 0;
			fifo_data29[i] = 0;
			fifo_data30[i] = 0;
			fifo_data31[i] = 0;
			fifo_data32[i] = 0;
			fifo_data33[i] = 0;
			fifo_data34[i] = 0;
			fifo_data35[i] = 0;
			fifo_data36[i] = 0;
			fifo_data37[i] = 0;
			fifo_data38[i] = 0;
			fifo_data39[i] = 0;
			fifo_data40[i] = 0;
			fifo_data41[i] = 0;
			fifo_data42[i] = 0;
			fifo_data43[i] = 0;
			fifo_data44[i] = 0;
			fifo_data45[i] = 0;
			fifo_data46[i] = 0;
			fifo_data47[i] = 0;
			fifo_data48[i] = 0;
			fifo_data49[i] = 0;
			fifo_data50[i] = 0;
			fifo_data51[i] = 0;
			fifo_data52[i] = 0;
			fifo_data53[i] = 0;
			fifo_data54[i] = 0;
			fifo_data55[i] = 0;
			fifo_data56[i] = 0;
			fifo_data57[i] = 0;
			fifo_data58[i] = 0;
			fifo_data59[i] = 0;
			fifo_data60[i] = 0;
			fifo_data61[i] = 0;
			fifo_data62[i] = 0;
			fifo_data63[i] = 0;
		end
	end

	// When a new entry is entered into store buffer, latch it.
	always @(posedge clk)
	begin
		if (write_i)
		begin
			if (mask_i[63]) fifo_data63[port0_addr] <= #1 data_i[511:504];
			if (mask_i[62]) fifo_data62[port0_addr] <= #1 data_i[503:496];
			if (mask_i[61]) fifo_data61[port0_addr] <= #1 data_i[495:488];
			if (mask_i[60]) fifo_data60[port0_addr] <= #1 data_i[487:480];
			if (mask_i[59]) fifo_data59[port0_addr] <= #1 data_i[479:472];
			if (mask_i[58]) fifo_data58[port0_addr] <= #1 data_i[471:464];
			if (mask_i[57]) fifo_data57[port0_addr] <= #1 data_i[463:456];
			if (mask_i[56]) fifo_data56[port0_addr] <= #1 data_i[455:448];
			if (mask_i[55]) fifo_data55[port0_addr] <= #1 data_i[447:440];
			if (mask_i[54]) fifo_data54[port0_addr] <= #1 data_i[439:432];
			if (mask_i[53]) fifo_data53[port0_addr] <= #1 data_i[431:424];
			if (mask_i[52]) fifo_data52[port0_addr] <= #1 data_i[423:416];
			if (mask_i[51]) fifo_data51[port0_addr] <= #1 data_i[415:408];
			if (mask_i[50]) fifo_data50[port0_addr] <= #1 data_i[407:400];
			if (mask_i[49]) fifo_data49[port0_addr] <= #1 data_i[399:392];
			if (mask_i[48]) fifo_data48[port0_addr] <= #1 data_i[391:384];
			if (mask_i[47]) fifo_data47[port0_addr] <= #1 data_i[383:376];
			if (mask_i[46]) fifo_data46[port0_addr] <= #1 data_i[375:368];
			if (mask_i[45]) fifo_data45[port0_addr] <= #1 data_i[367:360];
			if (mask_i[44]) fifo_data44[port0_addr] <= #1 data_i[359:352];
			if (mask_i[43]) fifo_data43[port0_addr] <= #1 data_i[351:344];
			if (mask_i[42]) fifo_data42[port0_addr] <= #1 data_i[343:336];
			if (mask_i[41]) fifo_data41[port0_addr] <= #1 data_i[335:328];
			if (mask_i[40]) fifo_data40[port0_addr] <= #1 data_i[327:320];
			if (mask_i[39]) fifo_data39[port0_addr] <= #1 data_i[319:312];
			if (mask_i[38]) fifo_data38[port0_addr] <= #1 data_i[311:304];
			if (mask_i[37]) fifo_data37[port0_addr] <= #1 data_i[303:296];
			if (mask_i[36]) fifo_data36[port0_addr] <= #1 data_i[295:288];
			if (mask_i[35]) fifo_data35[port0_addr] <= #1 data_i[287:280];
			if (mask_i[34]) fifo_data34[port0_addr] <= #1 data_i[279:272];
			if (mask_i[33]) fifo_data33[port0_addr] <= #1 data_i[271:264];
			if (mask_i[32]) fifo_data32[port0_addr] <= #1 data_i[263:256];
			if (mask_i[31]) fifo_data31[port0_addr] <= #1 data_i[255:248];
			if (mask_i[30]) fifo_data30[port0_addr] <= #1 data_i[247:240];
			if (mask_i[29]) fifo_data29[port0_addr] <= #1 data_i[239:232];
			if (mask_i[28]) fifo_data28[port0_addr] <= #1 data_i[231:224];
			if (mask_i[27]) fifo_data27[port0_addr] <= #1 data_i[223:216];
			if (mask_i[26]) fifo_data26[port0_addr] <= #1 data_i[215:208];
			if (mask_i[25]) fifo_data25[port0_addr] <= #1 data_i[207:200];
			if (mask_i[24]) fifo_data24[port0_addr] <= #1 data_i[199:192];
			if (mask_i[23]) fifo_data23[port0_addr] <= #1 data_i[191:184];
			if (mask_i[22]) fifo_data22[port0_addr] <= #1 data_i[183:176];
			if (mask_i[21]) fifo_data21[port0_addr] <= #1 data_i[175:168];
			if (mask_i[20]) fifo_data20[port0_addr] <= #1 data_i[167:160];
			if (mask_i[19]) fifo_data19[port0_addr] <= #1 data_i[159:152];
			if (mask_i[18]) fifo_data18[port0_addr] <= #1 data_i[151:144];
			if (mask_i[17]) fifo_data17[port0_addr] <= #1 data_i[143:136];
			if (mask_i[16]) fifo_data16[port0_addr] <= #1 data_i[135:128];
			if (mask_i[15]) fifo_data15[port0_addr] <= #1 data_i[127:120];
			if (mask_i[14]) fifo_data14[port0_addr] <= #1 data_i[119:112];
			if (mask_i[13]) fifo_data13[port0_addr] <= #1 data_i[111:104];
			if (mask_i[12]) fifo_data12[port0_addr] <= #1 data_i[103:96];
			if (mask_i[11]) fifo_data11[port0_addr] <= #1 data_i[95:88];
			if (mask_i[10]) fifo_data10[port0_addr] <= #1 data_i[87:80];
			if (mask_i[9]) fifo_data9[port0_addr] <= #1 data_i[79:72];
			if (mask_i[8]) fifo_data8[port0_addr] <= #1 data_i[71:64];
			if (mask_i[7]) fifo_data7[port0_addr] <= #1 data_i[63:56];
			if (mask_i[6]) fifo_data6[port0_addr] <= #1 data_i[55:48];
			if (mask_i[5]) fifo_data5[port0_addr] <= #1 data_i[47:40];
			if (mask_i[4]) fifo_data4[port0_addr] <= #1 data_i[39:32];
			if (mask_i[3]) fifo_data3[port0_addr] <= #1 data_i[31:24];
			if (mask_i[2]) fifo_data2[port0_addr] <= #1 data_i[23:16];
			if (mask_i[1]) fifo_data1[port0_addr] <= #1 data_i[15:8];
			if (mask_i[0]) fifo_data0[port0_addr] <= #1 data_i[7:0];
		end
	end

	// Existing store buffer data for RAW
	always @(posedge clk)
	begin
		data_o <= #1 {
			fifo_data63[hit_entry],
			fifo_data62[hit_entry],
			fifo_data61[hit_entry],
			fifo_data60[hit_entry],
			fifo_data59[hit_entry],
			fifo_data58[hit_entry],
			fifo_data57[hit_entry],
			fifo_data56[hit_entry],
			fifo_data55[hit_entry],
			fifo_data54[hit_entry],
			fifo_data53[hit_entry],
			fifo_data52[hit_entry],
			fifo_data51[hit_entry],
			fifo_data50[hit_entry],
			fifo_data49[hit_entry],
			fifo_data48[hit_entry],
			fifo_data47[hit_entry],
			fifo_data46[hit_entry],
			fifo_data45[hit_entry],
			fifo_data44[hit_entry],
			fifo_data43[hit_entry],
			fifo_data42[hit_entry],
			fifo_data41[hit_entry],
			fifo_data40[hit_entry],
			fifo_data39[hit_entry],
			fifo_data38[hit_entry],
			fifo_data37[hit_entry],
			fifo_data36[hit_entry],
			fifo_data35[hit_entry],
			fifo_data34[hit_entry],
			fifo_data33[hit_entry],
			fifo_data32[hit_entry],
			fifo_data31[hit_entry],
			fifo_data30[hit_entry],
			fifo_data29[hit_entry],
			fifo_data28[hit_entry],
			fifo_data27[hit_entry],
			fifo_data26[hit_entry],
			fifo_data25[hit_entry],
			fifo_data24[hit_entry],
			fifo_data23[hit_entry],
			fifo_data22[hit_entry],
			fifo_data21[hit_entry],
			fifo_data20[hit_entry],
			fifo_data19[hit_entry],
			fifo_data18[hit_entry],
			fifo_data17[hit_entry],
			fifo_data16[hit_entry],
			fifo_data15[hit_entry],
			fifo_data14[hit_entry],
			fifo_data13[hit_entry],
			fifo_data12[hit_entry],
			fifo_data11[hit_entry],
			fifo_data10[hit_entry],
			fifo_data9[hit_entry],
			fifo_data8[hit_entry],
			fifo_data7[hit_entry],
			fifo_data6[hit_entry],
			fifo_data5[hit_entry],
			fifo_data4[hit_entry],
			fifo_data3[hit_entry],
			fifo_data2[hit_entry],
			fifo_data1[hit_entry],
			fifo_data0[hit_entry]		
		};
	end

	// Data out to L2 cache for writeback
	always @*
	begin
		l2_data_o = {
			fifo_data63[head_ptr_ff],
			fifo_data62[head_ptr_ff],
			fifo_data61[head_ptr_ff],
			fifo_data60[head_ptr_ff],
			fifo_data59[head_ptr_ff],
			fifo_data58[head_ptr_ff],
			fifo_data57[head_ptr_ff],
			fifo_data56[head_ptr_ff],
			fifo_data55[head_ptr_ff],
			fifo_data54[head_ptr_ff],
			fifo_data53[head_ptr_ff],
			fifo_data52[head_ptr_ff],
			fifo_data51[head_ptr_ff],
			fifo_data50[head_ptr_ff],
			fifo_data49[head_ptr_ff],
			fifo_data48[head_ptr_ff],
			fifo_data47[head_ptr_ff],
			fifo_data46[head_ptr_ff],
			fifo_data45[head_ptr_ff],
			fifo_data44[head_ptr_ff],
			fifo_data43[head_ptr_ff],
			fifo_data42[head_ptr_ff],
			fifo_data41[head_ptr_ff],
			fifo_data40[head_ptr_ff],
			fifo_data39[head_ptr_ff],
			fifo_data38[head_ptr_ff],
			fifo_data37[head_ptr_ff],
			fifo_data36[head_ptr_ff],
			fifo_data35[head_ptr_ff],
			fifo_data34[head_ptr_ff],
			fifo_data33[head_ptr_ff],
			fifo_data32[head_ptr_ff],
			fifo_data31[head_ptr_ff],
			fifo_data30[head_ptr_ff],
			fifo_data29[head_ptr_ff],
			fifo_data28[head_ptr_ff],
			fifo_data27[head_ptr_ff],
			fifo_data26[head_ptr_ff],
			fifo_data25[head_ptr_ff],
			fifo_data24[head_ptr_ff],
			fifo_data23[head_ptr_ff],
			fifo_data22[head_ptr_ff],
			fifo_data21[head_ptr_ff],
			fifo_data20[head_ptr_ff],
			fifo_data19[head_ptr_ff],
			fifo_data18[head_ptr_ff],
			fifo_data17[head_ptr_ff],
			fifo_data16[head_ptr_ff],
			fifo_data15[head_ptr_ff],
			fifo_data14[head_ptr_ff],
			fifo_data13[head_ptr_ff],
			fifo_data12[head_ptr_ff],
			fifo_data11[head_ptr_ff],
			fifo_data10[head_ptr_ff],
			fifo_data9[head_ptr_ff],
			fifo_data8[head_ptr_ff],
			fifo_data7[head_ptr_ff],
			fifo_data6[head_ptr_ff],
			fifo_data5[head_ptr_ff],
			fifo_data4[head_ptr_ff],
			fifo_data3[head_ptr_ff],
			fifo_data2[head_ptr_ff],
			fifo_data1[head_ptr_ff],
			fifo_data0[head_ptr_ff]		
		};
	end
endmodule
