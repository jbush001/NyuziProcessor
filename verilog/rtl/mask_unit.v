// 
// Copyright 2011-2012 Jeff Bush
// 
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
// 
//     http://www.apache.org/licenses/LICENSE-2.0
// 
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
// 

//
// Multiplexes on a per-byte basis between two sources.  Used to 
// bypass pending stores on L1 data cache accesses.  A 1 bit selects
// from data0_i and a 0 bit selects from data1_i (XXX is that backward from
// what one would logically expect?)
// 

module mask_unit(
	input [63:0] 			mask_i,
	input [511:0] 			data0_i,
	input [511:0] 			data1_i,
	output [511:0] 			result_o);

	assign result_o = {
		mask_i[63] ? data0_i[511:504] : data1_i[511:504],
		mask_i[62] ? data0_i[503:496] : data1_i[503:496],
		mask_i[61] ? data0_i[495:488] : data1_i[495:488],
		mask_i[60] ? data0_i[487:480] : data1_i[487:480],
		mask_i[59] ? data0_i[479:472] : data1_i[479:472],
		mask_i[58] ? data0_i[471:464] : data1_i[471:464],
		mask_i[57] ? data0_i[463:456] : data1_i[463:456],
		mask_i[56] ? data0_i[455:448] : data1_i[455:448],
		mask_i[55] ? data0_i[447:440] : data1_i[447:440],
		mask_i[54] ? data0_i[439:432] : data1_i[439:432],
		mask_i[53] ? data0_i[431:424] : data1_i[431:424],
		mask_i[52] ? data0_i[423:416] : data1_i[423:416],
		mask_i[51] ? data0_i[415:408] : data1_i[415:408],
		mask_i[50] ? data0_i[407:400] : data1_i[407:400],
		mask_i[49] ? data0_i[399:392] : data1_i[399:392],
		mask_i[48] ? data0_i[391:384] : data1_i[391:384],
		mask_i[47] ? data0_i[383:376] : data1_i[383:376],
		mask_i[46] ? data0_i[375:368] : data1_i[375:368],
		mask_i[45] ? data0_i[367:360] : data1_i[367:360],
		mask_i[44] ? data0_i[359:352] : data1_i[359:352],
		mask_i[43] ? data0_i[351:344] : data1_i[351:344],
		mask_i[42] ? data0_i[343:336] : data1_i[343:336],
		mask_i[41] ? data0_i[335:328] : data1_i[335:328],
		mask_i[40] ? data0_i[327:320] : data1_i[327:320],
		mask_i[39] ? data0_i[319:312] : data1_i[319:312],
		mask_i[38] ? data0_i[311:304] : data1_i[311:304],
		mask_i[37] ? data0_i[303:296] : data1_i[303:296],
		mask_i[36] ? data0_i[295:288] : data1_i[295:288],
		mask_i[35] ? data0_i[287:280] : data1_i[287:280],
		mask_i[34] ? data0_i[279:272] : data1_i[279:272],
		mask_i[33] ? data0_i[271:264] : data1_i[271:264],
		mask_i[32] ? data0_i[263:256] : data1_i[263:256],
		mask_i[31] ? data0_i[255:248] : data1_i[255:248],
		mask_i[30] ? data0_i[247:240] : data1_i[247:240],
		mask_i[29] ? data0_i[239:232] : data1_i[239:232],
		mask_i[28] ? data0_i[231:224] : data1_i[231:224],
		mask_i[27] ? data0_i[223:216] : data1_i[223:216],
		mask_i[26] ? data0_i[215:208] : data1_i[215:208],
		mask_i[25] ? data0_i[207:200] : data1_i[207:200],
		mask_i[24] ? data0_i[199:192] : data1_i[199:192],
		mask_i[23] ? data0_i[191:184] : data1_i[191:184],
		mask_i[22] ? data0_i[183:176] : data1_i[183:176],
		mask_i[21] ? data0_i[175:168] : data1_i[175:168],
		mask_i[20] ? data0_i[167:160] : data1_i[167:160],
		mask_i[19] ? data0_i[159:152] : data1_i[159:152],
		mask_i[18] ? data0_i[151:144] : data1_i[151:144],
		mask_i[17] ? data0_i[143:136] : data1_i[143:136],
		mask_i[16] ? data0_i[135:128] : data1_i[135:128],
		mask_i[15] ? data0_i[127:120] : data1_i[127:120],
		mask_i[14] ? data0_i[119:112] : data1_i[119:112],
		mask_i[13] ? data0_i[111:104] : data1_i[111:104],
		mask_i[12] ? data0_i[103:96] : data1_i[103:96],
		mask_i[11] ? data0_i[95:88] : data1_i[95:88],
		mask_i[10] ? data0_i[87:80] : data1_i[87:80],
		mask_i[9] ? data0_i[79:72] : data1_i[79:72],
		mask_i[8] ? data0_i[71:64] : data1_i[71:64],
		mask_i[7] ? data0_i[63:56] : data1_i[63:56],
		mask_i[6] ? data0_i[55:48] : data1_i[55:48],
		mask_i[5] ? data0_i[47:40] : data1_i[47:40],
		mask_i[4] ? data0_i[39:32] : data1_i[39:32],
		mask_i[3] ? data0_i[31:24] : data1_i[31:24],
		mask_i[2] ? data0_i[23:16] : data1_i[23:16],
		mask_i[1] ? data0_i[15:8] : data1_i[15:8],
		mask_i[0] ? data0_i[7:0] : data1_i[7:0]
	};
endmodule
