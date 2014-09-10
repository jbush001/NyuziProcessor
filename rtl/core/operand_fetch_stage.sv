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

`include "defines.sv"

//
// Contains vector and scalar register files and controls fetching values 
// from them. This stage has two cycles of latency.  In the first cycle,
// the results are fetched from register memory: two scalar and two
// vector ports.  In the second cycle, the appropriate results are selected
// for the operands.
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
	output vector_lane_mask_t         of_mask_value,
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
	input vector_lane_mask_t          wb_writeback_mask,
	input register_idx_t              wb_writeback_reg);

	scalar_t scalar_val1;
	scalar_t scalar_val2;
	vector_t vector_val1;
	vector_t vector_val2;
	scalar_t cyc1_adjusted_pc;
	decoded_instruction_t cyc1_instruction;
	logic cyc1_instruction_valid;
	thread_idx_t cyc1_thread_idx;
	subcycle_t cyc1_subcycle;

	//
	// Intermediate stage (cycle 1)
	//
	sram_2r1w #(
		.DATA_WIDTH($bits(scalar_t)),
		.SIZE(32 * `THREADS_PER_CORE),
		.READ_DURING_WRITE("DONT_CARE")
	) scalar_registers(
		.read1_en(ts_instruction_valid && ts_instruction.has_scalar1),
		.read1_addr({ ts_thread_idx, ts_instruction.scalar_sel1 }),
		.read1_data(scalar_val1),
		.read2_en(ts_instruction_valid && ts_instruction.has_scalar2),
		.read2_addr({ ts_thread_idx, ts_instruction.scalar_sel2 }),
		.read2_data(scalar_val2),
		.write_en(wb_writeback_en && !wb_writeback_is_vector),
		.write_addr({wb_writeback_thread_idx, wb_writeback_reg}),
		.write_data(wb_writeback_value[0]),
		.*);

	genvar lane;
	generate
		for (lane = 0; lane < `VECTOR_LANES; lane++)
		begin : vector_lane_gen
			sram_2r1w #(
				.DATA_WIDTH($bits(scalar_t)),
				.SIZE(32 * `THREADS_PER_CORE),
				.READ_DURING_WRITE("DONT_CARE")
			) vector_registers (
				.read1_en(ts_instruction.has_vector1),
				.read1_addr({ ts_thread_idx, ts_instruction.vector_sel1 }),
				.read1_data(vector_val1[lane]),
				.read2_en(ts_instruction.has_vector2),
				.read2_addr({ ts_thread_idx, ts_instruction.vector_sel2 }),
				.read2_data(vector_val2[lane]),
				.write_en(wb_writeback_en && wb_writeback_is_vector && wb_writeback_mask[lane]),
				.write_addr({wb_writeback_thread_idx, wb_writeback_reg}),
				.write_data(wb_writeback_value[lane]),
				.*);
		end
	endgenerate

	always_ff @(posedge clk, posedge reset)
	begin
		if (reset)
			cyc1_instruction_valid <= 0;
		else
		begin
			cyc1_instruction_valid <= ts_instruction_valid 
				&& (!wb_rollback_en || wb_rollback_thread_idx != ts_thread_idx);
		end
	end
	
	always_ff @(posedge clk)
	begin
		cyc1_instruction <= ts_instruction;
		cyc1_thread_idx <= ts_thread_idx;
		cyc1_subcycle <= ts_subcycle;

		// By convention, most processors use the current instruction address + 4 when 
		// the PC is read. It's kind of goofy, perhaps rethink this.
		cyc1_adjusted_pc <= ts_instruction.pc + 4;
	end
	
	//
	// Output stage (cycle 2)
	//
	always_ff @(posedge clk, posedge reset)
	begin
		if (reset)
			of_instruction_valid <= 0;
		else
		begin
			of_instruction_valid <= cyc1_instruction_valid && (!wb_rollback_en 
				|| wb_rollback_thread_idx != cyc1_thread_idx);
		end
	end

	always_ff @(posedge clk)
	begin
		of_instruction <= cyc1_instruction;
		of_thread_idx <= cyc1_thread_idx;
		of_subcycle <= cyc1_subcycle;

		unique case (cyc1_instruction.op1_src)
			OP1_SRC_VECTOR1: of_operand1 <= vector_val1;
			OP1_SRC_PC:      of_operand1 <= {`VECTOR_LANES{cyc1_adjusted_pc}};
			default:         of_operand1 <= {`VECTOR_LANES{scalar_val1}};	// OP_SRC_SCALAR1
		endcase
		
		unique case (cyc1_instruction.op2_src)
			OP2_SRC_SCALAR2: of_operand2 <= {`VECTOR_LANES{scalar_val2}};
			OP2_SRC_PC:      of_operand2 <= {`VECTOR_LANES{cyc1_adjusted_pc}};
			OP2_SRC_VECTOR2: of_operand2 <= vector_val2;
			default:         of_operand2 <= {`VECTOR_LANES{cyc1_instruction.immediate_value}}; // OP2_SRC_IMMEDIATE
		endcase

		unique case (cyc1_instruction.mask_src)
			MASK_SRC_SCALAR1: of_mask_value <= scalar_val1[`VECTOR_LANES - 1:0];
			MASK_SRC_SCALAR2: of_mask_value <= scalar_val2[`VECTOR_LANES - 1:0];
			default:          of_mask_value <= {`VECTOR_LANES{1'b1}};	// MASK_SRC_ALL_ONES
		endcase

		of_store_value <= cyc1_instruction.store_value_is_vector 
			? vector_val2
			: { {`VECTOR_LANES - 1{32'd0}}, scalar_val2 };
	end
endmodule

// Local Variables:
// verilog-typedef-regexp:"_t$"
// End:
