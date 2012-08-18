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
// Storage for vector registers, 2 read ports and 1 write port.
// When a vector register is updated, the mask field controls which
// 32-bit lanes are changed.  For any lane that has a zero in the mask
// bit, the previous value will remain in the register.
//

module vector_register_file(
	input 					clk,
	input [6:0] 			ds_vector_sel1,
	input [6:0] 			ds_vector_sel2,
	output reg [511:0] 		vector_value1 = 0,
	output reg [511:0] 		vector_value2 = 0,
	input [6:0]				wb_writeback_reg,
	input [511:0]			wb_writeback_value,
	input [15:0]			wb_writeback_mask,
	input					enable_vector_reg_store);
	
	localparam NUM_REGISTERS = 4 * 32;

	// 128 registers total (32 per strand * 4 strands)
	reg[31:0]				lane15[0:NUM_REGISTERS - 1];
	reg[31:0]				lane14[0:NUM_REGISTERS - 1];
	reg[31:0]				lane13[0:NUM_REGISTERS - 1];
	reg[31:0]				lane12[0:NUM_REGISTERS - 1];
	reg[31:0]				lane11[0:NUM_REGISTERS - 1];
	reg[31:0]				lane10[0:NUM_REGISTERS - 1];
	reg[31:0]				lane9[0:NUM_REGISTERS - 1];
	reg[31:0]				lane8[0:NUM_REGISTERS - 1];
	reg[31:0]				lane7[0:NUM_REGISTERS - 1];
	reg[31:0]				lane6[0:NUM_REGISTERS - 1];
	reg[31:0]				lane5[0:NUM_REGISTERS - 1];
	reg[31:0]				lane4[0:NUM_REGISTERS - 1];
	reg[31:0]				lane3[0:NUM_REGISTERS - 1];
	reg[31:0]				lane2[0:NUM_REGISTERS - 1];
	reg[31:0]				lane1[0:NUM_REGISTERS - 1];
	reg[31:0]				lane0[0:NUM_REGISTERS - 1];
	integer					i;
	
	initial
	begin
		// synthesis translate_off
		for (i = 0; i < NUM_REGISTERS; i = i + 1)
		begin
			lane15[i] = 0;
			lane14[i] = 0;
			lane13[i] = 0;
			lane12[i] = 0;
			lane11[i] = 0;
			lane10[i] = 0;
			lane9[i] = 0;
			lane8[i] = 0;
			lane7[i] = 0;
			lane6[i] = 0;
			lane5[i] = 0;
			lane4[i] = 0;
			lane3[i] = 0;
			lane2[i] = 0;
			lane1[i] = 0;
			lane0[i] = 0;
		end	
		
		// synthesis translate_on
	end
	
	always @(posedge clk)
	begin
		vector_value1 <= #1 {
			lane15[ds_vector_sel1],
			lane14[ds_vector_sel1],
			lane13[ds_vector_sel1],
			lane12[ds_vector_sel1],
			lane11[ds_vector_sel1],
			lane10[ds_vector_sel1],
			lane9[ds_vector_sel1],
			lane8[ds_vector_sel1],
			lane7[ds_vector_sel1],
			lane6[ds_vector_sel1],
			lane5[ds_vector_sel1],
			lane4[ds_vector_sel1],
			lane3[ds_vector_sel1],
			lane2[ds_vector_sel1],
			lane1[ds_vector_sel1],
			lane0[ds_vector_sel1]
		};
			
		vector_value2 <= #1 {
			lane15[ds_vector_sel2],
			lane14[ds_vector_sel2],
			lane13[ds_vector_sel2],
			lane12[ds_vector_sel2],
			lane11[ds_vector_sel2],
			lane10[ds_vector_sel2],
			lane9[ds_vector_sel2],
			lane8[ds_vector_sel2],
			lane7[ds_vector_sel2],
			lane6[ds_vector_sel2],
			lane5[ds_vector_sel2],
			lane4[ds_vector_sel2],
			lane3[ds_vector_sel2],
			lane2[ds_vector_sel2],
			lane1[ds_vector_sel2],
			lane0[ds_vector_sel2]
		};

		if (enable_vector_reg_store)
		begin
			if (wb_writeback_mask[15]) lane15[wb_writeback_reg] <= #1 wb_writeback_value[511:480];
			if (wb_writeback_mask[14]) lane14[wb_writeback_reg] <= #1 wb_writeback_value[479:448];
			if (wb_writeback_mask[13]) lane13[wb_writeback_reg] <= #1 wb_writeback_value[447:416];
			if (wb_writeback_mask[12]) lane12[wb_writeback_reg] <= #1 wb_writeback_value[415:384];
			if (wb_writeback_mask[11]) lane11[wb_writeback_reg] <= #1 wb_writeback_value[383:352];
			if (wb_writeback_mask[10]) lane10[wb_writeback_reg] <= #1 wb_writeback_value[351:320];
			if (wb_writeback_mask[9]) lane9[wb_writeback_reg] <= #1 wb_writeback_value[319:288];
			if (wb_writeback_mask[8]) lane8[wb_writeback_reg] <= #1 wb_writeback_value[287:256];
			if (wb_writeback_mask[7]) lane7[wb_writeback_reg] <= #1 wb_writeback_value[255:224];
			if (wb_writeback_mask[6]) lane6[wb_writeback_reg] <= #1 wb_writeback_value[223:192];
			if (wb_writeback_mask[5]) lane5[wb_writeback_reg] <= #1 wb_writeback_value[191:160];
			if (wb_writeback_mask[4]) lane4[wb_writeback_reg] <= #1 wb_writeback_value[159:128];
			if (wb_writeback_mask[3]) lane3[wb_writeback_reg] <= #1 wb_writeback_value[127:96];
			if (wb_writeback_mask[2]) lane2[wb_writeback_reg] <= #1 wb_writeback_value[95:64];
			if (wb_writeback_mask[1]) lane1[wb_writeback_reg] <= #1 wb_writeback_value[63:32];
			if (wb_writeback_mask[0]) lane0[wb_writeback_reg] <= #1 wb_writeback_value[31:0];
		end
	end

endmodule
