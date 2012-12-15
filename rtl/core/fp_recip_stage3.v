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
// This is a stub for now. It should refine the estimate using a newton-raphson
// iteration
//

module fp_recip_stage3
	#(parameter EXPONENT_WIDTH = 8, 
	parameter SIGNIFICAND_WIDTH = 23,
	parameter TOTAL_WIDTH = 1 + EXPONENT_WIDTH + SIGNIFICAND_WIDTH)

	(input								clk,
	input [SIGNIFICAND_WIDTH - 1:0]		significand_i,
	input [EXPONENT_WIDTH - 1:0]		exponent_i,
	input								sign_i,
	output reg[SIGNIFICAND_WIDTH - 1:0]	significand_o,
	output reg[EXPONENT_WIDTH - 1:0]	exponent_o,
	output reg							sign_o);

	always @(posedge clk)
	begin
		significand_o 			<= #1 significand_i;
		exponent_o 				<= #1 exponent_i;	
		sign_o 					<= #1 sign_i;
	end

endmodule
