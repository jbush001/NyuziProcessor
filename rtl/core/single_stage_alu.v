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

`include "defines.v"

module single_stage_alu(
	input [5:0]          ds_alu_op,
	input [31:0]         operand1,
	input [31:0]         operand2,
	output logic[31:0]     single_stage_result);
	
	wire[4:0] leading_zeroes;
	wire[4:0] trailing_zeroes;
	wire carry;
	wire _ignore;
	wire[31:0] sum_difference;

	wire do_subtract = ds_alu_op != `OP_IADD;

	// Add/subtract
	assign { carry, sum_difference, _ignore } = { 1'b0, operand1, do_subtract } 
		+ { do_subtract, {32{do_subtract}} ^ operand2, do_subtract };

	// These flags are only valid if do_subtract is true.  Otherwise ignored.
	wire negative = sum_difference[31]; 
	wire overflow =	operand2[31] == negative && operand1[31] != operand2[31];
	wire zero = sum_difference == 0;
	wire signed_gtr = overflow == negative;

	// Count trailing zeroes using binary search
	wire tz4 = (operand2[15:0] == 16'b0);
	wire[15:0] tz_val16 = tz4 ? operand2[31:16] : operand2[15:0];
	wire tz3 = (tz_val16[7:0] == 8'b0);
	wire[7:0] tz_val8 = tz3 ? tz_val16[15:8] : tz_val16[7:0];
	wire tz2 = (tz_val8[3:0] == 4'b0);
	wire[3:0] tz_val4 = tz2 ? tz_val8[7:4] : tz_val8[3:0];
	wire tz1 = (tz_val4[1:0] == 2'b0);
	wire tz0 = tz1 ? ~tz_val4[2] : ~tz_val4[0];
	assign trailing_zeroes = { tz4, tz3, tz2, tz1, tz0 };

	// Count leading zeroes, as above except reversed
	wire lz4 = (operand2[31:16] == 16'b0);
	wire[15:0] lz_val16 = lz4 ? operand2[15:0] : operand2[31:16];
	wire lz3 = (lz_val16[15:8] == 8'b0);
	wire[7:0] lz_val8 = lz3 ? lz_val16[7:0] : lz_val16[15:8];
	wire lz2 = (lz_val8[7:4] == 4'b0);
	wire[3:0] lz_val4 = lz2 ? lz_val8[3:0] : lz_val8[7:4];
	wire lz1 = (lz_val4[3:2] == 2'b0);
	wire lz0 = lz1 ? ~lz_val4[1] : ~lz_val4[3];
	assign leading_zeroes = { lz4, lz3, lz2, lz1, lz0 };

	// Use a single shifter (with some muxes in front) to handle FTOI and integer 
	// arithmetic shifts.
	wire fp_sign = operand2[31];
	wire[7:0] fp_exponent = operand2[30:23];
	wire[23:0] fp_significand = { 1'b1, operand2[22:0] };
	wire[4:0] shift_amount = ds_alu_op == `OP_FTOI 
		? 23 - (fp_exponent - 127)
		: operand2[4:0];
	wire[31:0] shift_in = ds_alu_op == `OP_FTOI ? fp_significand : operand1;
	wire shift_in_sign = ds_alu_op == `OP_ASR ? operand1[31] : 1'd0;
	wire[31:0] rshift = { {32{shift_in_sign}}, shift_in } >> shift_amount;

	// Reciprocal estimate
	wire[31:0] reciprocal;
	fp_reciprocal_estimate fp_reciprocal_estimate(
		.value_i(operand2),
		.value_o(reciprocal));

	// Output mux
	always_comb
	begin
		unique case (ds_alu_op)
			`OP_OR: single_stage_result = operand1 | operand2;
			`OP_AND: single_stage_result = operand1 & operand2;
			`OP_UMINUS: single_stage_result = -operand2;		
			`OP_XOR: single_stage_result = operand1 ^ operand2;	  
			`OP_IADD,	
			`OP_ISUB: single_stage_result = sum_difference;	 
			`OP_ASR,
			`OP_LSR: single_stage_result = operand2[31:5] == 0 ? rshift : {32{shift_in_sign}};	   
			`OP_LSL: single_stage_result = operand2[31:5] == 0 ? operand1 << operand2[4:0] : 0;
			`OP_CLZ: single_stage_result = operand2 == 0 ? 32 : leading_zeroes;	  
			`OP_CTZ: single_stage_result = operand2 == 0 ? 32 : trailing_zeroes;
			`OP_COPY: single_stage_result = operand2;   
			`OP_EQUAL: single_stage_result = { {31{1'b0}}, zero };	  
			`OP_NEQUAL: single_stage_result = { {31{1'b0}}, ~zero }; 
			`OP_SIGTR: single_stage_result = { {31{1'b0}}, signed_gtr & ~zero };
			`OP_SIGTE: single_stage_result = { {31{1'b0}}, signed_gtr | zero }; 
			`OP_SILT: single_stage_result = { {31{1'b0}}, ~signed_gtr & ~zero}; 
			`OP_SILTE: single_stage_result = { {31{1'b0}}, ~signed_gtr | zero };
			`OP_UIGTR: single_stage_result = { {31{1'b0}}, ~carry & ~zero };
			`OP_UIGTE: single_stage_result = { {31{1'b0}}, ~carry | zero };
			`OP_UILT: single_stage_result = { {31{1'b0}}, carry & ~zero };
			`OP_UILTE: single_stage_result = { {31{1'b0}}, carry | zero };
			`OP_RECIP: single_stage_result = reciprocal;
			`OP_SEXT8: single_stage_result = { {24{operand2[7]}}, operand2[7:0] };
			`OP_SEXT16: single_stage_result = { {16{operand2[15]}}, operand2[15:0] };
			`OP_FTOI:
			begin
				if (!fp_exponent[7])	// Exponent negative (value smaller than zero)
					single_stage_result = 0;
				else if (fp_sign)
					single_stage_result = ~rshift + 1;
				else
					single_stage_result = rshift;
			end
			default: single_stage_result = 0; // Will happen. We technically don't care, but make consistent for simulation.
		endcase
	end
endmodule
