// 
// Copyright (C) 2011-2014 Jeff Bush
// 
// This library is free software; you can redistribute it and/or
// modify it under the terms of the GNU Library General Public
// License as published by the Free Software Foundation; either
// version 2 of the License, or (at your option) any later version.
// 
// This library is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
// Library General Public License for more details.
// 
// You should have received a copy of the GNU Library General Public
// License along with this library; if not, write to the
// Free Software Foundation, Inc., 51 Franklin St, Fifth Floor,
// Boston, MA  02110-1301, USA.
// 


`include "defines.v"

//
// First stage of floating point multiplier pipeline
// - Compute result exponent
// - Insert hidden bits
//

module fp_multiplier_stage1
	#(parameter SIGNIFICAND_PRODUCT_WIDTH = (`FP_SIGNIFICAND_WIDTH + 1) * 2)

	(input               clk,
	input                reset,
	input arith_opcode_t ds_alu_op,
	input [31:0]         operand1,
	input [31:0]         operand2,
	output logic[31:0]   mul1_muliplicand,
	output logic[31:0]   mul1_multiplier,
	output logic[7:0]    mul1_exponent,
	output logic         mul1_sign,
	output logic         mul_overflow_stage2,
	output logic         mul_underflow_stage2);

	logic sign1;
	logic[7:0] exponent1;
	logic sign2;
	logic[7:0] exponent2;

	// Multiplicand
	always_comb
	begin
		if (ds_alu_op == OP_ITOF)
		begin
			// Dummy multiply by 1.0
			sign1 = 0;
			exponent1 = 127;
			mul1_muliplicand = { 32'h00800000 };
		end
		else
		begin
			sign1 = operand1[31];
			exponent1 = operand1[30:23];
			mul1_muliplicand = { 8'd0, exponent1 != 0, operand1[22:0] };
		end
	end
	
	always_comb
	begin
		if (ds_alu_op == OP_ITOF)
		begin
			// Convert to unnormalized float for multiplication
			sign2 = operand2[31];
			exponent2 = 127 + 23;
			if (sign2)
				mul1_multiplier = (operand2 ^ {32{1'b1}}) + 1;
			else
				mul1_multiplier = operand2;
		end
		else
		begin
			sign2 = operand2[31];
			exponent2 = operand2[30:23];
			mul1_multiplier = { 8'd0, exponent2 != 0, operand2[22:0] };
		end
	end

	logic[7:0] result_exponent;
	logic underflow;
	logic carry;

	assign { underflow, carry, result_exponent } = { 2'd0, exponent1 } + 
		{ 2'd0, exponent2 } - 10'd127;

	always_ff @(posedge clk, posedge reset)
	begin
		if (reset)
		begin
			/*AUTORESET*/
			// Beginning of autoreset for uninitialized flops
			mul1_exponent <= 8'h0;
			mul1_sign <= 1'h0;
			mul_overflow_stage2 <= 1'h0;
			mul_underflow_stage2 <= 1'h0;
			// End of automatics
		end
		else
		begin
			mul1_exponent <= result_exponent;
			mul1_sign <= sign1 ^ sign2;
			mul_overflow_stage2 <= carry && !underflow;
			mul_underflow_stage2 <= underflow;
		end
	end
endmodule

// Local Variables:
// verilog-typedef-regexp:"_t$"
// End:

