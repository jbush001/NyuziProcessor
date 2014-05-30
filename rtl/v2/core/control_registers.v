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
// Storage for control registers, special purpose locations that control processor operation
// (for example, enabling threads)
//

module control_registers
	#(parameter CORE_ID = 0)
	(input                                   clk,
	input                                   reset,
	
	// Control signals to various stages
	output logic [`THREADS_PER_CORE - 1:0]  cr_thread_enable,
	
	// From writeback stage
	input                                   wb_fault,
	input fault_reason_t                    wb_fault_reason,
	input scalar_t                          wb_fault_address,
	
	// From dcache_data_stage (dd_ signals are unregistered.  dt_thread_idx represents thread
	// going into dcache_data_stage)
	input thread_idx_t                      dt_thread_idx,
	input                                   dd_creg_write_en,
	input                                   dd_creg_read_en,
	input control_register_t                dd_creg_index,
	input scalar_t                          dd_creg_write_val,
	
	// To writeback_stage
	output scalar_t                         cr_creg_read_val);
	
	scalar_t fault_address;
	fault_reason_t fault_reason;
	
	always_ff @(posedge clk, posedge reset)
	begin
		if (reset)
		begin
			cr_thread_enable <= 1'b1;
			fault_address <= 0;
			fault_reason <= FR_NONE;
		end
		else
		begin
			if (wb_fault)
			begin
				fault_reason <= wb_fault_reason;
				fault_address <= wb_fault_address;
			end
			
			if (dd_creg_write_en)
			begin
				case (dd_creg_index)
					CR_THREAD_ENABLE: cr_thread_enable <= dd_creg_write_val;
					CR_HALT_THREAD: cr_thread_enable[dt_thread_idx] <= 0;
					CR_HALT: cr_thread_enable <= 0;
				endcase
			end
			else if (dd_creg_read_en)
			begin
				case (dd_creg_index)
					CR_THREAD_ID: cr_creg_read_val <= { CORE_ID, dt_thread_idx };
					CR_FAULT_ADDRESS: cr_creg_read_val <= fault_address;
					CR_FAULT_REASON: cr_creg_read_val <= fault_reason;
				endcase
			end
		end
	end
endmodule

	
