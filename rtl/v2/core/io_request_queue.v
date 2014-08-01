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
// Handles non-cacheable memory operations to memory mapped registers
//

module io_request_queue
	#(parameter CORE_ID = 0)

	(input                                 clk,
	input                                  reset,
                                           
	// From dcache_data_stage              
	input                                  dd_io_write_en,
	input                                  dd_io_read_en,
	input thread_idx_t                     dd_io_thread_idx,
	input scalar_t                         dd_io_addr,
	input scalar_t                         dd_io_write_value,
	                                       
	// To writeback stage                  
	output scalar_t                        ior_read_value,
	output logic                           ior_rollback_en,
	
	// To thread select stage
	output logic[`THREADS_PER_CORE - 1:0]  ior_wake_bitmap);


	// XXX placeholder
	assign ior_wake_bitmap = 0;
	assign ior_rollback_en = 0;
	assign ior_read_value = 0;
endmodule

// Local Variables:
// verilog-typedef-regexp:"_t$"
// End:
