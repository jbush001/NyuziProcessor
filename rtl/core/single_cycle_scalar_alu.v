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
	input [31:0]				operand1_i,
	input [31:0]				operand2_i,
	output reg[31:0]			result_o = 0);
	
	wire[4:0]					leading_zeroes;
	wire[4:0]					trailing_zeroes;
	wire						carry;
	wire						_ignore;
	wire[31:0]					sum_difference;
	integer						i, j;

	wire is_sub = operation_i != `OP_IADD;

	// Add/subtract, with XORs in front of a carry chain.
	assign { carry, sum_difference, _ignore } = { 1'b0, operand1_i, is_sub } 
		+ { is_sub, {32{is_sub}} ^ operand2_i, is_sub };

	// These flags are only valid if this is is_sub is true.  Otherwise ignored.
	wire negative = sum_difference[31]; 
	wire overflow =	 operand2_i[31] == negative && operand1_i[31] != operand2_i[31];
	wire zero = sum_difference == 0;
	wire signed_gtr = overflow == negative;

	// Count trailing zeroes
	assign trailing_zeroes[4] = (operand2_i[15:0] == 16'b0);
	wire[15:0] tz_val16 = trailing_zeroes[4] ? operand2_i[31:16] : operand2_i[15:0];
	assign trailing_zeroes[3] = (tz_val16[7:0] == 8'b0);
	wire[7:0] tz_val8 = trailing_zeroes[3] ? tz_val16[15:8] : tz_val16[7:0];
	assign trailing_zeroes[2] = (tz_val8[3:0] == 4'b0);
	wire[3:0] tz_val4 = trailing_zeroes[2] ? tz_val8[7:4] : tz_val8[3:0];
	assign trailing_zeroes[1] = (tz_val4[1:0] == 2'b0);
	assign trailing_zeroes[0] = trailing_zeroes[1] ? ~tz_val4[2] : ~tz_val4[0];

	// Count leading zeroes
	assign leading_zeroes[4] = (operand2_i[31:16] == 16'b0);
	wire[15:0] lz_val16 = leading_zeroes[4] ? operand2_i[15:0] : operand2_i[31:16];
	assign leading_zeroes[3] = (lz_val16[15:8] == 8'b0);
	wire[7:0] lz_val8 = leading_zeroes[3] ? lz_val16[7:0] : lz_val16[15:8];
	assign leading_zeroes[2] = (lz_val8[7:4] == 4'b0);
	wire[3:0] lz_val4 = leading_zeroes[2] ? lz_val8[3:0] : lz_val8[7:4];
	assign leading_zeroes[1] = (lz_val4[3:2] == 2'b0);
	assign leading_zeroes[0] = leading_zeroes[1] ? ~lz_val4[1] : ~lz_val4[3];

	wire fp_sign = operand2_i[31];
	wire[7:0] fp_exponent = operand2_i[30:23];
	wire[23:0] fp_significand = { 1'b1, operand2_i[22:0] };

	wire[4:0] shift_amount = operation_i == `OP_FTOI 
		? 23 - (fp_exponent - 127)
		: operand2_i[4:0];
	wire[31:0] shift_in = operation_i == `OP_FTOI ? fp_significand : operand1_i;
	wire shift_in_sign = operation_i == `OP_ASR ? operand1_i[31] : 1'd0;
	wire[31:0] rshift = { {32{shift_in_sign}}, shift_in } >> shift_amount;

	always @*
	begin
		case (operation_i)
			`OP_OR: result_o = operand1_i | operand2_i;
			`OP_AND: result_o = operand1_i & operand2_i;
			`OP_UMINUS: result_o = -operand2_i;		
			`OP_XOR: result_o = operand1_i ^ operand2_i;	  
			`OP_NOT: result_o = ~operand2_i;
			`OP_IADD,	
			`OP_ISUB: result_o = sum_difference;	 
			`OP_ASR,
			`OP_LSR: result_o = operand2_i[31:5] == 0 ? rshift : {32{shift_in_sign}};	   
			`OP_LSL: result_o = operand2_i[31:5] == 0 ? operand1_i << operand2_i[4:0] : 0;
			`OP_CLZ: result_o = operand2_i == 0 ? 32 : leading_zeroes;	  
			`OP_CTZ: result_o = operand2_i == 0 ? 32 : trailing_zeroes;
			`OP_COPY: result_o = operand2_i;   
			`OP_EQUAL: result_o = { {31{1'b0}}, zero };	  
			`OP_NEQUAL: result_o = { {31{1'b0}}, ~zero }; 
			`OP_SIGTR: result_o = { {31{1'b0}}, signed_gtr & ~zero };
			`OP_SIGTE: result_o = { {31{1'b0}}, signed_gtr | zero }; 
			`OP_SILT: result_o = { {31{1'b0}}, ~signed_gtr & ~zero}; 
			`OP_SILTE: result_o = { {31{1'b0}}, ~signed_gtr | zero };
			`OP_UIGTR: result_o = { {31{1'b0}}, ~carry & ~zero };
			`OP_UIGTE: result_o = { {31{1'b0}}, ~carry | zero };
			`OP_UILT: result_o = { {31{1'b0}}, carry & ~zero };
			`OP_UILTE: result_o = { {31{1'b0}}, carry | zero };
			`OP_FTOI:
			begin
				if (operand2_i == 0)
					result_o = 0;
				else if (fp_exponent < 127)	// Exponent negative (value smaller than zero)
					result_o = 0;
				else if (fp_sign)
					result_o = ~rshift + 1;
				else
					result_o = rshift;
			end
			default:   result_o = 0;	// Will happen.	 We technically don't care, but make consistent for simulation.
		endcase
	end
endmodule
