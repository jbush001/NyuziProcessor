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
// Floating Point Execute Stage 2
//
// Floating Point Addition
// - Shift smaller operand to align with larger
// Floating Point multiplication
// - Perform actual operation (XXX placeholder, see below)
// Float to int conversion
// - Shift significand right to truncate fractional bit positions
//

module fp_execute_stage2(
    input                                       clk,
    input                                       reset,

    // From writeback_stage
    input logic                                 wb_rollback_en,
    input local_thread_idx_t                    wb_rollback_thread_idx,
    input pipeline_sel_t                        wb_rollback_pipeline,

    // From fp_execute_stage1
    input vector_lane_mask_t                    fx1_mask_value,
    input                                       fx1_instruction_valid,
    input decoded_instruction_t                 fx1_instruction,
    input local_thread_idx_t                    fx1_thread_idx,
    input subcycle_t                            fx1_subcycle,
    input [NUM_VECTOR_LANES - 1:0]             fx1_result_is_inf,
    input [NUM_VECTOR_LANES - 1:0]             fx1_result_is_nan,
    input [NUM_VECTOR_LANES - 1:0][5:0]        fx1_ftoi_lshift,

    // Floating point addition/subtraction
    input scalar_t[NUM_VECTOR_LANES - 1:0]     fx1_significand_le,
    input scalar_t[NUM_VECTOR_LANES - 1:0]     fx1_significand_se,
    input [NUM_VECTOR_LANES - 1:0]             fx1_logical_subtract,
    input [NUM_VECTOR_LANES - 1:0][5:0]        fx1_se_align_shift,
    input [NUM_VECTOR_LANES - 1:0][7:0]        fx1_add_exponent,
    input [NUM_VECTOR_LANES - 1:0]             fx1_add_result_sign,

    // Floating point multiplication
    input [NUM_VECTOR_LANES - 1:0][7:0]        fx1_mul_exponent,
    input [NUM_VECTOR_LANES - 1:0]             fx1_mul_sign,
    input [NUM_VECTOR_LANES - 1:0][31:0]       fx1_multiplicand,
    input [NUM_VECTOR_LANES - 1:0][31:0]       fx1_multiplier,

    // To fp_execute_stage3
    output logic                                fx2_instruction_valid,
    output decoded_instruction_t                fx2_instruction,
    output vector_lane_mask_t                   fx2_mask_value,
    output local_thread_idx_t                   fx2_thread_idx,
    output subcycle_t                           fx2_subcycle,
    output logic[NUM_VECTOR_LANES - 1:0]       fx2_result_is_inf,
    output logic[NUM_VECTOR_LANES - 1:0]       fx2_result_is_nan,
    output logic[NUM_VECTOR_LANES - 1:0][5:0]  fx2_ftoi_lshift,

    // Floating point addition/subtraction
    output logic[NUM_VECTOR_LANES - 1:0]       fx2_logical_subtract,
    output logic[NUM_VECTOR_LANES - 1:0]       fx2_add_result_sign,
    output scalar_t[NUM_VECTOR_LANES - 1:0]    fx2_significand_le,
    output scalar_t[NUM_VECTOR_LANES - 1:0]    fx2_significand_se,
    output logic[NUM_VECTOR_LANES - 1:0][7:0]  fx2_add_exponent,
    output logic[NUM_VECTOR_LANES - 1:0]       fx2_guard,
    output logic[NUM_VECTOR_LANES - 1:0]       fx2_round,
    output logic[NUM_VECTOR_LANES - 1:0]       fx2_sticky,

    // Floating point multiplication
    output logic[NUM_VECTOR_LANES - 1:0][63:0]  fx2_significand_product,
    output logic[NUM_VECTOR_LANES - 1:0][7:0]   fx2_mul_exponent,
    output logic[NUM_VECTOR_LANES - 1:0]        fx2_mul_sign);

    logic is_imulhs;

    assign is_imulhs = fx1_instruction.alu_op == OP_MULH_I;

    genvar lane_idx;
    generate
        for (lane_idx = 0; lane_idx < NUM_VECTOR_LANES; lane_idx++)
        begin : lane_logic_gen
            scalar_t aligned_significand;
            logic guard;
            logic round;
            logic[24:0] sticky_bits;
            logic sticky;
            logic[63:0] sext_multiplicand;
            logic[63:0] sext_multiplier;

            assign {aligned_significand, guard, round, sticky_bits} = {fx1_significand_se[lane_idx], 27'd0} >>
                fx1_se_align_shift[lane_idx];
            assign sticky = |sticky_bits;

            // Sign extend multiply operands
            assign sext_multiplicand = {{32{fx1_multiplicand[lane_idx][31] && is_imulhs}},
                fx1_multiplicand[lane_idx]};
            assign sext_multiplier = {{32{fx1_multiplier[lane_idx][31] && is_imulhs}},
                fx1_multiplier[lane_idx]};

            always_ff @(posedge clk)
            begin
                fx2_significand_le[lane_idx] <= fx1_significand_le[lane_idx];
                fx2_significand_se[lane_idx] <= aligned_significand;
                fx2_add_exponent[lane_idx] <= fx1_add_exponent[lane_idx];
                fx2_logical_subtract[lane_idx] <= fx1_logical_subtract[lane_idx];
                fx2_add_result_sign[lane_idx] <= fx1_add_result_sign[lane_idx];
                fx2_guard[lane_idx] <= guard;
                fx2_round[lane_idx] <= round;
                fx2_sticky[lane_idx] <= sticky;
                fx2_mul_exponent[lane_idx] <= fx1_mul_exponent[lane_idx];
                fx2_mul_sign[lane_idx] <= fx1_mul_sign[lane_idx];
                fx2_result_is_inf[lane_idx] <= fx1_result_is_inf[lane_idx];
                fx2_result_is_nan[lane_idx] <= fx1_result_is_nan[lane_idx];
                fx2_ftoi_lshift[lane_idx] <= fx1_ftoi_lshift[lane_idx];

                // XXX Simple version. Should have a wallace tree here to collect partial products.
                fx2_significand_product[lane_idx] <= sext_multiplicand * sext_multiplier;
            end
        end
    endgenerate

    always_ff @(posedge clk)
    begin
        fx2_instruction <= fx1_instruction;
        fx2_mask_value <= fx1_mask_value;
        fx2_thread_idx <= fx1_thread_idx;
        fx2_subcycle <= fx1_subcycle;
    end

    always_ff @(posedge clk, posedge reset)
    begin
        if (reset)
            fx2_instruction_valid <= '0;
        else
        begin
            fx2_instruction_valid <= fx1_instruction_valid
                && (!wb_rollback_en || wb_rollback_thread_idx != fx1_thread_idx
                || wb_rollback_pipeline != PIPE_MEM);
        end
    end
endmodule
