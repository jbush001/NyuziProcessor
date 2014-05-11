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

module control_registers(
	input                                   clk,
	input                                   reset,
	
	// Control signals to various stages
	output logic [`THREADS_PER_CORE - 1:0]  cr_thread_enable,
	
	// From dcache_data_stage (dd_ signals are unregistered.  dt_thread_idx represents thread
	// going into dcache_data_stage)
	input thread_idx_t                      dt_thread_idx,
	input                                   dd_creg_write_en,
	input                                   dd_creg_read_en,
	input control_register_t                dd_creg_index,
	input scalar_t                          dd_creg_write_val,
	
	// To writeback_stage
	output scalar_t             cr_creg_read_val);
	
	always @(posedge clk, posedge reset)
	begin
		if (reset)
		begin
			cr_thread_enable <= 1'b1;
		end
		else
		begin
			if (dd_creg_write_en)
			begin
				case (dd_creg_index)
					CR_STRAND_ENABLE: cr_thread_enable <= dd_creg_write_val;
					CR_HALT_STRAND: cr_thread_enable[dt_thread_idx] <= 0;
					CR_HALT: cr_thread_enable <= 0;
				endcase
			end
			else if (dd_creg_read_en)
			begin
				case (dd_creg_index)
					CR_STRAND_ID: cr_creg_read_val <= dt_thread_idx;
				endcase
			end
		end
	end
endmodule

	
