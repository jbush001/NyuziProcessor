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
// Storage for control registers, special purpose locations that control 
// processor operation (for example, enabling threads)
//

module control_registers
	#(parameter core_id_t CORE_ID = 0)
	(input                                  clk,
	input                                   reset,
	
	// Control signals to various stages
	output thread_bitmap_t                  cr_thread_enable,
	output scalar_t                         cr_eret_address[`THREADS_PER_CORE],
	
	// From single cycle exec
	input                                   ix_is_eret,
	input thread_idx_t                      ix_thread_idx,
	
	// From writeback stage
	input                                   wb_fault,
	input fault_reason_t                    wb_fault_reason,
	input scalar_t                          wb_fault_pc,
	input scalar_t                          wb_fault_access_addr,
	input thread_idx_t                      wb_fault_thread_idx,
	
	// From dcache_data_stage (dd_ signals are unregistered.  dt_thread_idx 
	// represents thread going into dcache_data_stage)
	input thread_idx_t                      dt_thread_idx,
	input                                   dd_creg_write_en,
	input                                   dd_creg_read_en,
	input control_register_t                dd_creg_index,
	input scalar_t                          dd_creg_write_val,
	
	// To writeback_stage
	output scalar_t                         cr_creg_read_val,
	output thread_bitmap_t                  cr_interrupt_en,
	output scalar_t                         cr_fault_handler);
	
	scalar_t fault_access_addr[`THREADS_PER_CORE];
	fault_reason_t fault_reason[`THREADS_PER_CORE];
	logic prev_int_flag[`THREADS_PER_CORE];
	scalar_t cycle_count;
	
	always_ff @(posedge clk, posedge reset)
	begin
		if (reset)
		begin
			cr_thread_enable <= 1;
			cr_interrupt_en <= 0;
			for (int i = 0; i < `THREADS_PER_CORE; i++)
			begin
				fault_reason[i] <= FR_RESET;
				cr_eret_address[i] <= 0;
				prev_int_flag[i] <= 0;
			end

			cr_fault_handler <= 0;
			cycle_count <= 0;
		end
		else
		begin
			// Ensure a read and write don't occur in the same cycle
			assert(!(dd_creg_write_en && dd_creg_read_en));
		
			// A fault and eret are triggered from the same stage, so they
			// shouldn't occur simultaneously.
			assert(!(wb_fault && ix_is_eret));
		
			cycle_count <= cycle_count + 1;
		
			if (wb_fault)
			begin
				fault_reason[wb_fault_thread_idx] <= wb_fault_reason;
				cr_eret_address[wb_fault_thread_idx] <= wb_fault_pc;
				fault_access_addr[wb_fault_thread_idx] <= wb_fault_access_addr;
				cr_interrupt_en[wb_fault_thread_idx] <= 0;	// Disable interrupts for this thread
				prev_int_flag[wb_fault_thread_idx] <= cr_interrupt_en[wb_fault_thread_idx];
			end
			else if (ix_is_eret)
			begin	
				// Copy from prev interrupt to interrupt flag
				cr_interrupt_en[ix_thread_idx] <= prev_int_flag[ix_thread_idx];	
			end

			//
			// Write logic
			//
			if (dd_creg_write_en)
			begin
				case (dd_creg_index)
					CR_THREAD_ENABLE:    cr_thread_enable <= dd_creg_write_val;
					CR_HALT_THREAD:      cr_thread_enable[dt_thread_idx] <= 0;
					CR_FLAGS:
					begin
						prev_int_flag[dt_thread_idx] <= dd_creg_write_val[1];
						cr_interrupt_en[dt_thread_idx] <= dd_creg_write_val[0];
					end 

					CR_HALT:             cr_thread_enable <= 0;
					CR_FAULT_HANDLER:    cr_fault_handler <= dd_creg_write_val;
				endcase
			end
			
			//
			// Read logic
			//
			if (dd_creg_read_en)
			begin
				case (dd_creg_index)
					CR_THREAD_ENABLE:    cr_creg_read_val <= cr_thread_enable;
					CR_FLAGS:
					begin
						cr_creg_read_val <= { 
							prev_int_flag[dt_thread_idx],
							cr_interrupt_en[dt_thread_idx] 
						};
					end

					CR_THREAD_ID:        cr_creg_read_val <= { CORE_ID, dt_thread_idx };
					CR_FAULT_PC:         cr_creg_read_val <= cr_eret_address[dt_thread_idx];
					CR_FAULT_REASON:     cr_creg_read_val <= fault_reason[dt_thread_idx];
					CR_FAULT_HANDLER:    cr_creg_read_val <= cr_fault_handler;
					CR_FAULT_ADDRESS:    cr_creg_read_val <= fault_access_addr[dt_thread_idx];
					CR_CYCLE_COUNT:      cr_creg_read_val <= cycle_count;
					default:             cr_creg_read_val <= 32'hffffffff;
				endcase
			end
		end
	end
endmodule

// Local Variables:
// verilog-typedef-regexp:"_t$"
// End:
	
