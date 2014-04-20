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
// Instruction Pipeline - Instruction Fetch Data Stage
// - If the last fetched PC was determined to be in the instruction cache, fetch the actual contents
//   of the corresponding cache line here.
//
module ifetch_data_stage(
	input                    clk,
	input                    reset,

	// From instruction fetch tag stage
	input                    ift_cache_hit,
	input scalar_t           ift_pc,
	input thread_idx_t       ift_thread_idx,

	// To instruction decode stage
	output scalar_t          ifd_instruction,
	output logic             ifd_instruction_valid,
	output scalar_t          ifd_pc,
	output thread_idx_t      ifd_thread_idx,

	// From rollback controller
	input                    wb_rollback_en,
	input thread_idx_t       wb_rollback_thread_idx,

	// (simulation only) to cache data placeholder
 	output scalar_t          SIM_icache_request_addr,
	input scalar_t           SIM_icache_data);

	// XXX stubbed in...
	assign ifd_instruction = { SIM_icache_data[7:0], SIM_icache_data[15:8], SIM_icache_data[23:16], SIM_icache_data[31:24] };
	assign SIM_icache_request_addr = ift_pc;

	always_ff @(posedge clk, posedge reset)
	begin
		if (reset)
		begin
			/*AUTORESET*/
			// Beginning of autoreset for uninitialized flops
			ifd_instruction_valid <= 1'h0;
			ifd_pc <= 1'h0;
			ifd_thread_idx <= 1'h0;
			// End of automatics
		end
		else
		begin
			ifd_instruction_valid <= ift_cache_hit && (!wb_rollback_en || wb_rollback_thread_idx 
				!= ift_thread_idx);
			ifd_pc <= ift_pc + 4;
			ifd_thread_idx <= ift_thread_idx;
		end
	end
endmodule

// Local Variables:
// verilog-typedef-regexp:"_t$"
// End:
