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
// Contains vector and scalar register files and fetches values
// from them.
//

module operand_fetch_stage(
    input                             clk,
    input                             reset,

    // From thread_select_stage
    input                             ts_instruction_valid,
    input decoded_instruction_t       ts_instruction,
    input local_thread_idx_t          ts_thread_idx,
    input subcycle_t                  ts_subcycle,

    // To fp_execute_stage1/int_execute_stage/dcache_tag_stage
    output vector_t                   of_operand1,
    output vector_t                   of_operand2,
    output vector_lane_mask_t         of_mask_value,
    output vector_t                   of_store_value,
    output decoded_instruction_t      of_instruction,
    output logic                      of_instruction_valid,
    output local_thread_idx_t         of_thread_idx,
    output subcycle_t                 of_subcycle,

    // From writeback_stage
    input                             wb_rollback_en,
    input local_thread_idx_t          wb_rollback_thread_idx,
    input                             wb_writeback_en,
    input local_thread_idx_t          wb_writeback_thread_idx,
    input                             wb_writeback_is_vector,
    input vector_t                    wb_writeback_value,
    input vector_lane_mask_t          wb_writeback_mask,
    input register_idx_t              wb_writeback_reg);

    scalar_t scalar_val1;
    scalar_t scalar_val2;
    vector_t vector_val1;
    vector_t vector_val2;

    sram_2r1w #(
        .DATA_WIDTH($bits(scalar_t)),
        .SIZE(32 * `THREADS_PER_CORE),
        .READ_DURING_WRITE("DONT_CARE")
    ) scalar_registers(
        .read1_en(ts_instruction_valid && ts_instruction.has_scalar1),
        .read1_addr({ts_thread_idx, ts_instruction.scalar_sel1}),
        .read1_data(scalar_val1),
        .read2_en(ts_instruction_valid && ts_instruction.has_scalar2),
        .read2_addr({ts_thread_idx, ts_instruction.scalar_sel2}),
        .read2_data(scalar_val2),
        .write_en(wb_writeback_en && !wb_writeback_is_vector),
        .write_addr({wb_writeback_thread_idx, wb_writeback_reg}),
        .write_data(wb_writeback_value[0]),
        .*);

    genvar lane;
    generate
        for (lane = 0; lane < NUM_VECTOR_LANES; lane++)
        begin : vector_lane_gen
            sram_2r1w #(
                .DATA_WIDTH($bits(scalar_t)),
                .SIZE(32 * `THREADS_PER_CORE),
                .READ_DURING_WRITE("DONT_CARE")
            ) vector_registers (
                .read1_en(ts_instruction.has_vector1),
                .read1_addr({ts_thread_idx, ts_instruction.vector_sel1}),
                .read1_data(vector_val1[lane]),
                .read2_en(ts_instruction.has_vector2),
                .read2_addr({ts_thread_idx, ts_instruction.vector_sel2}),
                .read2_data(vector_val2[lane]),
                .write_en(wb_writeback_en && wb_writeback_is_vector && wb_writeback_mask[NUM_VECTOR_LANES - lane - 1]),
                .write_addr({wb_writeback_thread_idx, wb_writeback_reg}),
                .write_data(wb_writeback_value[lane]),
                .*);
        end
    endgenerate

    always_ff @(posedge clk, posedge reset)
    begin
        if (reset)
            of_instruction_valid <= 0;
        else
        begin
            of_instruction_valid <= ts_instruction_valid
                && (!wb_rollback_en || wb_rollback_thread_idx != ts_thread_idx);
        end
    end

    always_ff @(posedge clk)
    begin
        of_instruction <= ts_instruction;
        of_thread_idx <= ts_thread_idx;
        of_subcycle <= ts_subcycle;
    end

    assign of_store_value = of_instruction.store_value_is_vector
            ? vector_val2
            : {{NUM_VECTOR_LANES - 1{32'd0}}, scalar_val2};

    always_comb
    begin
        case (of_instruction.op1_src)
            OP1_SRC_VECTOR1: of_operand1 = vector_val1;
            default:         of_operand1 = {NUM_VECTOR_LANES{scalar_val1}};    // OP_SRC_SCALAR1
        endcase

        case (of_instruction.op2_src)
            OP2_SRC_SCALAR2: of_operand2 = {NUM_VECTOR_LANES{scalar_val2}};
            OP2_SRC_VECTOR2: of_operand2 = vector_val2;
            default:         of_operand2 = {NUM_VECTOR_LANES{of_instruction.immediate_value}}; // OP2_SRC_IMMEDIATE
        endcase

        case (of_instruction.mask_src)
            MASK_SRC_SCALAR1: of_mask_value = scalar_val1[NUM_VECTOR_LANES - 1:0];
            MASK_SRC_SCALAR2: of_mask_value = scalar_val2[NUM_VECTOR_LANES - 1:0];
            default:          of_mask_value = {NUM_VECTOR_LANES{1'b1}};    // MASK_SRC_ALL_ONES
        endcase
    end
endmodule
