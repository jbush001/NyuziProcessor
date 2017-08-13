//
// Copyright 2011-2015 Jeff Bush
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

`include "defines.sv"

import defines::*;

//
// Floating Point Execute Stage 1
//
// Floating Point Addition
// - Determine which operand has the larger absolute value
// - Swap if necessary so the larger operand is in the larger-exponent lane
//   (_le)
// - Compute alignment shift count
// Float to int conversion
// - Steer significand down smaller-exponent lane
// Floating point multiplication
// - Add exponents/multiply significands
// The floating point pipeline also handles integer multiplication. This
// stages passes through the integer value to the multiplier in the next
// stage.
//

module fp_execute_stage1(
    input                                          clk,
    input                                          reset,

    // From writeback_stage
    input logic                                    wb_rollback_en,
    input local_thread_idx_t                       wb_rollback_thread_idx,

    // From operand_fetch_stage
    input vector_t                                 of_operand1,
    input vector_t                                 of_operand2,
    input vector_lane_mask_t                       of_mask_value,
    input                                          of_instruction_valid,
    input decoded_instruction_t                    of_instruction,
    input local_thread_idx_t                       of_thread_idx,
    input subcycle_t                               of_subcycle,

    // To fp_execute_stage2
    output logic                                   fx1_instruction_valid,
    output decoded_instruction_t                   fx1_instruction,
    output vector_lane_mask_t                      fx1_mask_value,
    output local_thread_idx_t                      fx1_thread_idx,
    output subcycle_t                              fx1_subcycle,
    output logic[NUM_VECTOR_LANES - 1:0]          fx1_result_is_inf,
    output logic[NUM_VECTOR_LANES - 1:0]          fx1_result_is_nan,
    output logic[NUM_VECTOR_LANES - 1:0][5:0]     fx1_ftoi_lshift,

    // Floating point addition/subtraction
    output scalar_t[NUM_VECTOR_LANES - 1:0]       fx1_significand_le,  // Larger exponent
    output scalar_t[NUM_VECTOR_LANES - 1:0]       fx1_significand_se,  // Smaller exponent
    output logic[NUM_VECTOR_LANES - 1:0][5:0]     fx1_se_align_shift,
    output logic[NUM_VECTOR_LANES - 1:0][7:0]     fx1_add_exponent,
    output logic[NUM_VECTOR_LANES - 1:0]          fx1_logical_subtract,
    output logic[NUM_VECTOR_LANES - 1:0]          fx1_add_result_sign,

    // Floating point multiplication
    output logic[NUM_VECTOR_LANES - 1:0][31:0]    fx1_multiplicand,
    output logic[NUM_VECTOR_LANES - 1:0][31:0]    fx1_multiplier,
    output logic[NUM_VECTOR_LANES - 1:0][7:0]     fx1_mul_exponent,
    output logic[NUM_VECTOR_LANES - 1:0]          fx1_mul_sign);

    logic is_fmul;
    logic is_imul;
    logic is_ftoi;
    logic is_itof;

    assign is_fmul = of_instruction.alu_op == OP_MUL_F;
    assign is_imul = of_instruction.alu_op == OP_MULL_I || of_instruction.alu_op == OP_MULH_U
        || of_instruction.alu_op == OP_MULH_I;
    assign is_ftoi = of_instruction.alu_op == OP_FTOI;
    assign is_itof = of_instruction.alu_op == OP_ITOF;

    genvar lane_idx;
    generate
        for (lane_idx = 0; lane_idx < NUM_VECTOR_LANES; lane_idx++)
        begin : lane_logic_gen
            float32_t fop1;
            float32_t fop2;
            logic[FLOAT32_SIG_WIDTH:0] full_significand1;    // Note extra bit
            logic[FLOAT32_SIG_WIDTH:0] full_significand2;
            logic op1_hidden_bit;
            logic op2_hidden_bit;
            logic op1_is_larger;
            logic[FLOAT32_EXP_WIDTH - 1:0] exp_difference;
            logic is_subtract;
            logic[FLOAT32_EXP_WIDTH - 1:0] mul_exponent;
            logic fop1_is_inf;
            logic fop1_is_nan;
            logic fop2_is_inf;
            logic fop2_is_nan;
            logic logical_subtract;
            logic result_is_nan;
            logic mul_exponent_underflow;
            logic mul_exponent_carry;
            logic[5:0] ftoi_rshift;
            logic[5:0] ftoi_lshift_nxt;

            assign fop1 = of_operand1[lane_idx];
            assign fop2 = of_operand2[lane_idx];
            assign op1_hidden_bit = fop1.exponent != 0;    // Check for subnormal numbers
            assign op2_hidden_bit = fop2.exponent != 0;
            assign full_significand1 = {op1_hidden_bit, fop1.significand};
            assign full_significand2 = {op2_hidden_bit, fop2.significand};
            assign is_subtract = of_instruction.alu_op != OP_ADD_F;    // This also include compares
            assign fop1_is_inf = fop1.exponent == 8'hff && fop1.significand == 0;
            assign fop1_is_nan = fop1.exponent == 8'hff && fop1.significand != 0;
            assign fop2_is_inf = fop2.exponent == 8'hff && fop2.significand == 0;
            assign fop2_is_nan = fop2.exponent == 8'hff && fop2.significand != 0;

            // Compute how much to shift the significand right to truncate
            // fractional digits
            always_comb
            begin
                if (fop2.exponent < 8'd118)
                begin
                    ftoi_rshift = 6'd32;    // Number is less than one, set to 0
                    ftoi_lshift_nxt = 0;
                end
                else if (fop2.exponent < 8'd150)
                begin
                    ftoi_rshift = 6'(8'd150 - fop2.exponent);  // Truncate significand
                    ftoi_lshift_nxt = 0;
                end
                else
                begin
                    ftoi_rshift = 6'd0;    // No fractional bits that fit in precision
                    ftoi_lshift_nxt = 6'(fop2.exponent - 8'd150);
                end
            end

            always_comb
            begin
                if (is_itof)
                    logical_subtract = of_operand2[lane_idx][31]; // Check high bit to see if this is negative
                else if (is_ftoi)
                    logical_subtract = fop2.sign; // If negative, inverter in stg 3 will convert to 2s complement
                else
                    logical_subtract = fop1.sign ^ fop2.sign ^ is_subtract;
            end

            always_comb
            begin
                if (is_itof)
                    result_is_nan = 0;
                else if (is_fmul)
                    result_is_nan = fop1_is_nan || fop2_is_nan || (fop1_is_inf && of_operand2[lane_idx] == 0)
                        || (fop2_is_inf && of_operand1[lane_idx] == 0);
                else if (is_ftoi)
                    result_is_nan = fop2_is_nan || fop2_is_inf || fop2.exponent >= 8'd159;
                else
                    result_is_nan = fop1_is_nan || fop2_is_nan || (fop1_is_inf && fop2_is_inf && logical_subtract);
            end

            // The result exponent for multiplication is the sum of the exponents. Convert these
            // from biased to unbiased representation by inverting the MSB, then add.
            // XXX handle underflow
            assign {mul_exponent_underflow, mul_exponent_carry, mul_exponent}
                =  {2'd0, fop1.exponent} + {2'd0, fop2.exponent} - 10'd127;

            // Subtle: In the case where values are equal, leave operand1 in the _le slot. This properly
            // handles the sign for +/- zero.
            assign op1_is_larger = fop1.exponent > fop2.exponent
                    || (fop1.exponent == fop2.exponent && full_significand1 >= full_significand2);
            assign exp_difference = op1_is_larger ? fop1.exponent - fop2.exponent
                : fop2.exponent - fop1.exponent;

            always_ff @(posedge clk)
            begin
                fx1_result_is_nan[lane_idx] <= result_is_nan;
                fx1_result_is_inf[lane_idx] <= !is_itof && !result_is_nan && (fop1_is_inf || fop2_is_inf
                    || (is_fmul && mul_exponent_carry && !mul_exponent_underflow));

                // Floating point addition pipeline.
                // - If this is a float<->int conversion, the value goes down the small exponent path.
                //   The large exponent is set to zero.
                // - For addition/subtraction, sort into significand_le (the larger value) and
                //   sigificand_se (the smaller).
                if (op1_is_larger || is_ftoi || is_itof)
                begin
                    if (is_ftoi || is_itof)
                        fx1_significand_le[lane_idx] <= 0;
                    else
                        fx1_significand_le[lane_idx] <= scalar_t'(full_significand1);

                    if (is_itof)
                    begin
                        // Convert int to float
                        fx1_significand_se[lane_idx] <= of_operand2[lane_idx];
                        fx1_add_exponent[lane_idx] <= 8'd127 + 8'd23;
                        fx1_add_result_sign[lane_idx] <= of_operand2[lane_idx][31];
                    end
                    else
                    begin
                        // Add/Subtract/Compare, first operand has larger value
                        fx1_significand_se[lane_idx] <= scalar_t'(full_significand2);
                        fx1_add_exponent[lane_idx] <= fop1.exponent;
                        fx1_add_result_sign[lane_idx] <= fop1.sign;    // Larger magnitude sign wins
                    end
                end
                else
                begin
                    // Add/Subtract/Comapare, second operand has larger value
                    fx1_significand_le[lane_idx] <= scalar_t'(full_significand2);
                    fx1_significand_se[lane_idx] <= scalar_t'(full_significand1);
                    fx1_add_exponent[lane_idx] <= fop2.exponent;
                    fx1_add_result_sign[lane_idx] <= fop2.sign ^ is_subtract;
                end

                fx1_logical_subtract[lane_idx] <= logical_subtract;
                if (is_itof)
                    fx1_se_align_shift[lane_idx] <= 0;
                else if (is_ftoi)
                begin
                    // Shift to truncate fractional bits
                    fx1_se_align_shift[lane_idx] <= ftoi_rshift[5:0];
                end
                else
                begin
                    // Compute how much to shift significand to make exponents be equal.
                    // Shift up to 27 bits, even though the significand is only 24 bits.
                    // This allows shifting out the guard and round bits.
                    fx1_se_align_shift[lane_idx] <= exp_difference < 8'd27 ? 6'(exp_difference) : 6'd27;
                end

                fx1_ftoi_lshift[lane_idx] <= ftoi_lshift_nxt;

                // Multiplication pipeline.
                // XXX this is a pass through now. For a more optimal implementation, this could do
                // booth encoding.
                if (is_imul)
                begin
                    // Unsigned multiply
                    fx1_multiplicand[lane_idx] <= of_operand1[lane_idx];
                    fx1_multiplier[lane_idx] <= of_operand2[lane_idx];
                end
                else
                begin
                    fx1_multiplicand[lane_idx] <= scalar_t'(full_significand1);
                    fx1_multiplier[lane_idx] <= scalar_t'(full_significand2);
                end

                fx1_mul_exponent[lane_idx] <= mul_exponent;
                fx1_mul_sign[lane_idx] <= fop1.sign ^ fop2.sign;
            end
        end
    endgenerate

    always_ff @(posedge clk)
    begin
        fx1_instruction <= of_instruction;
        fx1_mask_value <= of_mask_value;
        fx1_thread_idx <= of_thread_idx;
        fx1_subcycle <= of_subcycle;
    end

    always_ff @(posedge clk, posedge reset)
    begin
        if (reset)
            fx1_instruction_valid <= '0;
        else
        begin
            fx1_instruction_valid <= of_instruction_valid
                && (!wb_rollback_en || wb_rollback_thread_idx != of_thread_idx)
                && of_instruction.pipeline_sel == PIPE_FLOAT_ARITH;
        end
    end
endmodule
