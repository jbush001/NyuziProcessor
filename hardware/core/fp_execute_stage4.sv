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
// Floating Point Execute Stage 4
//
// Floating point addition/multiplication
// - Finds leading zero to determine how much to shift to normalize for
//   addition
// - Passes through multiplication result. Could have second stage of wallace
//   tree here.
//

module fp_execute_stage4(
    input                                       clk,
    input                                       reset,

    // From fp_execute_stage3
    input vector_mask_t                         fx3_mask_value,
    input                                       fx3_instruction_valid,
    input decoded_instruction_t                 fx3_instruction,
    input local_thread_idx_t                    fx3_thread_idx,
    input subcycle_t                            fx3_subcycle,
    input [NUM_VECTOR_LANES - 1:0]              fx3_result_inf,
    input [NUM_VECTOR_LANES - 1:0]              fx3_result_nan,
    input [NUM_VECTOR_LANES - 1:0]              fx3_equal,
    input [NUM_VECTOR_LANES - 1:0][5:0]         fx3_ftoi_lshift,

    // Floating point addition/subtraction
    input scalar_t[NUM_VECTOR_LANES - 1:0]      fx3_add_significand,
    input[NUM_VECTOR_LANES - 1:0][7:0]          fx3_add_exponent,
    input[NUM_VECTOR_LANES - 1:0]               fx3_add_result_sign,
    input[NUM_VECTOR_LANES - 1:0]               fx3_logical_subtract,

    // Floating point multiplication
    input [NUM_VECTOR_LANES - 1:0][63:0]        fx3_significand_product,
    input [NUM_VECTOR_LANES - 1:0][7:0]         fx3_mul_exponent,
    input [NUM_VECTOR_LANES - 1:0]              fx3_mul_underflow,
    input [NUM_VECTOR_LANES - 1:0]              fx3_mul_sign,

    // To fp_execute_stage5
    output logic                                fx4_instruction_valid,
    output decoded_instruction_t                fx4_instruction,
    output vector_mask_t                        fx4_mask_value,
    output local_thread_idx_t                   fx4_thread_idx,
    output subcycle_t                           fx4_subcycle,
    output logic [NUM_VECTOR_LANES - 1:0]       fx4_result_inf,
    output logic [NUM_VECTOR_LANES - 1:0]       fx4_result_nan,
    output logic [NUM_VECTOR_LANES - 1:0]       fx4_equal,

    // Floating point addition/subtraction
    output logic[NUM_VECTOR_LANES - 1:0][7:0]   fx4_add_exponent,
    output logic[NUM_VECTOR_LANES - 1:0][31:0]  fx4_add_significand,
    output logic[NUM_VECTOR_LANES - 1:0]        fx4_add_result_sign,
    output logic[NUM_VECTOR_LANES - 1:0]        fx4_logical_subtract,
    output logic[NUM_VECTOR_LANES - 1:0][5:0]   fx4_norm_shift,

    // Floating point multiplication
    output logic[NUM_VECTOR_LANES - 1:0][63:0]  fx4_significand_product,
    output logic[NUM_VECTOR_LANES - 1:0][7:0]   fx4_mul_exponent,
    output logic[NUM_VECTOR_LANES - 1:0]        fx4_mul_underflow,
    output logic[NUM_VECTOR_LANES - 1:0]        fx4_mul_sign);

    logic ftoi;

    assign ftoi = fx3_instruction.alu_op == OP_FTOI;

    genvar lane_idx;
    generate
        for (lane_idx = 0; lane_idx < NUM_VECTOR_LANES; lane_idx++)
        begin : lane_logic_gen
            logic[5:0] leading_zeroes;

            // Determine normalization shift count for add/sub.
            always_comb
            begin
                // The 24th and 0th bit positions will get chopped already. The
                // normalization shift measures how far the value needs to be shifted to
                // make the leading one be truncated.
                leading_zeroes = 0;
                unique casez (fx3_add_significand[lane_idx])
                    32'b1???????????????????????????????: leading_zeroes = 0;
                    32'b01??????????????????????????????: leading_zeroes = 1;
                    32'b001?????????????????????????????: leading_zeroes = 2;
                    32'b0001????????????????????????????: leading_zeroes = 3;
                    32'b00001???????????????????????????: leading_zeroes = 4;
                    32'b000001??????????????????????????: leading_zeroes = 5;
                    32'b0000001?????????????????????????: leading_zeroes = 6;
                    32'b00000001????????????????????????: leading_zeroes = 7;
                    32'b000000001???????????????????????: leading_zeroes = 8;
                    32'b0000000001??????????????????????: leading_zeroes = 9;
                    32'b00000000001?????????????????????: leading_zeroes = 10;
                    32'b000000000001????????????????????: leading_zeroes = 11;
                    32'b0000000000001???????????????????: leading_zeroes = 12;
                    32'b00000000000001??????????????????: leading_zeroes = 13;
                    32'b000000000000001?????????????????: leading_zeroes = 14;
                    32'b0000000000000001????????????????: leading_zeroes = 15;
                    32'b00000000000000001???????????????: leading_zeroes = 16;
                    32'b000000000000000001??????????????: leading_zeroes = 17;
                    32'b0000000000000000001?????????????: leading_zeroes = 18;
                    32'b00000000000000000001????????????: leading_zeroes = 19;
                    32'b000000000000000000001???????????: leading_zeroes = 20;
                    32'b0000000000000000000001??????????: leading_zeroes = 21;
                    32'b00000000000000000000001?????????: leading_zeroes = 22;
                    32'b000000000000000000000001????????: leading_zeroes = 23;
                    32'b0000000000000000000000001???????: leading_zeroes = 24;
                    32'b00000000000000000000000001??????: leading_zeroes = 25;
                    32'b000000000000000000000000001?????: leading_zeroes = 26;
                    32'b0000000000000000000000000001????: leading_zeroes = 27;
                    32'b00000000000000000000000000001???: leading_zeroes = 28;
                    32'b000000000000000000000000000001??: leading_zeroes = 29;
                    32'b0000000000000000000000000000001?: leading_zeroes = 30;
                    32'b00000000000000000000000000000001: leading_zeroes = 31;
                    32'b00000000000000000000000000000000: leading_zeroes = 32;
                    default: leading_zeroes = 0;
                endcase
            end

            always_ff @(posedge clk)
            begin
                fx4_add_significand[lane_idx] <= fx3_add_significand[lane_idx];
                fx4_norm_shift[lane_idx] <= ftoi ? fx3_ftoi_lshift[lane_idx] : leading_zeroes;
                fx4_add_exponent[lane_idx] <= fx3_add_exponent[lane_idx];
                fx4_add_result_sign[lane_idx] <= fx3_add_result_sign[lane_idx];
                fx4_logical_subtract[lane_idx] <= fx3_logical_subtract[lane_idx];
                fx4_significand_product[lane_idx] <= fx3_significand_product[lane_idx];
                fx4_mul_exponent[lane_idx] <= fx3_mul_exponent[lane_idx];
                fx4_mul_underflow[lane_idx] <= fx3_mul_underflow[lane_idx];
                fx4_mul_sign[lane_idx] <= fx3_mul_sign[lane_idx];
                fx4_result_inf[lane_idx] <= fx3_result_inf[lane_idx];
                fx4_result_nan[lane_idx] <= fx3_result_nan[lane_idx];
                fx4_equal[lane_idx] <= fx3_equal[lane_idx];
            end
        end
    endgenerate

    always_ff @(posedge clk)
    begin
        fx4_instruction <= fx3_instruction;
        fx4_mask_value <= fx3_mask_value;
        fx4_thread_idx <= fx3_thread_idx;
        fx4_subcycle <= fx3_subcycle;
    end

    always_ff @(posedge clk, posedge reset)
    begin
        if (reset)
            fx4_instruction_valid <= '0;
        else
            fx4_instruction_valid <= fx3_instruction_valid;
    end
endmodule
