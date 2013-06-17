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
// Stage 2 of the floating point addition pipeline
// - Select the higher exponent to use as the result exponent
// - Shift to align significands
// 

module fp_adder_stage2
	(input									clk,
	input									reset,
	input [5:0] 							add1_operand_align_shift,
	input [`FP_SIGNIFICAND_WIDTH + 2:0] 	add1_significand1,
	input [`FP_SIGNIFICAND_WIDTH + 2:0] 	add1_significand2,
	input [`FP_EXPONENT_WIDTH - 1:0] 		add1_exponent1,
	input [`FP_EXPONENT_WIDTH - 1:0] 		add1_exponent2,
	input  									add1_exponent2_larger,
	output reg[`FP_EXPONENT_WIDTH - 1:0] 	add2_exponent,
	output reg[`FP_SIGNIFICAND_WIDTH + 2:0] add2_significand1,
	output reg[`FP_SIGNIFICAND_WIDTH + 2:0] add2_significand2);

	reg[`FP_EXPONENT_WIDTH - 1:0] unnormalized_exponent_nxt; 

	// Select the higher exponent to use as the result exponent
	always @*
	begin
		if (add1_exponent2_larger)
			unnormalized_exponent_nxt = add1_exponent2;
		else
			unnormalized_exponent_nxt = add1_exponent1;
	end

	// Arithmetic shift right to align significands
	wire[`FP_SIGNIFICAND_WIDTH + 2:0]  aligned2_nxt = {{`FP_SIGNIFICAND_WIDTH{add1_significand2[`FP_SIGNIFICAND_WIDTH + 2]}}, 
			 add1_significand2 } >> add1_operand_align_shift;

	always @(posedge clk, posedge reset)
	begin
		if (reset)
		begin
			/*AUTORESET*/
			// Beginning of autoreset for uninitialized flops
			add2_exponent <= {(1+(`FP_EXPONENT_WIDTH-1)){1'b0}};
			add2_significand1 <= {(1+(`FP_SIGNIFICAND_WIDTH+2)){1'b0}};
			add2_significand2 <= {(1+(`FP_SIGNIFICAND_WIDTH+2)){1'b0}};
			// End of automatics
		end
		else
		begin
			add2_exponent 	<= unnormalized_exponent_nxt;
			add2_significand1 				<= add1_significand1;
			add2_significand2 				<= aligned2_nxt;
		end
	end
endmodule
