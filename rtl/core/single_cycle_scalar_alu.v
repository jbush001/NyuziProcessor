//
// Copyright 2011-2012 Jeff Bush
// 
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
// 
//	   http://www.apache.org/licenses/LICENSE-2.0
// 
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
// 

//
// Handles arithmetic operations that take one cycle to complete.
// The output is not registered.
//

`include "instruction_format.h"

module single_cycle_scalar_alu(
	input [5:0]					operation_i,
	input [31:0]				operand1,
	input [31:0]				operand2,
	output reg[31:0]			single_cycle_result);
	
	wire[4:0]					leading_zeroes;
	wire[4:0]					trailing_zeroes;
	wire						carry;
	wire						_ignore;
	wire[31:0]					sum_difference;

	wire do_subtract = operation_i != `OP_IADD;

	// Add/subtract, with XORs in front of a carry chain.
	assign { carry, sum_difference, _ignore } = { 1'b0, operand1, do_subtract } 
		+ { do_subtract, {32{do_subtract}} ^ operand2, do_subtract };

	// These flags are only valid if do_subtract is true.  Otherwise ignored.
	wire negative = sum_difference[31]; 
	wire overflow =	 operand2[31] == negative && operand1[31] != operand2[31];
	wire zero = sum_difference == 0;
	wire signed_gtr = overflow == negative;

	// Count trailing zeroes
	assign trailing_zeroes[4] = (operand2[15:0] == 16'b0);
	wire[15:0] tz_val16 = trailing_zeroes[4] ? operand2[31:16] : operand2[15:0];
	assign trailing_zeroes[3] = (tz_val16[7:0] == 8'b0);
	wire[7:0] tz_val8 = trailing_zeroes[3] ? tz_val16[15:8] : tz_val16[7:0];
	assign trailing_zeroes[2] = (tz_val8[3:0] == 4'b0);
	wire[3:0] tz_val4 = trailing_zeroes[2] ? tz_val8[7:4] : tz_val8[3:0];
	assign trailing_zeroes[1] = (tz_val4[1:0] == 2'b0);
	assign trailing_zeroes[0] = trailing_zeroes[1] ? ~tz_val4[2] : ~tz_val4[0];

	// Count leading zeroes
	assign leading_zeroes[4] = (operand2[31:16] == 16'b0);
	wire[15:0] lz_val16 = leading_zeroes[4] ? operand2[15:0] : operand2[31:16];
	assign leading_zeroes[3] = (lz_val16[15:8] == 8'b0);
	wire[7:0] lz_val8 = leading_zeroes[3] ? lz_val16[7:0] : lz_val16[15:8];
	assign leading_zeroes[2] = (lz_val8[7:4] == 4'b0);
	wire[3:0] lz_val4 = leading_zeroes[2] ? lz_val8[3:0] : lz_val8[7:4];
	assign leading_zeroes[1] = (lz_val4[3:2] == 2'b0);
	assign leading_zeroes[0] = leading_zeroes[1] ? ~lz_val4[1] : ~lz_val4[3];

	wire fp_sign = operand2[31];
	wire[7:0] fp_exponent = operand2[30:23];
	wire[23:0] fp_significand = { 1'b1, operand2[22:0] };

	wire[4:0] shift_amount = operation_i == `OP_FTOI 
		? 23 - (fp_exponent - 127)
		: operand2[4:0];
	wire[31:0] shift_in = operation_i == `OP_FTOI ? fp_significand : operand1;
	wire shift_in_sign = operation_i == `OP_ASR ? operand1[31] : 1'd0;
	wire[31:0] rshift = { {32{shift_in_sign}}, shift_in } >> shift_amount;

	wire[31:0] reciprocal;

	fp_reciprocal_estimate fp_reciprocal_estimate(
		.value_i(operand2),
		.value_o(reciprocal));

	always @*
	begin
		case (operation_i)
			`OP_OR: single_cycle_result = operand1 | operand2;
			`OP_AND: single_cycle_result = operand1 & operand2;
			`OP_UMINUS: single_cycle_result = -operand2;		
			`OP_XOR: single_cycle_result = operand1 ^ operand2;	  
			`OP_NOT: single_cycle_result = ~operand2;
			`OP_IADD,	
			`OP_ISUB: single_cycle_result = sum_difference;	 
			`OP_ASR,
			`OP_LSR: single_cycle_result = operand2[31:5] == 0 ? rshift : {32{shift_in_sign}};	   
			`OP_LSL: single_cycle_result = operand2[31:5] == 0 ? operand1 << operand2[4:0] : 0;
			`OP_CLZ: single_cycle_result = operand2 == 0 ? 32 : leading_zeroes;	  
			`OP_CTZ: single_cycle_result = operand2 == 0 ? 32 : trailing_zeroes;
			`OP_COPY: single_cycle_result = operand2;   
			`OP_EQUAL: single_cycle_result = { {31{1'b0}}, zero };	  
			`OP_NEQUAL: single_cycle_result = { {31{1'b0}}, ~zero }; 
			`OP_SIGTR: single_cycle_result = { {31{1'b0}}, signed_gtr & ~zero };
			`OP_SIGTE: single_cycle_result = { {31{1'b0}}, signed_gtr | zero }; 
			`OP_SILT: single_cycle_result = { {31{1'b0}}, ~signed_gtr & ~zero}; 
			`OP_SILTE: single_cycle_result = { {31{1'b0}}, ~signed_gtr | zero };
			`OP_UIGTR: single_cycle_result = { {31{1'b0}}, ~carry & ~zero };
			`OP_UIGTE: single_cycle_result = { {31{1'b0}}, ~carry | zero };
			`OP_UILT: single_cycle_result = { {31{1'b0}}, carry & ~zero };
			`OP_UILTE: single_cycle_result = { {31{1'b0}}, carry | zero };
			`OP_RECIP: single_cycle_result = reciprocal;
			`OP_FTOI:
			begin
				if (!fp_exponent[7])	// Exponent negative (value smaller than zero)
					single_cycle_result = 0;
				else if (fp_sign)
					single_cycle_result = ~rshift + 1;
				else
					single_cycle_result = rshift;
			end
			default: single_cycle_result = 0; // Will happen. We technically don't care, but make consistent for simulation.
		endcase
	end
endmodule
