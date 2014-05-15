//
// Copyright (C) 2014 Jeff Bush
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
// Contains vector and scalar register files and controls fetching values 
// from them.  The fetch has one cycle of latency. 
// There is some combinational logic at the end of this stage to select
// the proper results.
//
module operand_fetch_stage(
	input                             clk,
	input                             reset,

	// From thread select stage
	input                             ts_instruction_valid,
	input decoded_instruction_t       ts_instruction,
	input thread_idx_t                ts_thread_idx,
	input subcycle_t                  ts_subcycle,
	
	// To execution units
	output vector_t                   of_operand1,
	output vector_t                   of_operand2,
	output logic[`VECTOR_LANES - 1:0] of_mask_value,
	output vector_t                   of_store_value,
	output decoded_instruction_t      of_instruction,
	output logic                      of_instruction_valid,
	output thread_idx_t               of_thread_idx,
	output subcycle_t                 of_subcycle,

	// From rollback stage
	input                             wb_rollback_en,
	input thread_idx_t                wb_rollback_thread_idx,

	// From writeback stage
	input                             wb_writeback_en,
	input thread_idx_t                wb_writeback_thread_idx,
	input                             wb_writeback_is_vector,
	input vector_t                    wb_writeback_value,
	input [`VECTOR_LANES - 1:0]       wb_writeback_mask,
	input register_idx_t              wb_writeback_reg);

	scalar_t scalar_val1;
	scalar_t scalar_val2;
	vector_t vector_val1;
	vector_t vector_val2;

	sram_2r1w #(
		.DATA_WIDTH($bits(scalar_t)),
		.SIZE(32 * `THREADS_PER_CORE)
	) scalar_register_file(
		.read1_en(ts_instruction_valid && ts_instruction.has_scalar1),
		.read1_addr({ ts_thread_idx, ts_instruction.scalar_sel1 }),
		.read1_data(scalar_val1),
		.read2_en(ts_instruction_valid && ts_instruction.has_scalar2),
		.read2_addr({ ts_thread_idx, ts_instruction.scalar_sel2 }),
		.read2_data(scalar_val2),
		.write_en(wb_writeback_en && !wb_writeback_is_vector),
		.write_addr({wb_writeback_thread_idx, wb_writeback_reg}),
		.write_data(wb_writeback_value[0]),
		.write_byte_en(0),
		.*);

	genvar lane;
	generate
		for (lane = 0; lane < `VECTOR_LANES; lane++)
		begin : laneram
			sram_2r1w #(
				.DATA_WIDTH($bits(scalar_t)),
				.SIZE(32 * `THREADS_PER_CORE)
			) vector_register_file (
				.read1_en(ts_instruction.has_vector1),
				.read1_addr({ ts_thread_idx, ts_instruction.vector_sel1 }),
				.read1_data(vector_val1[lane]),
				.read2_en(ts_instruction.has_vector2),
				.read2_addr({ ts_thread_idx, ts_instruction.vector_sel2 }),
				.read2_data(vector_val2[lane]),
				.write_en(wb_writeback_en && wb_writeback_is_vector && wb_writeback_mask[lane]),
				.write_addr({wb_writeback_thread_idx, wb_writeback_reg}),
				.write_data(wb_writeback_value[lane]),
				.write_byte_en(0),
				.*);
		end
	endgenerate

	always_ff @(posedge clk, posedge reset)
	begin
		if (reset)
		begin
			of_instruction <= 0;
			/*AUTORESET*/
			// Beginning of autoreset for uninitialized flops
			of_instruction_valid <= 1'h0;
			of_subcycle <= 1'h0;
			of_thread_idx <= 1'h0;
			// End of automatics
		end
		else
		begin
			of_instruction_valid <= ts_instruction_valid && (!wb_rollback_en || wb_rollback_thread_idx 
				!= ts_thread_idx);
			of_instruction <= ts_instruction;
			of_thread_idx <= ts_thread_idx;
			of_subcycle <= ts_subcycle;
		end
	end
	
	// Combinational logic after flops to pull correct result
	always_comb
	begin
		if (of_instruction.op1_is_vector)
			of_operand1 = vector_val1;
		else if (of_instruction.scalar_sel1 == `REG_PC)
			of_operand1 = {`VECTOR_LANES{of_instruction.pc + 4}};
		else
			of_operand1 = {`VECTOR_LANES{scalar_val1}};
			
		unique case (of_instruction.op2_src)
			OP2_SRC_SCALAR2:	
			begin
				if (of_instruction.scalar_sel2 == `REG_PC)
					of_operand2 = {`VECTOR_LANES{of_instruction.pc + 4}};
				else
					of_operand2 = {`VECTOR_LANES{scalar_val2}};
			end
			OP2_SRC_VECTOR2:	of_operand2 = vector_val2;
			OP2_SRC_IMMEDIATE:  of_operand2 = {`VECTOR_LANES{of_instruction.immediate_value}};
			default:			of_operand2 = {$bits(vector_t){1'b0}}; // Don't care
		endcase

		unique case (of_instruction.mask_src)
			MASK_SRC_SCALAR1:		of_mask_value = scalar_val1[`VECTOR_LANES - 1:0];
			MASK_SRC_SCALAR1_INV:	of_mask_value = ~scalar_val1[`VECTOR_LANES - 1:0];
			MASK_SRC_SCALAR2:		of_mask_value = scalar_val2[`VECTOR_LANES - 1:0];
			MASK_SRC_SCALAR2_INV:	of_mask_value = ~scalar_val2[`VECTOR_LANES - 1:0];
			MASK_SRC_ALL_ONES:		of_mask_value = {`VECTOR_LANES{1'b1}};
			default:				of_mask_value = {`VECTOR_LANES{1'b0}};
		endcase
	end

	assign of_store_value = of_instruction.store_value_is_vector 
		? vector_val2
		: { {`VECTOR_LANES - 1{32'd0}}, scalar_val2 };
endmodule

// Local Variables:
// verilog-typedef-regexp:"_t$"
// End:
