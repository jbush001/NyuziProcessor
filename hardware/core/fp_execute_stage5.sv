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

`include "defines.svh"

import defines::*;

//
// Floating Point Execute Stage 5
//
// Floating point addition/multiplication
// - Normalization shift
// - Post normalization rounding (for addition overflow)
//

module fp_execute_stage5(
    input                                   clk,
    input                                   reset,

    // From fp_execute_stage4
    input vector_mask_t                     fx4_mask_value,
    input                                   fx4_instruction_valid,
    input decoded_instruction_t             fx4_instruction,
    input local_thread_idx_t                fx4_thread_idx,
    input subcycle_t                        fx4_subcycle,
    input [NUM_VECTOR_LANES - 1:0]          fx4_result_inf,
    input [NUM_VECTOR_LANES - 1:0]          fx4_result_nan,
    input [NUM_VECTOR_LANES - 1:0]          fx4_equal,

    // Floating point addition/subtraction
    input [NUM_VECTOR_LANES - 1:0][7:0]     fx4_add_exponent,
    input scalar_t[NUM_VECTOR_LANES - 1:0]  fx4_add_significand,
    input [NUM_VECTOR_LANES - 1:0]          fx4_add_result_sign,
    input [NUM_VECTOR_LANES - 1:0]          fx4_logical_subtract,
    input [NUM_VECTOR_LANES - 1:0][5:0]     fx4_norm_shift,

    // Floating point multiplication
    input [NUM_VECTOR_LANES - 1:0][63:0]    fx4_significand_product,
    input [NUM_VECTOR_LANES - 1:0][7:0]     fx4_mul_exponent,
    input [NUM_VECTOR_LANES - 1:0]          fx4_mul_underflow,
    input [NUM_VECTOR_LANES - 1:0]          fx4_mul_sign,

    // To writeback_stage
    output logic                            fx5_instruction_valid,
    output decoded_instruction_t            fx5_instruction,
    output vector_mask_t                    fx5_mask_value,
    output local_thread_idx_t               fx5_thread_idx,
    output subcycle_t                       fx5_subcycle,
    output vector_t                         fx5_result);

    logic fmul;
    logic imull;
    logic imulh;
    logic ftoi;

    assign fmul = fx4_instruction.alu_op == OP_MUL_F;
    assign imull = fx4_instruction.alu_op == OP_MULL_I;
    assign imulh = fx4_instruction.alu_op == OP_MULH_U || fx4_instruction.alu_op == OP_MULH_I;
    assign ftoi = fx4_instruction.alu_op == OP_FTOI;

    genvar lane_idx;
    generate
        for (lane_idx = 0; lane_idx < NUM_VECTOR_LANES; lane_idx++)
        begin : lane_logic_gen
            logic[22:0] add_result_significand;
            logic[7:0] add_result_exponent;
            logic[7:0] adjusted_add_exponent;
            scalar_t shifted_significand;
            logic add_subnormal;
            scalar_t add_result;
            logic add_round;
            logic add_overflow;
            logic mul_normalize_shift;
            logic[22:0] mul_normalized_significand;
            logic[22:0] mul_rounded_significand;
            scalar_t fmul_result;
            logic[7:0] mul_exponent;
            logic mul_guard;
            logic mul_round;
            logic[21:0] mul_sticky_bits;
            logic mul_sticky;
            logic mul_round_tie;
            logic mul_round_up;
            logic mul_do_round;
            logic compare_result;
            logic sum_zero;
            logic mul_hidden_bit;
            logic mul_round_overflow;

            assign adjusted_add_exponent = fx4_add_exponent[lane_idx]
                - FLOAT32_EXP_WIDTH'(fx4_norm_shift[lane_idx]) + FLOAT32_EXP_WIDTH'(8);
            assign add_subnormal = fx4_add_exponent[lane_idx] == 0 || fx4_add_significand[lane_idx] == 0;
            assign shifted_significand = fx4_add_significand[lane_idx] << fx4_norm_shift[lane_idx];

            // Because this can only shift one bit out, can only round to even here.
            // shifted_significand[7] is the guard bit. shifted_significand[8] indicates whether
            // the result is even or odd.
            assign add_round = shifted_significand[7] && shifted_significand[8] && !fx4_logical_subtract[lane_idx];
            assign add_result_significand = add_subnormal ? fx4_add_significand[lane_idx][22:0]
                : (shifted_significand[30:8] + FLOAT32_SIG_WIDTH'(add_round));    // Round up using truncated bit
            assign add_result_exponent = add_subnormal ? '0 : adjusted_add_exponent;
            assign add_overflow = add_result_exponent == 8'hFF && !fx4_result_nan[lane_idx];

            always_comb
            begin
                if (fx4_result_inf[lane_idx] || add_overflow)
                    add_result = {fx4_add_result_sign[lane_idx], 8'hff, 23'd0};
                else if (fx4_result_nan[lane_idx])
                    add_result = {32'h7fffffff};
                else if (add_result_significand == 0 && add_subnormal)
                begin
                    // IEEE754-2008, 6.3: "When the sum of two operands with opposite signs
                    // (or the difference of two operands with like signs) is exactly zero,
                    // the sign of that sum (or difference) shall be +0.
                    // XXX this will pick up some additional cases like -0.0 + 0.0."
                    add_result = 0;
                end
                else
                    add_result = {fx4_add_result_sign[lane_idx], add_result_exponent, add_result_significand};
            end

            assign sum_zero = add_subnormal && add_result_significand == 0;

            // If the operation is unordered (either operand is NaN), treat the result as false
            always_comb
            begin
                unique case (fx4_instruction.alu_op)
                    OP_CMPGT_F: compare_result = !fx4_add_result_sign[lane_idx] && !fx4_equal[lane_idx] && !fx4_result_nan[lane_idx];
                    OP_CMPGE_F: compare_result = (!fx4_add_result_sign[lane_idx] || fx4_equal[lane_idx]) && !fx4_result_nan[lane_idx];
                    OP_CMPLT_F: compare_result = fx4_add_result_sign[lane_idx] && !fx4_equal[lane_idx] && !fx4_result_nan[lane_idx];
                    OP_CMPLE_F: compare_result = (fx4_add_result_sign[lane_idx] || fx4_equal[lane_idx]) && !fx4_result_nan[lane_idx];
                    OP_CMPEQ_F: compare_result = fx4_equal[lane_idx] && !fx4_result_nan[lane_idx];
                    OP_CMPNE_F: compare_result = !fx4_equal[lane_idx] || fx4_result_nan[lane_idx];
                    default: compare_result = 0;
                endcase
            end

            // If the operands for multiplication are both normalized (start with a leading 1), then the
            // the maximum normalization shift is one place.
            // XXX does not handle subnormal product
            assign mul_normalize_shift = !fx4_significand_product[lane_idx][47];
            assign {mul_normalized_significand, mul_guard, mul_round, mul_sticky_bits} = mul_normalize_shift
                ? {fx4_significand_product[lane_idx][45:0], 1'b0}
                : fx4_significand_product[lane_idx][46:0];
            assign mul_sticky = |mul_sticky_bits;
            assign mul_round_tie = mul_guard && !(mul_round || mul_sticky);
            assign mul_round_up = mul_guard && (mul_round || mul_sticky);
            assign mul_do_round = mul_round_up || (mul_round_tie && mul_normalized_significand[0]);
            assign mul_rounded_significand = mul_normalized_significand + FLOAT32_SIG_WIDTH'(mul_do_round);
            assign mul_hidden_bit = mul_normalize_shift ? fx4_significand_product[lane_idx][46] : 1'b1;
            assign mul_round_overflow = mul_do_round && mul_rounded_significand == 0;
            always_comb
            begin
                if (!mul_hidden_bit)
                    mul_exponent = 0;    // Is subnormal
                else if (mul_normalize_shift && !mul_round_overflow)
                    mul_exponent = fx4_mul_exponent[lane_idx];
                else
                    mul_exponent = fx4_mul_exponent[lane_idx] + FLOAT32_EXP_WIDTH'(1);
            end

            always_comb
            begin
                if (fx4_result_inf[lane_idx])
                    fmul_result = {fx4_mul_sign[lane_idx], 8'hff, 23'd0};
                else if (fx4_result_nan[lane_idx])
                    fmul_result = {32'h7fffffff};
                else
                    fmul_result = {fx4_mul_sign[lane_idx], mul_exponent, mul_rounded_significand};
            end

            always_ff @(posedge clk)
            begin
                if (ftoi)
                begin
                    if (fx4_result_nan[lane_idx])
                        fx5_result[lane_idx] <= 32'h80000000;    // nan signal indicates an invalid conversion
                    else
                        fx5_result[lane_idx] <= shifted_significand;
                end
                else if (fx4_instruction.compare)
                    fx5_result[lane_idx] <= scalar_t'(compare_result);
                else if (imull)
                    fx5_result[lane_idx] <= fx4_significand_product[lane_idx][31:0];
                else if (imulh)
                    fx5_result[lane_idx] <= fx4_significand_product[lane_idx][63:32];
                else if (fmul)
                    fx5_result[lane_idx] <= fx4_mul_underflow[lane_idx] ? 32'h00000000 : fmul_result;
                else
                    fx5_result[lane_idx] <= add_result;
            end
        end
    endgenerate

    always_ff @(posedge clk)
    begin
        fx5_instruction <= fx4_instruction;
        fx5_mask_value <= fx4_mask_value;
        fx5_thread_idx <= fx4_thread_idx;
        fx5_subcycle <= fx4_subcycle;
    end

    always_ff @(posedge clk, posedge reset)
    begin
        if (reset)
            fx5_instruction_valid <= '0;
        else
            fx5_instruction_valid <= fx4_instruction_valid;
    end
endmodule
