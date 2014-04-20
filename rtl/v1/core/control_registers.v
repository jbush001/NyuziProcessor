// 
// Copyright (C) 2011-2014 Jeff Bush
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
// This module contains the control registers, special purpose locations
// that are used for system level functions like obtaining the current strand
// ID.
//

module control_registers
	#(parameter CORE_ID = 0)
	
	(input                                clk, 
	input                                 reset,

	// Control signals to from other units
	output logic[`STRANDS_PER_CORE - 1:0] cr_strand_enable,
	output logic[31:0]                    cr_exception_handler_address,
	input                                 wb_latch_fault,
	input [31:0]                          wb_fault_pc,
	input [`STRAND_INDEX_WIDTH - 1:0]     wb_fault_strand,

	// From memory access stage
	input[`STRAND_INDEX_WIDTH - 1:0]      ex_strand,	// strand that is reading or writing control register
	input control_register_t              ma_cr_index,
	input                                 ma_cr_read_en,
	input                                 ma_cr_write_en,
	input[31:0]                           ma_cr_write_value,
	
	// To writeback stage
	output logic[31:0]                    cr_read_value);

	logic[31:0] saved_fault_pc[`STRANDS_PER_CORE];

	// Need to move this out of always for Xilinx tools.
	wire[31:0] strand_saved_fault_pc = saved_fault_pc[ex_strand];

	always_comb
	begin
		unique case (ma_cr_index)
			CR_STRAND_ID: cr_read_value = { CORE_ID, ex_strand }; 		// Strand ID
			CR_EXCEPTION_HANDLER: cr_read_value = cr_exception_handler_address;
			CR_FAULT_ADDRESS: cr_read_value = strand_saved_fault_pc;
			CR_STRAND_ENABLE: cr_read_value = cr_strand_enable;
			default: cr_read_value = 0;
		endcase
	end

	always_ff @(posedge clk, posedge reset)
	begin : update
		if (reset)
		begin
		 	cr_strand_enable <= 1'b1;	// Enable strand 0
			for (int i = 0; i < `STRANDS_PER_CORE; i++)
				saved_fault_pc[i] <= 0;

			/*AUTORESET*/
			// Beginning of autoreset for uninitialized flops
			cr_exception_handler_address <= 32'h0;
			// End of automatics
		end
		else
		begin
			assert($onehot0({ma_cr_read_en, ma_cr_write_en}));
		
			// Transfer to a control register
			if (ma_cr_write_en)
			begin
				case (ma_cr_index)
					CR_HALT_STRAND: cr_strand_enable <= cr_strand_enable & ~(1'b1 << ex_strand);
					CR_EXCEPTION_HANDLER: cr_exception_handler_address <= ma_cr_write_value;
					CR_STRAND_ENABLE: cr_strand_enable <= ma_cr_write_value;
					CR_HALT: cr_strand_enable <= 0;	// HALT
				endcase
			end
			
			// Fault handling
			if (wb_latch_fault)
				saved_fault_pc[wb_fault_strand] <= wb_fault_pc;
		end
	end
endmodule

// Local Variables:
// verilog-typedef-regexp:"_t$"
// End:

