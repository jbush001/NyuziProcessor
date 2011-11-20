//
// Dual-ported 512 bit wide synchronous memory
//

module mem512
	#(parameter MEM_COUNT = 128,
	ADDR_WIDTH = 7)	// Number of 512 bit entries
	(input						clk,
	input [ADDR_WIDTH - 1:0]	port0_addr_i,
	input [511:0]				port0_data_i,
	output reg[511:0]			port0_data_o,
	input						port0_write_i,
	input [63:0]				port0_byte_enable_i,
	input [ADDR_WIDTH - 1:0]	port1_addr_i,
	input [511:0]				port1_data_i,
	output reg[511:0]			port1_data_o,
	input						port1_write_i);

	reg[7:0]					data63[0:MEM_COUNT - 1];
	reg[7:0]					data62[0:MEM_COUNT - 1];
	reg[7:0]					data61[0:MEM_COUNT - 1];
	reg[7:0]					data60[0:MEM_COUNT - 1];
	reg[7:0]					data59[0:MEM_COUNT - 1];
	reg[7:0]					data58[0:MEM_COUNT - 1];
	reg[7:0]					data57[0:MEM_COUNT - 1];
	reg[7:0]					data56[0:MEM_COUNT - 1];
	reg[7:0]					data55[0:MEM_COUNT - 1];
	reg[7:0]					data54[0:MEM_COUNT - 1];
	reg[7:0]					data53[0:MEM_COUNT - 1];
	reg[7:0]					data52[0:MEM_COUNT - 1];
	reg[7:0]					data51[0:MEM_COUNT - 1];
	reg[7:0]					data50[0:MEM_COUNT - 1];
	reg[7:0]					data49[0:MEM_COUNT - 1];
	reg[7:0]					data48[0:MEM_COUNT - 1];
	reg[7:0]					data47[0:MEM_COUNT - 1];
	reg[7:0]					data46[0:MEM_COUNT - 1];
	reg[7:0]					data45[0:MEM_COUNT - 1];
	reg[7:0]					data44[0:MEM_COUNT - 1];
	reg[7:0]					data43[0:MEM_COUNT - 1];
	reg[7:0]					data42[0:MEM_COUNT - 1];
	reg[7:0]					data41[0:MEM_COUNT - 1];
	reg[7:0]					data40[0:MEM_COUNT - 1];
	reg[7:0]					data39[0:MEM_COUNT - 1];
	reg[7:0]					data38[0:MEM_COUNT - 1];
	reg[7:0]					data37[0:MEM_COUNT - 1];
	reg[7:0]					data36[0:MEM_COUNT - 1];
	reg[7:0]					data35[0:MEM_COUNT - 1];
	reg[7:0]					data34[0:MEM_COUNT - 1];
	reg[7:0]					data33[0:MEM_COUNT - 1];
	reg[7:0]					data32[0:MEM_COUNT - 1];
	reg[7:0]					data31[0:MEM_COUNT - 1];
	reg[7:0]					data30[0:MEM_COUNT - 1];
	reg[7:0]					data29[0:MEM_COUNT - 1];
	reg[7:0]					data28[0:MEM_COUNT - 1];
	reg[7:0]					data27[0:MEM_COUNT - 1];
	reg[7:0]					data26[0:MEM_COUNT - 1];
	reg[7:0]					data25[0:MEM_COUNT - 1];
	reg[7:0]					data24[0:MEM_COUNT - 1];
	reg[7:0]					data23[0:MEM_COUNT - 1];
	reg[7:0]					data22[0:MEM_COUNT - 1];
	reg[7:0]					data21[0:MEM_COUNT - 1];
	reg[7:0]					data20[0:MEM_COUNT - 1];
	reg[7:0]					data19[0:MEM_COUNT - 1];
	reg[7:0]					data18[0:MEM_COUNT - 1];
	reg[7:0]					data17[0:MEM_COUNT - 1];
	reg[7:0]					data16[0:MEM_COUNT - 1];
	reg[7:0]					data15[0:MEM_COUNT - 1];
	reg[7:0]					data14[0:MEM_COUNT - 1];
	reg[7:0]					data13[0:MEM_COUNT - 1];
	reg[7:0]					data12[0:MEM_COUNT - 1];
	reg[7:0]					data11[0:MEM_COUNT - 1];
	reg[7:0]					data10[0:MEM_COUNT - 1];
	reg[7:0]					data9[0:MEM_COUNT - 1];
	reg[7:0]					data8[0:MEM_COUNT - 1];
	reg[7:0]					data7[0:MEM_COUNT - 1];
	reg[7:0]					data6[0:MEM_COUNT - 1];
	reg[7:0]					data5[0:MEM_COUNT - 1];
	reg[7:0]					data4[0:MEM_COUNT - 1];
	reg[7:0]					data3[0:MEM_COUNT - 1];
	reg[7:0]					data2[0:MEM_COUNT - 1];
	reg[7:0]					data1[0:MEM_COUNT - 1];
	reg[7:0]					data0[0:MEM_COUNT - 1];
	integer						i;

	initial
	begin
		for (i = 0; i < MEM_COUNT; i = i + 1)
		begin
			data0[i] = 0;
			data1[i] = 0;
			data2[i] = 0;
			data3[i] = 0;
			data4[i] = 0;
			data5[i] = 0;
			data6[i] = 0;
			data7[i] = 0;
			data8[i] = 0;
			data9[i] = 0;
			data10[i] = 0;
			data11[i] = 0;
			data12[i] = 0;
			data13[i] = 0;
			data14[i] = 0;
			data15[i] = 0;
			data16[i] = 0;
			data17[i] = 0;
			data18[i] = 0;
			data19[i] = 0;
			data20[i] = 0;
			data21[i] = 0;
			data22[i] = 0;
			data23[i] = 0;
			data24[i] = 0;
			data25[i] = 0;
			data26[i] = 0;
			data27[i] = 0;
			data28[i] = 0;
			data29[i] = 0;
			data30[i] = 0;
			data31[i] = 0;
			data32[i] = 0;
			data33[i] = 0;
			data34[i] = 0;
			data35[i] = 0;
			data36[i] = 0;
			data37[i] = 0;
			data38[i] = 0;
			data39[i] = 0;
			data40[i] = 0;
			data41[i] = 0;
			data42[i] = 0;
			data43[i] = 0;
			data44[i] = 0;
			data45[i] = 0;
			data46[i] = 0;
			data47[i] = 0;
			data48[i] = 0;
			data49[i] = 0;
			data50[i] = 0;
			data51[i] = 0;
			data52[i] = 0;
			data53[i] = 0;
			data54[i] = 0;
			data55[i] = 0;
			data56[i] = 0;
			data57[i] = 0;
			data58[i] = 0;
			data59[i] = 0;
			data60[i] = 0;
			data61[i] = 0;
			data62[i] = 0;
			data63[i] = 0;
		end
	end

	always @(posedge clk)
	begin
		if (port0_write_i)
		begin
			if (port0_byte_enable_i[63]) data63[port0_addr_i] <= #1 port0_data_i[511:504];
			if (port0_byte_enable_i[62]) data62[port0_addr_i] <= #1 port0_data_i[503:496];
			if (port0_byte_enable_i[61]) data61[port0_addr_i] <= #1 port0_data_i[495:488];
			if (port0_byte_enable_i[60]) data60[port0_addr_i] <= #1 port0_data_i[487:480];
			if (port0_byte_enable_i[59]) data59[port0_addr_i] <= #1 port0_data_i[479:472];
			if (port0_byte_enable_i[58]) data58[port0_addr_i] <= #1 port0_data_i[471:464];
			if (port0_byte_enable_i[57]) data57[port0_addr_i] <= #1 port0_data_i[463:456];
			if (port0_byte_enable_i[56]) data56[port0_addr_i] <= #1 port0_data_i[455:448];
			if (port0_byte_enable_i[55]) data55[port0_addr_i] <= #1 port0_data_i[447:440];
			if (port0_byte_enable_i[54]) data54[port0_addr_i] <= #1 port0_data_i[439:432];
			if (port0_byte_enable_i[53]) data53[port0_addr_i] <= #1 port0_data_i[431:424];
			if (port0_byte_enable_i[52]) data52[port0_addr_i] <= #1 port0_data_i[423:416];
			if (port0_byte_enable_i[51]) data51[port0_addr_i] <= #1 port0_data_i[415:408];
			if (port0_byte_enable_i[50]) data50[port0_addr_i] <= #1 port0_data_i[407:400];
			if (port0_byte_enable_i[49]) data49[port0_addr_i] <= #1 port0_data_i[399:392];
			if (port0_byte_enable_i[48]) data48[port0_addr_i] <= #1 port0_data_i[391:384];
			if (port0_byte_enable_i[47]) data47[port0_addr_i] <= #1 port0_data_i[383:376];
			if (port0_byte_enable_i[46]) data46[port0_addr_i] <= #1 port0_data_i[375:368];
			if (port0_byte_enable_i[45]) data45[port0_addr_i] <= #1 port0_data_i[367:360];
			if (port0_byte_enable_i[44]) data44[port0_addr_i] <= #1 port0_data_i[359:352];
			if (port0_byte_enable_i[43]) data43[port0_addr_i] <= #1 port0_data_i[351:344];
			if (port0_byte_enable_i[42]) data42[port0_addr_i] <= #1 port0_data_i[343:336];
			if (port0_byte_enable_i[41]) data41[port0_addr_i] <= #1 port0_data_i[335:328];
			if (port0_byte_enable_i[40]) data40[port0_addr_i] <= #1 port0_data_i[327:320];
			if (port0_byte_enable_i[39]) data39[port0_addr_i] <= #1 port0_data_i[319:312];
			if (port0_byte_enable_i[38]) data38[port0_addr_i] <= #1 port0_data_i[311:304];
			if (port0_byte_enable_i[37]) data37[port0_addr_i] <= #1 port0_data_i[303:296];
			if (port0_byte_enable_i[36]) data36[port0_addr_i] <= #1 port0_data_i[295:288];
			if (port0_byte_enable_i[35]) data35[port0_addr_i] <= #1 port0_data_i[287:280];
			if (port0_byte_enable_i[34]) data34[port0_addr_i] <= #1 port0_data_i[279:272];
			if (port0_byte_enable_i[33]) data33[port0_addr_i] <= #1 port0_data_i[271:264];
			if (port0_byte_enable_i[32]) data32[port0_addr_i] <= #1 port0_data_i[263:256];
			if (port0_byte_enable_i[31]) data31[port0_addr_i] <= #1 port0_data_i[255:248];
			if (port0_byte_enable_i[30]) data30[port0_addr_i] <= #1 port0_data_i[247:240];
			if (port0_byte_enable_i[29]) data29[port0_addr_i] <= #1 port0_data_i[239:232];
			if (port0_byte_enable_i[28]) data28[port0_addr_i] <= #1 port0_data_i[231:224];
			if (port0_byte_enable_i[27]) data27[port0_addr_i] <= #1 port0_data_i[223:216];
			if (port0_byte_enable_i[26]) data26[port0_addr_i] <= #1 port0_data_i[215:208];
			if (port0_byte_enable_i[25]) data25[port0_addr_i] <= #1 port0_data_i[207:200];
			if (port0_byte_enable_i[24]) data24[port0_addr_i] <= #1 port0_data_i[199:192];
			if (port0_byte_enable_i[23]) data23[port0_addr_i] <= #1 port0_data_i[191:184];
			if (port0_byte_enable_i[22]) data22[port0_addr_i] <= #1 port0_data_i[183:176];
			if (port0_byte_enable_i[21]) data21[port0_addr_i] <= #1 port0_data_i[175:168];
			if (port0_byte_enable_i[20]) data20[port0_addr_i] <= #1 port0_data_i[167:160];
			if (port0_byte_enable_i[19]) data19[port0_addr_i] <= #1 port0_data_i[159:152];
			if (port0_byte_enable_i[18]) data18[port0_addr_i] <= #1 port0_data_i[151:144];
			if (port0_byte_enable_i[17]) data17[port0_addr_i] <= #1 port0_data_i[143:136];
			if (port0_byte_enable_i[16]) data16[port0_addr_i] <= #1 port0_data_i[135:128];
			if (port0_byte_enable_i[15]) data15[port0_addr_i] <= #1 port0_data_i[127:120];
			if (port0_byte_enable_i[14]) data14[port0_addr_i] <= #1 port0_data_i[119:112];
			if (port0_byte_enable_i[13]) data13[port0_addr_i] <= #1 port0_data_i[111:104];
			if (port0_byte_enable_i[12]) data12[port0_addr_i] <= #1 port0_data_i[103:96];
			if (port0_byte_enable_i[11]) data11[port0_addr_i] <= #1 port0_data_i[95:88];
			if (port0_byte_enable_i[10]) data10[port0_addr_i] <= #1 port0_data_i[87:80];
			if (port0_byte_enable_i[9]) data9[port0_addr_i] <= #1 port0_data_i[79:72];
			if (port0_byte_enable_i[8]) data8[port0_addr_i] <= #1 port0_data_i[71:64];
			if (port0_byte_enable_i[7]) data7[port0_addr_i] <= #1 port0_data_i[63:56];
			if (port0_byte_enable_i[6]) data6[port0_addr_i] <= #1 port0_data_i[55:48];
			if (port0_byte_enable_i[5]) data5[port0_addr_i] <= #1 port0_data_i[47:40];
			if (port0_byte_enable_i[4]) data4[port0_addr_i] <= #1 port0_data_i[39:32];
			if (port0_byte_enable_i[3]) data3[port0_addr_i] <= #1 port0_data_i[31:24];
			if (port0_byte_enable_i[2]) data2[port0_addr_i] <= #1 port0_data_i[23:16];
			if (port0_byte_enable_i[1]) data1[port0_addr_i] <= #1 port0_data_i[15:8];
			if (port0_byte_enable_i[0]) data0[port0_addr_i] <= #1 port0_data_i[7:0];
		end
	end

	always @(posedge clk)
	begin
		port0_data_o <= #1 {
			data63[port0_addr_i],
			data62[port0_addr_i],
			data61[port0_addr_i],
			data60[port0_addr_i],
			data59[port0_addr_i],
			data58[port0_addr_i],
			data57[port0_addr_i],
			data56[port0_addr_i],
			data55[port0_addr_i],
			data54[port0_addr_i],
			data53[port0_addr_i],
			data52[port0_addr_i],
			data51[port0_addr_i],
			data50[port0_addr_i],
			data49[port0_addr_i],
			data48[port0_addr_i],
			data47[port0_addr_i],
			data46[port0_addr_i],
			data45[port0_addr_i],
			data44[port0_addr_i],
			data43[port0_addr_i],
			data42[port0_addr_i],
			data41[port0_addr_i],
			data40[port0_addr_i],
			data39[port0_addr_i],
			data38[port0_addr_i],
			data37[port0_addr_i],
			data36[port0_addr_i],
			data35[port0_addr_i],
			data34[port0_addr_i],
			data33[port0_addr_i],
			data32[port0_addr_i],
			data31[port0_addr_i],
			data30[port0_addr_i],
			data29[port0_addr_i],
			data28[port0_addr_i],
			data27[port0_addr_i],
			data26[port0_addr_i],
			data25[port0_addr_i],
			data24[port0_addr_i],
			data23[port0_addr_i],
			data22[port0_addr_i],
			data21[port0_addr_i],
			data20[port0_addr_i],
			data19[port0_addr_i],
			data18[port0_addr_i],
			data17[port0_addr_i],
			data16[port0_addr_i],
			data15[port0_addr_i],
			data14[port0_addr_i],
			data13[port0_addr_i],
			data12[port0_addr_i],
			data11[port0_addr_i],
			data10[port0_addr_i],
			data9[port0_addr_i],
			data8[port0_addr_i],
			data7[port0_addr_i],
			data6[port0_addr_i],
			data5[port0_addr_i],
			data4[port0_addr_i],
			data3[port0_addr_i],
			data2[port0_addr_i],
			data1[port0_addr_i],
			data0[port0_addr_i]		
		};
	end


	always @(posedge clk)
	begin
		port1_data_o <= #1 {
			data63[port1_addr_i],
			data62[port1_addr_i],
			data61[port1_addr_i],
			data60[port1_addr_i],
			data59[port1_addr_i],
			data58[port1_addr_i],
			data57[port1_addr_i],
			data56[port1_addr_i],
			data55[port1_addr_i],
			data54[port1_addr_i],
			data53[port1_addr_i],
			data52[port1_addr_i],
			data51[port1_addr_i],
			data50[port1_addr_i],
			data49[port1_addr_i],
			data48[port1_addr_i],
			data47[port1_addr_i],
			data46[port1_addr_i],
			data45[port1_addr_i],
			data44[port1_addr_i],
			data43[port1_addr_i],
			data42[port1_addr_i],
			data41[port1_addr_i],
			data40[port1_addr_i],
			data39[port1_addr_i],
			data38[port1_addr_i],
			data37[port1_addr_i],
			data36[port1_addr_i],
			data35[port1_addr_i],
			data34[port1_addr_i],
			data33[port1_addr_i],
			data32[port1_addr_i],
			data31[port1_addr_i],
			data30[port1_addr_i],
			data29[port1_addr_i],
			data28[port1_addr_i],
			data27[port1_addr_i],
			data26[port1_addr_i],
			data25[port1_addr_i],
			data24[port1_addr_i],
			data23[port1_addr_i],
			data22[port1_addr_i],
			data21[port1_addr_i],
			data20[port1_addr_i],
			data19[port1_addr_i],
			data18[port1_addr_i],
			data17[port1_addr_i],
			data16[port1_addr_i],
			data15[port1_addr_i],
			data14[port1_addr_i],
			data13[port1_addr_i],
			data12[port1_addr_i],
			data11[port1_addr_i],
			data10[port1_addr_i],
			data9[port1_addr_i],
			data8[port1_addr_i],
			data7[port1_addr_i],
			data6[port1_addr_i],
			data5[port1_addr_i],
			data4[port1_addr_i],
			data3[port1_addr_i],
			data2[port1_addr_i],
			data1[port1_addr_i],
			data0[port1_addr_i]		
		};
	end

	always @(posedge clk)
	begin
		if (port1_write_i)
		begin
			data63[port1_addr_i] <= #1 port1_data_i[511:504];
			data62[port1_addr_i] <= #1 port1_data_i[503:496];
			data61[port1_addr_i] <= #1 port1_data_i[495:488];
			data60[port1_addr_i] <= #1 port1_data_i[487:480];
			data59[port1_addr_i] <= #1 port1_data_i[479:472];
			data58[port1_addr_i] <= #1 port1_data_i[471:464];
			data57[port1_addr_i] <= #1 port1_data_i[463:456];
			data56[port1_addr_i] <= #1 port1_data_i[455:448];
			data55[port1_addr_i] <= #1 port1_data_i[447:440];
			data54[port1_addr_i] <= #1 port1_data_i[439:432];
			data53[port1_addr_i] <= #1 port1_data_i[431:424];
			data52[port1_addr_i] <= #1 port1_data_i[423:416];
			data51[port1_addr_i] <= #1 port1_data_i[415:408];
			data50[port1_addr_i] <= #1 port1_data_i[407:400];
			data49[port1_addr_i] <= #1 port1_data_i[399:392];
			data48[port1_addr_i] <= #1 port1_data_i[391:384];
			data47[port1_addr_i] <= #1 port1_data_i[383:376];
			data46[port1_addr_i] <= #1 port1_data_i[375:368];
			data45[port1_addr_i] <= #1 port1_data_i[367:360];
			data44[port1_addr_i] <= #1 port1_data_i[359:352];
			data43[port1_addr_i] <= #1 port1_data_i[351:344];
			data42[port1_addr_i] <= #1 port1_data_i[343:336];
			data41[port1_addr_i] <= #1 port1_data_i[335:328];
			data40[port1_addr_i] <= #1 port1_data_i[327:320];
			data39[port1_addr_i] <= #1 port1_data_i[319:312];
			data38[port1_addr_i] <= #1 port1_data_i[311:304];
			data37[port1_addr_i] <= #1 port1_data_i[303:296];
			data36[port1_addr_i] <= #1 port1_data_i[295:288];
			data35[port1_addr_i] <= #1 port1_data_i[287:280];
			data34[port1_addr_i] <= #1 port1_data_i[279:272];
			data33[port1_addr_i] <= #1 port1_data_i[271:264];
			data32[port1_addr_i] <= #1 port1_data_i[263:256];
			data31[port1_addr_i] <= #1 port1_data_i[255:248];
			data30[port1_addr_i] <= #1 port1_data_i[247:240];
			data29[port1_addr_i] <= #1 port1_data_i[239:232];
			data28[port1_addr_i] <= #1 port1_data_i[231:224];
			data27[port1_addr_i] <= #1 port1_data_i[223:216];
			data26[port1_addr_i] <= #1 port1_data_i[215:208];
			data25[port1_addr_i] <= #1 port1_data_i[207:200];
			data24[port1_addr_i] <= #1 port1_data_i[199:192];
			data23[port1_addr_i] <= #1 port1_data_i[191:184];
			data22[port1_addr_i] <= #1 port1_data_i[183:176];
			data21[port1_addr_i] <= #1 port1_data_i[175:168];
			data20[port1_addr_i] <= #1 port1_data_i[167:160];
			data19[port1_addr_i] <= #1 port1_data_i[159:152];
			data18[port1_addr_i] <= #1 port1_data_i[151:144];
			data17[port1_addr_i] <= #1 port1_data_i[143:136];
			data16[port1_addr_i] <= #1 port1_data_i[135:128];
			data15[port1_addr_i] <= #1 port1_data_i[127:120];
			data14[port1_addr_i] <= #1 port1_data_i[119:112];
			data13[port1_addr_i] <= #1 port1_data_i[111:104];
			data12[port1_addr_i] <= #1 port1_data_i[103:96];
			data11[port1_addr_i] <= #1 port1_data_i[95:88];
			data10[port1_addr_i] <= #1 port1_data_i[87:80];
			data9[port1_addr_i] <= #1 port1_data_i[79:72];
			data8[port1_addr_i] <= #1 port1_data_i[71:64];
			data7[port1_addr_i] <= #1 port1_data_i[63:56];
			data6[port1_addr_i] <= #1 port1_data_i[55:48];
			data5[port1_addr_i] <= #1 port1_data_i[47:40];
			data4[port1_addr_i] <= #1 port1_data_i[39:32];
			data3[port1_addr_i] <= #1 port1_data_i[31:24];
			data2[port1_addr_i] <= #1 port1_data_i[23:16];
			data1[port1_addr_i] <= #1 port1_data_i[15:8];
			data0[port1_addr_i] <= #1 port1_data_i[7:0];
		end
	end


endmodule
