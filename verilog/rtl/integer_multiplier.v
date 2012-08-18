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
// The integer multiplier has 3 cycles of latency.
// This is a stub for now.  It is intended to be replaced by something
// like a wallace tree.
//

module integer_multiplier(
	input wire 					clk,
	input [31:0]				multiplicand_i,
	input [31:0]				multiplier_i,
	output reg[47:0]			product_o = 0);
	
	reg[47:0]					product1 = 0;
	reg[47:0]					product2 = 0;

	always @(posedge clk)
	begin
		product1 <= #1 multiplicand_i * multiplier_i;
		product2 <= #1 product1;
		product_o <= #1 product2;
	end
endmodule
