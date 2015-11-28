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

//
// Storage for control registers.
//

module control_registers
	#(parameter core_id_t CORE_ID = 0)
	(input                                  clk,
	input                                   reset,

	// To multiple stages
	output scalar_t                         cr_eret_address[`THREADS_PER_CORE],
	output logic                            cr_mmu_en[`THREADS_PER_CORE],
	output logic                            cr_supervisor_en[`THREADS_PER_CORE],
	output logic[`ASID_WIDTH - 1:0]         cr_current_asid[`THREADS_PER_CORE],

	// From int_execute_stage
	input                                   ix_is_eret,
	input thread_idx_t                      ix_thread_idx,

	// From dcache_data_stage
	// dd_xxx signals are unregistered. dt_thread_idx represents thread going into
	// dcache_data_stage)
	input thread_idx_t                      dt_thread_idx,
	input                                   dd_creg_write_en,
	input                                   dd_creg_read_en,
	input control_register_t                dd_creg_index,
	input scalar_t                          dd_creg_write_val,

	// From writeback_stage
	input                                   wb_fault,
	input fault_reason_t                    wb_fault_reason,
	input scalar_t                          wb_fault_pc,
	input scalar_t                          wb_fault_access_vaddr,
	input thread_idx_t                      wb_fault_thread_idx,
	input subcycle_t                        wb_fault_subcycle,

	// To writeback_stage
	output scalar_t                         cr_creg_read_val,
	output thread_bitmap_t                  cr_interrupt_en,
	output subcycle_t                       cr_eret_subcycle[`THREADS_PER_CORE],
	output scalar_t                         cr_fault_handler,
	output scalar_t                         cr_tlb_miss_handler);

	scalar_t fault_access_addr[`THREADS_PER_CORE];
	fault_reason_t fault_reason[`THREADS_PER_CORE];
	logic interrupt_en_saved[`THREADS_PER_CORE];
	logic mmu_en_saved[`THREADS_PER_CORE];
	logic supervisor_en_saved[`THREADS_PER_CORE];
	scalar_t scratchpad[`THREADS_PER_CORE * 2];
	scalar_t cycle_count;

	always_ff @(posedge clk, posedge reset)
	begin
		if (reset)
		begin
			for (int i = 0; i < `THREADS_PER_CORE; i++)
			begin
				fault_reason[i] <= FR_RESET;
				cr_eret_address[i] <= 0;
				interrupt_en_saved[i] <= 0;
				fault_access_addr[i] <= '0;
				cr_mmu_en[i] <= 0;
				mmu_en_saved[i] <= 0;
				cr_eret_subcycle[i] <= 0;
				cr_supervisor_en[i] <= 1;	// Threads start in supervisor mode
				supervisor_en_saved[i] <= 1;
				cr_current_asid[i] <= 0;
			end

			for (int i = 0; i < `THREADS_PER_CORE * 2; i++)
				scratchpad[i] <= '0;

			/*AUTORESET*/
			// Beginning of autoreset for uninitialized flops
			cr_creg_read_val <= '0;
			cr_fault_handler <= '0;
			cr_interrupt_en <= '0;
			cr_tlb_miss_handler <= '0;
			cycle_count <= '0;
			// End of automatics
		end
		else
		begin
			// Ensure a read and write don't occur in the same cycle
			assert(!(dd_creg_write_en && dd_creg_read_en));

			// A fault and eret are triggered from the same stage, so they
			// must not occur simultaneously (an eret can raise a fault if it
			// is not in supervisor mode, but ix_is_eret should not be asserted
			// in that case)
			assert(!(wb_fault && ix_is_eret));

			cycle_count <= cycle_count + 1;

			if (wb_fault)
			begin
				// Copy current flags to prev flags
				interrupt_en_saved[wb_fault_thread_idx] <= cr_interrupt_en[wb_fault_thread_idx];
				mmu_en_saved[wb_fault_thread_idx] <= cr_mmu_en[wb_fault_thread_idx];
				supervisor_en_saved[wb_fault_thread_idx] <= cr_supervisor_en[ix_thread_idx];
				cr_eret_subcycle[wb_fault_thread_idx] <= wb_fault_subcycle;

				// Dispatch fault
				fault_reason[wb_fault_thread_idx] <= wb_fault_reason;
				cr_eret_address[wb_fault_thread_idx] <= wb_fault_pc;
				fault_access_addr[wb_fault_thread_idx] <= wb_fault_access_vaddr;
				cr_interrupt_en[wb_fault_thread_idx] <= 0;	// Disable interrupts for this thread
				cr_supervisor_en[ix_thread_idx] <= 1; // Enter supervisor mode on fault
				if (wb_fault_reason == FR_ITLB_MISS || wb_fault_reason == FR_DTLB_MISS)
					cr_mmu_en[wb_fault_thread_idx] <= 0;
			end
			else if (ix_is_eret)
			begin
				// Copy from prev flags to current flags
				cr_interrupt_en[ix_thread_idx] <= interrupt_en_saved[ix_thread_idx];
				cr_mmu_en[ix_thread_idx] <= mmu_en_saved[ix_thread_idx];
				cr_supervisor_en[ix_thread_idx] <= supervisor_en_saved[ix_thread_idx];
			end

			//
			// Write logic
			//
			if (dd_creg_write_en)
			begin
				case (dd_creg_index)
					CR_FLAGS:
					begin
						cr_supervisor_en[dt_thread_idx] <= dd_creg_write_val[2];
						cr_mmu_en[dt_thread_idx] <= dd_creg_write_val[1];
						cr_interrupt_en[dt_thread_idx] <= dd_creg_write_val[0];
					end

					CR_SAVED_FLAGS:
					begin
						supervisor_en_saved[dt_thread_idx] <= dd_creg_write_val[2];
						mmu_en_saved[dt_thread_idx] <= dd_creg_write_val[1];
						interrupt_en_saved[dt_thread_idx] <= dd_creg_write_val[0];
					end

					CR_FAULT_PC:         cr_eret_address[dt_thread_idx] <= dd_creg_write_val;
					CR_FAULT_HANDLER:    cr_fault_handler <= dd_creg_write_val;
					CR_TLB_MISS_HANDLER: cr_tlb_miss_handler <= dd_creg_write_val;
					CR_SCRATCHPAD0:      scratchpad[{1'b0, dt_thread_idx}] <= dd_creg_write_val;
					CR_SCRATCHPAD1:      scratchpad[{1'b1, dt_thread_idx}] <= dd_creg_write_val;
					CR_SUBCYCLE:         cr_eret_subcycle[dt_thread_idx] <= subcycle_t'(dd_creg_write_val);
					CR_CURRENT_ASID:     cr_current_asid[dt_thread_idx] <= dd_creg_write_val[`ASID_WIDTH - 1:0];
					default:
						;
				endcase
			end

			//
			// Read logic
			//
			if (dd_creg_read_en)
			begin
				case (dd_creg_index)
					CR_FLAGS:
					begin
						cr_creg_read_val <= scalar_t'({
							cr_supervisor_en[dt_thread_idx],
							cr_mmu_en[dt_thread_idx],
							cr_interrupt_en[dt_thread_idx]
						});
					end

					CR_SAVED_FLAGS:
					begin
						cr_creg_read_val <= scalar_t'({
							supervisor_en_saved[dt_thread_idx],
							mmu_en_saved[dt_thread_idx],
							interrupt_en_saved[dt_thread_idx]
						});
					end

					CR_THREAD_ID:        cr_creg_read_val <= scalar_t'({CORE_ID, dt_thread_idx});
					CR_FAULT_PC:         cr_creg_read_val <= cr_eret_address[dt_thread_idx];
					CR_FAULT_REASON:     cr_creg_read_val <= scalar_t'(fault_reason[dt_thread_idx]);
					CR_FAULT_HANDLER:    cr_creg_read_val <= cr_fault_handler;
					CR_FAULT_ADDRESS:    cr_creg_read_val <= fault_access_addr[dt_thread_idx];
					CR_TLB_MISS_HANDLER: cr_creg_read_val <= cr_tlb_miss_handler;
					CR_CYCLE_COUNT:      cr_creg_read_val <= cycle_count;
					CR_SCRATCHPAD0:      cr_creg_read_val <= scratchpad[{1'b0, dt_thread_idx}];
					CR_SCRATCHPAD1:      cr_creg_read_val <= scratchpad[{1'b1, dt_thread_idx}];
					CR_SUBCYCLE:         cr_creg_read_val <= scalar_t'(cr_eret_subcycle[dt_thread_idx]);
					CR_CURRENT_ASID:     cr_creg_read_val <= scalar_t'(cr_current_asid[dt_thread_idx]);
					default:             cr_creg_read_val <= 32'hffffffff;
				endcase
			end
		end
	end
endmodule

// Local Variables:
// verilog-typedef-regexp:"_t$"
// verilog-auto-reset-widths:unbased
// End:

