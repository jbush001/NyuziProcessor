//
// Emulates cache behavior for simulation
//
module sim_cache
	#(parameter MEM_SIZE = 'h100000)

	(input 					clk,
	
	// Instruction Port
	input[31:0]				iaddress_i,
	output reg[31:0]		idata_o,
	input					iaccess_i,
	
	// Data Port
	input[31:0]				daddress_i,
	output reg[511:0]		ddata_o,
	input[511:0]			ddata_i,
	input					dwrite_i,
	input					daccess_i,
	input[63:0]				dwrite_mask_i,
	output reg				dack_o);

	reg[31:0]				data[0:MEM_SIZE - 1];
	wire[511:0] 			orig_data;
	reg[31:0]				daddr_stage_1;
	reg						daccess_stage_1;


	integer i;

	initial
	begin
		idata_o = 0;
		ddata_o = 0;
		for (i = 0; i < MEM_SIZE; i = i + 1)
			data[i] = 0;
			
		dack_o = 0;
	end

	// Instruction read
	always @(posedge clk)
	begin
		if (iaccess_i)
			idata_o <= #1 data[iaddress_i[31:2]];
	end

	// Execute Stage (cycle 0)
	always @(posedge clk)
	begin
		daddr_stage_1 		<= #1 daddress_i;
		daccess_stage_1 	<= #1 daccess_i;
		dack_o 				<= #1 daccess_i;
	end

	// Memory Access Stage (cycle 1)
	// XXX should enforce alignment to 16 byte boundary
	assign orig_data = {
		data[daddr_stage_1[31:2]],
		data[daddr_stage_1[31:2] + 1],
		data[daddr_stage_1[31:2] + 2],
		data[daddr_stage_1[31:2] + 3],
		data[daddr_stage_1[31:2] + 4],
		data[daddr_stage_1[31:2] + 5],
		data[daddr_stage_1[31:2] + 6],
		data[daddr_stage_1[31:2] + 7],
		data[daddr_stage_1[31:2] + 8],
		data[daddr_stage_1[31:2] + 9],
		data[daddr_stage_1[31:2] + 10],
		data[daddr_stage_1[31:2] + 11],
		data[daddr_stage_1[31:2] + 12],
		data[daddr_stage_1[31:2] + 13],
		data[daddr_stage_1[31:2] + 14],
		data[daddr_stage_1[31:2] + 15]
	};

	always @(posedge clk)
	begin
		if (daccess_stage_1 && dwrite_i)
		begin
			data[daddr_stage_1[31:2] + 0] <= #1 {
				dwrite_mask_i[63]	? ddata_i[511:504]	: orig_data[511:504],
				dwrite_mask_i[62]	? ddata_i[503:496]	: orig_data[503:496],
				dwrite_mask_i[61]	? ddata_i[495:488]	: orig_data[495:488],
				dwrite_mask_i[60]	? ddata_i[487:480]	: orig_data[487:480]
			};

			data[daddr_stage_1[31:2] + 1] <= #1 {
				dwrite_mask_i[59]	? ddata_i[479:472]	: orig_data[479:472],
				dwrite_mask_i[58]	? ddata_i[471:464]	: orig_data[471:464],
				dwrite_mask_i[57]	? ddata_i[463:456]	: orig_data[463:456],
				dwrite_mask_i[56]	? ddata_i[455:448]	: orig_data[455:448]
			};

			data[daddr_stage_1[31:2] + 2] <= #1 {
				dwrite_mask_i[55]	? ddata_i[447:440]	: orig_data[447:440],
				dwrite_mask_i[54]	? ddata_i[439:432]	: orig_data[439:432],
				dwrite_mask_i[53]	? ddata_i[431:424]	: orig_data[431:424],
				dwrite_mask_i[52]	? ddata_i[423:416]	: orig_data[423:416]
			};

			data[daddr_stage_1[31:2] + 3] <= #1 {
				dwrite_mask_i[51]	? ddata_i[415:408]	: orig_data[415:408],
				dwrite_mask_i[50]	? ddata_i[407:400]	: orig_data[407:400],
				dwrite_mask_i[49]	? ddata_i[399:392]	: orig_data[399:392],
				dwrite_mask_i[48]	? ddata_i[391:384]	: orig_data[391:384]
			};

			data[daddr_stage_1[31:2] + 4] <= #1 {
				dwrite_mask_i[47]	? ddata_i[383:376]	: orig_data[383:376],
				dwrite_mask_i[46]	? ddata_i[375:368]	: orig_data[375:368],
				dwrite_mask_i[45]	? ddata_i[367:360]	: orig_data[367:360],
				dwrite_mask_i[44]	? ddata_i[359:352]	: orig_data[359:352]
			};

			data[daddr_stage_1[31:2] + 5] <= #1 {
				dwrite_mask_i[43]	? ddata_i[351:344]	: orig_data[351:344],
				dwrite_mask_i[42]	? ddata_i[343:336]	: orig_data[343:336],
				dwrite_mask_i[41]	? ddata_i[335:328]	: orig_data[335:328],
				dwrite_mask_i[40]	? ddata_i[327:320]	: orig_data[327:320]
			};

			data[daddr_stage_1[31:2] + 6] <= #1 {
				dwrite_mask_i[39]	? ddata_i[319:312]	: orig_data[319:312],
				dwrite_mask_i[38]	? ddata_i[311:304]	: orig_data[311:304],
				dwrite_mask_i[37]	? ddata_i[303:296]	: orig_data[303:296],
				dwrite_mask_i[36]	? ddata_i[295:288]	: orig_data[295:288]
			};

			data[daddr_stage_1[31:2] + 7] <= #1 {
				dwrite_mask_i[35]	? ddata_i[287:280]	: orig_data[287:280],
				dwrite_mask_i[34]	? ddata_i[279:272]	: orig_data[279:272],
				dwrite_mask_i[33]	? ddata_i[271:264]	: orig_data[271:264],
				dwrite_mask_i[32]	? ddata_i[263:256]	: orig_data[263:256]
			};

			data[daddr_stage_1[31:2] + 8] <= #1 {
				dwrite_mask_i[31]	? ddata_i[255:248]	: orig_data[255:248],
				dwrite_mask_i[30]	? ddata_i[247:240]	: orig_data[247:240],
				dwrite_mask_i[29]	? ddata_i[239:232]	: orig_data[239:232],
				dwrite_mask_i[28]	? ddata_i[231:224]	: orig_data[231:224]
			};

			data[daddr_stage_1[31:2] + 9] <= #1 {
				dwrite_mask_i[27]	? ddata_i[223:216]	: orig_data[223:216],
				dwrite_mask_i[26]	? ddata_i[215:208]	: orig_data[215:208],
				dwrite_mask_i[25]	? ddata_i[207:200]	: orig_data[207:200],
				dwrite_mask_i[24]	? ddata_i[199:192]	: orig_data[199:192]
			};

			data[daddr_stage_1[31:2] + 10] <= #1 {
				dwrite_mask_i[23]	? ddata_i[191:184]	: orig_data[191:184],
				dwrite_mask_i[22]	? ddata_i[183:176]	: orig_data[183:176],
				dwrite_mask_i[21]	? ddata_i[175:168]	: orig_data[175:168],
				dwrite_mask_i[20]	? ddata_i[167:160]	: orig_data[167:160]
			};

			data[daddr_stage_1[31:2] + 11] <= #1 {
				dwrite_mask_i[19]	? ddata_i[159:152]	: orig_data[159:152],
				dwrite_mask_i[18]	? ddata_i[151:144]	: orig_data[151:144],
				dwrite_mask_i[17]	? ddata_i[143:136]	: orig_data[143:136],
				dwrite_mask_i[16]	? ddata_i[135:128]	: orig_data[135:128]
			};

			data[daddr_stage_1[31:2] + 12] <= #1 {
				dwrite_mask_i[15]	? ddata_i[127:120]	: orig_data[127:120],
				dwrite_mask_i[14]	? ddata_i[119:112]	: orig_data[119:112],
				dwrite_mask_i[13]	? ddata_i[111:104]	: orig_data[111:104],
				dwrite_mask_i[12]	? ddata_i[103:96]	: orig_data[103:96]
			};

			data[daddr_stage_1[31:2] + 13] <= #1 {
				dwrite_mask_i[11]	? ddata_i[95:88]	: orig_data[95:88],
				dwrite_mask_i[10]	? ddata_i[87:80]	: orig_data[87:80],
				dwrite_mask_i[9]	? ddata_i[79:72]	: orig_data[79:72],
				dwrite_mask_i[8]	? ddata_i[71:64]	: orig_data[71:64]
			};

			data[daddr_stage_1[31:2] + 14] <= #1 {
				dwrite_mask_i[7]	? ddata_i[63:56]	: orig_data[63:56],
				dwrite_mask_i[6]	? ddata_i[55:48]	: orig_data[55:48],
				dwrite_mask_i[5]	? ddata_i[47:40]	: orig_data[47:40],
				dwrite_mask_i[4]	? ddata_i[39:32]	: orig_data[39:32]
			};

			data[daddr_stage_1[31:2] + 15] <= #1 {
				dwrite_mask_i[3]	? ddata_i[31:24]	: orig_data[31:24],
				dwrite_mask_i[2]	? ddata_i[23:16]	: orig_data[23:16],
				dwrite_mask_i[1]	? ddata_i[15:8]	: orig_data[15:8],
				dwrite_mask_i[0]	? ddata_i[7:0]	: orig_data[7:0]
			};
		end
	end

	// Data read
	always @(posedge clk)
	begin
		if (daccess_stage_1 && ~dwrite_i)
			ddata_o <= #1 orig_data;
	end
endmodule
