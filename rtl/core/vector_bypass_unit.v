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
// Vector Bypass Unit
//
// Bypasses vector results that have not yet been committed to the register file
// from later stages in the pipeline.  This must bypass each word lane in the
// vector individually because of predication.
//

module vector_bypass_unit
	(input [6:0] 						register_sel_i,
	input [511:0] 						data_i,
	output [511:0] 						value_o,
	input [6:0] 						bypass1_register_i,
	input 								bypass1_write_i,
	input [511:0] 						bypass1_value_i,
	input [15:0] 						bypass1_mask_i,
	input [6:0] 						bypass2_register_i,
	input 								bypass2_write_i,
	input [511:0] 						bypass2_value_i,
	input [15:0] 						bypass2_mask_i,
	input [6:0] 						bypass3_register_i,
	input 								bypass3_write_i,
	input [511:0] 						bypass3_value_i,
	input [15:0] 						bypass3_mask_i,
	input [6:0] 						bypass4_register_i,
	input 								bypass4_write_i,
	input [511:0] 						bypass4_value_i,
	input [15:0] 						bypass4_mask_i);

	reg[31:0] 							result_lanes[0:15];
	integer 							i;
	integer								j;

	initial
	begin
		for (j = 0; j < 16; j = j + 1)
			result_lanes[j] = 0;
	end

	assign value_o = {
		result_lanes[15],
		result_lanes[14],
		result_lanes[13],
		result_lanes[12],
		result_lanes[11],
		result_lanes[10],
		result_lanes[9],
		result_lanes[8],
		result_lanes[7],
		result_lanes[6],
		result_lanes[5],
		result_lanes[4],
		result_lanes[3],
		result_lanes[2],
		result_lanes[1],
		result_lanes[0]
	};

	wire bypass1_has_value = register_sel_i == bypass1_register_i && bypass1_write_i;
	wire bypass2_has_value = register_sel_i == bypass2_register_i && bypass2_write_i;
	wire bypass3_has_value = register_sel_i == bypass3_register_i && bypass3_write_i;
	wire bypass4_has_value = register_sel_i == bypass4_register_i && bypass4_write_i;

	always @*
	begin
		for (i = 0; i < 16; i = i + 1)
		begin
			if (bypass1_has_value && bypass1_mask_i[i])
				result_lanes[i] = bypass1_value_i >> (i * 32);
			else if (bypass2_has_value && bypass2_mask_i[i])
				result_lanes[i] = bypass2_value_i >> (i * 32);
			else if (bypass3_has_value && bypass3_mask_i[i])
				result_lanes[i] = bypass3_value_i >> (i * 32);
			else if (bypass4_has_value && bypass4_mask_i[i])
				result_lanes[i] = bypass4_value_i >> (i * 32);
			else
				result_lanes[i] = data_i >> (i * 32);
		end
	end
endmodule
