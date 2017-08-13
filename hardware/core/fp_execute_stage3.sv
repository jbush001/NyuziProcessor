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
// Floating Point Execute Stage 3
//
// Floating Point Addition
// - Add/subtract significands
// - Rounding for subtraction
// Int-to-float/float-to-int
// - Convert negative values to 2's complement.
// Floating point multiplication
// - pass through
//

module fp_execute_stage3(
    input                                       clk,
    input                                       reset,

    // From fp_execute_stage2
    input vector_lane_mask_t                    fx2_mask_value,
    input                                       fx2_instruction_valid,
    input decoded_instruction_t                 fx2_instruction,
    input local_thread_idx_t                    fx2_thread_idx,
    input subcycle_t                            fx2_subcycle,
    input [NUM_VECTOR_LANES - 1:0]             fx2_result_is_inf,
    input [NUM_VECTOR_LANES - 1:0]             fx2_result_is_nan,
    input [NUM_VECTOR_LANES - 1:0][5:0]        fx2_ftoi_lshift,

    // Floating point addition/subtraction
    input scalar_t[NUM_VECTOR_LANES - 1:0]     fx2_significand_le,
    input scalar_t[NUM_VECTOR_LANES - 1:0]     fx2_significand_se,
    input[NUM_VECTOR_LANES - 1:0]              fx2_logical_subtract,
    input[NUM_VECTOR_LANES - 1:0][7:0]         fx2_add_exponent,
    input[NUM_VECTOR_LANES - 1:0]              fx2_add_result_sign,
    input[NUM_VECTOR_LANES - 1:0]              fx2_guard,
    input[NUM_VECTOR_LANES - 1:0]              fx2_round,
    input[NUM_VECTOR_LANES - 1:0]              fx2_sticky,

    // Floating point multiplication
    input [NUM_VECTOR_LANES - 1:0][63:0]       fx2_significand_product,
    input [NUM_VECTOR_LANES - 1:0][7:0]        fx2_mul_exponent,
    input [NUM_VECTOR_LANES - 1:0]             fx2_mul_sign,

    // To fp_execute_stage4
    output logic                                fx3_instruction_valid,
    output decoded_instruction_t                fx3_instruction,
    output vector_lane_mask_t                   fx3_mask_value,
    output local_thread_idx_t                   fx3_thread_idx,
    output subcycle_t                           fx3_subcycle,
    output logic[NUM_VECTOR_LANES - 1:0]       fx3_result_is_inf,
    output logic[NUM_VECTOR_LANES - 1:0]       fx3_result_is_nan,
    output logic[NUM_VECTOR_LANES - 1:0][5:0]  fx3_ftoi_lshift,

    // Floating point addition/subtraction
    output scalar_t[NUM_VECTOR_LANES - 1:0]    fx3_add_significand,
    output logic[NUM_VECTOR_LANES - 1:0][7:0]  fx3_add_exponent,
    output logic[NUM_VECTOR_LANES - 1:0]       fx3_add_result_sign,
    output logic[NUM_VECTOR_LANES - 1:0]       fx3_logical_subtract,

    // Floating point multiplication
    output logic[NUM_VECTOR_LANES - 1:0][63:0] fx3_significand_product,
    output logic[NUM_VECTOR_LANES - 1:0][7:0]  fx3_mul_exponent,
    output logic[NUM_VECTOR_LANES - 1:0]       fx3_mul_sign);

    logic is_ftoi;

    assign is_ftoi = fx2_instruction.alu_op == OP_FTOI;

    genvar lane_idx;
    generate
        for (lane_idx = 0; lane_idx < NUM_VECTOR_LANES; lane_idx++)
        begin : lane_logic_gen
            logic carry_in;
            scalar_t unnormalized_sum;
            logic sum_is_odd;
            logic round_up;
            logic round_tie;
            logic do_round;
            logic _unused;

            // Round-to-nearest, round half to even. Compute the value of the low bit
            // of the sum to predict if the result is odd.
            assign sum_is_odd = fx2_significand_le[lane_idx][0] ^ fx2_significand_se[lane_idx][0];
            assign round_tie = (fx2_guard[lane_idx] && !(fx2_round[lane_idx] || fx2_sticky[lane_idx]));
            assign round_up = (fx2_guard[lane_idx] && (fx2_round[lane_idx] || fx2_sticky[lane_idx]));
            assign do_round = (round_up || (sum_is_odd && round_tie));

            // For logical subtraction, rounding reduces the unnormalized sum because
            // it rounds the subtrahend up. Since this inverts the second parameter
            // to perform a subtraction, a +1 is normally necessary. Round down by
            // not doing that. For logical addition, rounding increases the unnormalized
            // sum. Do these by setting carry_in appropriately.
            //
            // For float<->int conversions, overload this to handle changing between signed-magnitude
            // and two's complement format. LE is set to zero and fx2_logical_subtract indicates
            // if it needs a conversion.
            assign carry_in = fx2_logical_subtract[lane_idx] ^ (do_round && !is_ftoi);
            assign {unnormalized_sum, _unused} = {fx2_significand_le[lane_idx], 1'b1}
                + {(fx2_significand_se[lane_idx] ^ {32{fx2_logical_subtract[lane_idx]}}), carry_in};

            always_ff @(posedge clk)
            begin
                fx3_result_is_inf[lane_idx] <= fx2_result_is_inf[lane_idx];
                fx3_result_is_nan[lane_idx] <= fx2_result_is_nan[lane_idx];
                fx3_ftoi_lshift[lane_idx] <= fx2_ftoi_lshift[lane_idx];

                // Addition
                fx3_add_significand[lane_idx] <= unnormalized_sum;
                fx3_add_exponent[lane_idx] <= fx2_add_exponent[lane_idx];
                fx3_logical_subtract[lane_idx] <= fx2_logical_subtract[lane_idx];
                fx3_add_result_sign[lane_idx] <= fx2_add_result_sign[lane_idx];

                // Multiplication
                fx3_significand_product[lane_idx] <= fx2_significand_product[lane_idx];
                fx3_mul_exponent[lane_idx] <= fx2_mul_exponent[lane_idx];
                fx3_mul_sign[lane_idx] <= fx2_mul_sign[lane_idx];
            end
        end
    endgenerate

    always_ff @(posedge clk)
    begin
        fx3_instruction <= fx2_instruction;
        fx3_mask_value <= fx2_mask_value;
        fx3_thread_idx <= fx2_thread_idx;
        fx3_subcycle <= fx2_subcycle;
    end

    always_ff @(posedge clk, posedge reset)
    begin
        if (reset)
            fx3_instruction_valid <= '0;
        else
            fx3_instruction_valid <= fx2_instruction_valid;
    end
endmodule
