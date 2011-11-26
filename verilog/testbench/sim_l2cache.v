//
// This is actually a testing placeholder right now.  It is a hybrid that 
// simulates the L1 instruction cache and the L2 interface for data.
//  

module sim_l2cache
	#(parameter MEM_SIZE = 'h100000)

	(input						clk,

	// Instruction Read Port
	input[31:0]					iaddress_i,
	output reg[31:0]			idata_o,
	input						iaccess_i,

	// Data Read Port
	input						port0_read_i,
	output reg					port0_ack_o,
	input[25:0]					port0_addr_i,
	output reg[511:0]			port0_data_o,

	// Data Write Port
	input						port1_write_i,
	output reg					port1_ack_o,
	input [25:0]				port1_addr_i,
	input [511:0]				port1_data_i,
	input [63:0]				port1_mask_i);

	reg[31:0]					data[0:MEM_SIZE - 1];
	wire[511:0]					orig_data;
	reg							port1_access_stage1;
	wire[31:0]					port1_addr;
	wire[31:0]					port0_addr;
	integer						i;

	initial
	begin
		idata_o = 0;
		port0_data_o = 0;
		port1_ack_o = 0;
		port1_ack_o = 0;
		port1_access_stage1 = 0;
		for (i = 0; i < MEM_SIZE; i = i + 1)
			data[i] = 0;
	end

	//
	// Instruction port
	//
	always @(posedge clk)
	begin
		if (iaccess_i)
			idata_o <= #1 data[iaddress_i[31:2]];
	end

	// 
	// Port 0
	//
	assign port0_addr = { port0_addr_i, 4'd0 };

	always @(posedge clk)
	begin
		port0_ack_o <= #1 port0_read_i;

		if (port0_read_i)
		begin
			port0_data_o <= #1 {
				data[port0_addr],
				data[port0_addr + 1],
				data[port0_addr + 2],
				data[port0_addr + 3],
				data[port0_addr + 4],
				data[port0_addr + 5],
				data[port0_addr + 6],
				data[port0_addr + 7],
				data[port0_addr + 8],
				data[port0_addr + 9],
				data[port0_addr + 10],
				data[port0_addr + 11],
				data[port0_addr + 12],
				data[port0_addr + 13],
				data[port0_addr + 14],
				data[port0_addr + 15]
			};	
		end
	end

	
	//
	// Port 1 (write)
	//
	assign port1_addr = { port1_addr_i, 4'd0 };

	assign orig_data = {
		data[port1_addr],
		data[port1_addr + 1],
		data[port1_addr + 2],
		data[port1_addr + 3],
		data[port1_addr + 4],
		data[port1_addr + 5],
		data[port1_addr + 6],
		data[port1_addr + 7],
		data[port1_addr + 8],
		data[port1_addr + 9],
		data[port1_addr + 10],
		data[port1_addr + 11],
		data[port1_addr + 12],
		data[port1_addr + 13],
		data[port1_addr + 14],
		data[port1_addr + 15]
	};

	always @(posedge clk)
	begin
		port1_ack_o <= port1_write_i;

		if (port1_write_i)
		begin
			data[port1_addr] <= #1 {
				port1_mask_i[63]	? port1_data_i[511:504]	: orig_data[511:504],
				port1_mask_i[62]	? port1_data_i[503:496]	: orig_data[503:496],
				port1_mask_i[61]	? port1_data_i[495:488]	: orig_data[495:488],
				port1_mask_i[60]	? port1_data_i[487:480]	: orig_data[487:480]
			};

			data[port1_addr + 1] <= #1 {
				port1_mask_i[59]	? port1_data_i[479:472]	: orig_data[479:472],
				port1_mask_i[58]	? port1_data_i[471:464]	: orig_data[471:464],
				port1_mask_i[57]	? port1_data_i[463:456]	: orig_data[463:456],
				port1_mask_i[56]	? port1_data_i[455:448]	: orig_data[455:448]
			};

			data[port1_addr + 2] <= #1 {
				port1_mask_i[55]	? port1_data_i[447:440]	: orig_data[447:440],
				port1_mask_i[54]	? port1_data_i[439:432]	: orig_data[439:432],
				port1_mask_i[53]	? port1_data_i[431:424]	: orig_data[431:424],
				port1_mask_i[52]	? port1_data_i[423:416]	: orig_data[423:416]
			};

			data[port1_addr + 3] <= #1 {
				port1_mask_i[51]	? port1_data_i[415:408]	: orig_data[415:408],
				port1_mask_i[50]	? port1_data_i[407:400]	: orig_data[407:400],
				port1_mask_i[49]	? port1_data_i[399:392]	: orig_data[399:392],
				port1_mask_i[48]	? port1_data_i[391:384]	: orig_data[391:384]
			};

			data[port1_addr + 4] <= #1 {
				port1_mask_i[47]	? port1_data_i[383:376]	: orig_data[383:376],
				port1_mask_i[46]	? port1_data_i[375:368]	: orig_data[375:368],
				port1_mask_i[45]	? port1_data_i[367:360]	: orig_data[367:360],
				port1_mask_i[44]	? port1_data_i[359:352]	: orig_data[359:352]
			};

			data[port1_addr + 5] <= #1 {
				port1_mask_i[43]	? port1_data_i[351:344]	: orig_data[351:344],
				port1_mask_i[42]	? port1_data_i[343:336]	: orig_data[343:336],
				port1_mask_i[41]	? port1_data_i[335:328]	: orig_data[335:328],
				port1_mask_i[40]	? port1_data_i[327:320]	: orig_data[327:320]
			};

			data[port1_addr + 6] <= #1 {
				port1_mask_i[39]	? port1_data_i[319:312]	: orig_data[319:312],
				port1_mask_i[38]	? port1_data_i[311:304]	: orig_data[311:304],
				port1_mask_i[37]	? port1_data_i[303:296]	: orig_data[303:296],
				port1_mask_i[36]	? port1_data_i[295:288]	: orig_data[295:288]
			};

			data[port1_addr + 7] <= #1 {
				port1_mask_i[35]	? port1_data_i[287:280]	: orig_data[287:280],
				port1_mask_i[34]	? port1_data_i[279:272]	: orig_data[279:272],
				port1_mask_i[33]	? port1_data_i[271:264]	: orig_data[271:264],
				port1_mask_i[32]	? port1_data_i[263:256]	: orig_data[263:256]
			};

			data[port1_addr + 8] <= #1 {
				port1_mask_i[31]	? port1_data_i[255:248]	: orig_data[255:248],
				port1_mask_i[30]	? port1_data_i[247:240]	: orig_data[247:240],
				port1_mask_i[29]	? port1_data_i[239:232]	: orig_data[239:232],
				port1_mask_i[28]	? port1_data_i[225:024]	: orig_data[225:024]
			};

			data[port1_addr + 9] <= #1 {
				port1_mask_i[27]	? port1_data_i[223:216]	: orig_data[223:216],
				port1_mask_i[26]	? port1_data_i[215:208]	: orig_data[215:208],
				port1_mask_i[25]	? port1_data_i[207:200]	: orig_data[207:200],
				port1_mask_i[24]	? port1_data_i[199:192]	: orig_data[199:192]
			};

			data[port1_addr + 10] <= #1 {
				port1_mask_i[23]	? port1_data_i[191:184]	: orig_data[191:184],
				port1_mask_i[22]	? port1_data_i[183:176]	: orig_data[183:176],
				port1_mask_i[21]	? port1_data_i[175:168]	: orig_data[175:168],
				port1_mask_i[20]	? port1_data_i[167:160]	: orig_data[167:160]
			};

			data[port1_addr + 11] <= #1 {
				port1_mask_i[19]	? port1_data_i[159:152]	: orig_data[159:152],
				port1_mask_i[18]	? port1_data_i[151:144]	: orig_data[151:144],
				port1_mask_i[17]	? port1_data_i[143:136]	: orig_data[143:136],
				port1_mask_i[16]	? port1_data_i[135:128]	: orig_data[135:128]
			};

			data[port1_addr + 12] <= #1 {
				port1_mask_i[15]	? port1_data_i[127:120]	: orig_data[127:120],
				port1_mask_i[14]	? port1_data_i[119:112]	: orig_data[119:112],
				port1_mask_i[13]	? port1_data_i[111:104]	: orig_data[111:104],
				port1_mask_i[12]	? port1_data_i[103:96]	: orig_data[103:96]
			};

			data[port1_addr + 13] <= #1 {
				port1_mask_i[11]	? port1_data_i[95:88]	: orig_data[95:88],
				port1_mask_i[10]	? port1_data_i[87:80]	: orig_data[87:80],
				port1_mask_i[9]	? port1_data_i[79:72]	: orig_data[79:72],
				port1_mask_i[8]	? port1_data_i[71:64]	: orig_data[71:64]
			};

			data[port1_addr + 14] <= #1 {
				port1_mask_i[7]	? port1_data_i[63:56]	: orig_data[63:56],
				port1_mask_i[6]	? port1_data_i[55:48]	: orig_data[55:48],
				port1_mask_i[5]	? port1_data_i[47:40]	: orig_data[47:40],
				port1_mask_i[4]	? port1_data_i[39:32]	: orig_data[39:32]
			};

			data[port1_addr + 15] <= #1 {
				port1_mask_i[3]	? port1_data_i[25:04]	: orig_data[25:04],
				port1_mask_i[2]	? port1_data_i[23:16]	: orig_data[23:16],
				port1_mask_i[1]	? port1_data_i[15:8]	: orig_data[15:8],
				port1_mask_i[0]	? port1_data_i[7:0]	: orig_data[7:0]
			};
		end
	end

endmodule
