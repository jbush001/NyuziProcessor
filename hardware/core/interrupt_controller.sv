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
// Dispatches interrupts to threads.
// Much functionality is stubbed in here. Features that should be implemented:
// - Inter-CPU/inter-thread interrupts
// - Multiple external interrupts with prioritization
// - Level/edge triggered external interrupts
// - Wake thread on interrupt
// - Currently dispatches external interrupts only on thread 0. Should enable
//   load balancing somehow...
//
module interrupt_controller
	#(parameter BASE_ADDRESS = 0)
	(input                                      clk,
	input                                       reset,

	// IO bus interface
	io_bus_interface.slave                      io_bus,

	// From external interface
	input                                       interrupt_req,

	// To cores
	output logic[`TOTAL_THREADS - 1:0]          ic_thread_en,
	output logic[`TOTAL_THREADS - 1:0]          ic_interrupt_pending,
	output interrupt_id_t                       ic_interrupt_id[`TOTAL_THREADS - 1:0],
	output                                      processor_halt,

	// From cores
	input [`TOTAL_THREADS - 1:0]                wb_interrupt_ack);

	always_ff @(posedge clk, posedge reset)
	begin
		if (reset)
			ic_thread_en <= 1;
		else if (io_bus.write_en)
		begin
			case (io_bus.address)
				// Thread enable flag handling. This is limited to 32 threads.
				// To add more, put the next 32 bits in subsequent io addresses.
				BASE_ADDRESS: // resume thread
					ic_thread_en <= ic_thread_en | io_bus.write_data[`TOTAL_THREADS - 1:0];

				BASE_ADDRESS + 4: // halt thread
					ic_thread_en <= ic_thread_en & ~io_bus.write_data[`TOTAL_THREADS - 1:0];
			endcase
		end
	end

	assign processor_halt = ic_thread_en == 0;

	genvar thread_idx;
	generate
		for (thread_idx = 0; thread_idx < `TOTAL_THREADS; thread_idx++)
		begin : core_int_gen
			assign ic_interrupt_id[thread_idx] = 0;
			always_ff @(posedge clk, posedge reset)
			begin
				if (reset)
					ic_interrupt_pending[thread_idx] <= 0;
				else if (!ic_interrupt_pending[thread_idx] && interrupt_req && thread_idx == 0) // XXX hardcoded
					ic_interrupt_pending[thread_idx] <= 1;
				else if (wb_interrupt_ack[thread_idx])
					ic_interrupt_pending[thread_idx] <= 0;
			end
		end
	endgenerate
endmodule
