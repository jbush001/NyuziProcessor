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

module dcache_tag_stage(
	input                             clk,
	input                             reset,

	// From operand fetch stage
	input vector_t                    of_operand1,
	input vector_t                    of_operand2,
	input [`VECTOR_LANES - 1:0]       of_mask_value,
	input vector_t                    of_store_value,
	input                             of_instruction_valid,
	input decoded_instruction_t       of_instruction,
	input thread_idx_t                of_thread_idx,

	// to dcache data stage
	output                            dt_instruction_valid,
	output decoded_instruction_t      dt_instruction,
	output [`VECTOR_LANES - 1:0]      dt_mask_value,
	output thread_idx_t               dt_thread_idx,
	output scalar_t                   dt_request_addr,
	output vector_t                   dt_store_value,

	// From writeback stage
	input logic                      wb_rollback_en,
	input thread_idx_t               wb_rollback_thread_idx);


	always_ff @(posedge clk, posedge reset)
	begin
		if (reset)
		begin
			/*AUTORESET*/
			// Beginning of autoreset for uninitialized flops
			dt_instruction <= 1'h0;
			dt_instruction_valid <= 1'h0;
			dt_mask_value <= {(1+(`VECTOR_LANES-1)){1'b0}};
			dt_request_addr <= 1'h0;
			dt_store_value <= 1'h0;
			dt_thread_idx <= 1'h0;
			// End of automatics
		end
		else
		begin
			dt_instruction_valid <= of_instruction_valid && (!wb_rollback_en || wb_rollback_thread_idx != of_thread_idx)
				&& of_instruction.pipeline_sel == PIPE_MEM;
			dt_instruction <= of_instruction;
			dt_mask_value <= of_mask_value;
			dt_thread_idx <= of_thread_idx;
			dt_request_addr <= of_operand1[0] + of_instruction.immediate_value;
			dt_store_value <= of_store_value;
		end
	end
endmodule

// Local Variables:
// verilog-typedef-regexp:"_t$"
// End:
