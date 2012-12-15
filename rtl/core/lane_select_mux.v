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
// Given a 512 bit register (which is treated as a vector with 16 32-bit lanes),
// select one of the lanes for output.
//

module lane_select_mux
	#(parameter				ASCENDING_INDEX = 0)
	
	(input [511:0]			value_i,
	input[3:0]				lane_select_i,
	output reg[31:0]		value_o);
	
	always @*
	begin
		case (ASCENDING_INDEX ? 4'd15 - lane_select_i : lane_select_i)
			4'd15:	value_o = value_i[511:480];
			4'd14:	value_o = value_i[479:448];
			4'd13:	value_o = value_i[447:416];
			4'd12:	value_o = value_i[415:384];
			4'd11:	value_o = value_i[383:352];
			4'd10:	value_o = value_i[351:320];
			4'd9:	value_o = value_i[319:288];
			4'd8:	value_o = value_i[287:256];
			4'd7:	value_o = value_i[255:224];
			4'd6:	value_o = value_i[223:192];
			4'd5:	value_o = value_i[191:160];
			4'd4:	value_o = value_i[159:128];
			4'd3:	value_o = value_i[127:96];
			4'd2:	value_o = value_i[95:64];
			4'd1:	value_o = value_i[63:32];
			4'd0:	value_o = value_i[31:0];
		endcase
	end
endmodule
