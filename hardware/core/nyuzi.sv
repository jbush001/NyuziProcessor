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
// Top level block for processor. Contains all cores and L2 cache, connects
// to AXI system bus.
//

module nyuzi
	#(parameter RESET_PC = 0)

	(input                 clk,
	input                 reset,
	axi4_interface.master axi_bus,
	output                processor_halt,
	input                 interrupt_req,

	// Non-cacheable memory signals
	output                io_write_en,
	output                io_read_en,
	output scalar_t       io_address,
	output scalar_t       io_write_data,
	input scalar_t        io_read_data);

	l2req_packet_t l2i_request[`NUM_CORES];
	ioreq_packet_t io_request[`NUM_CORES];
	logic[`TOTAL_PERF_EVENTS - 1:0] perf_events;
	logic[`TOTAL_THREADS - 1:0] ic_interrupt_pending;
	logic[`TOTAL_THREADS - 1:0] wb_interrupt_ack;
	scalar_t ic_io_read_data;	// Currently not used
	logic[31:0] perf_io_read_data;
	logic[31:0] selected_io_read_data;
	enum logic[1:0] {
		IO_PERF_COUNTERS,
		IO_INT_CONTROLLER,
		IO_ARBITER
	} io_read_source;

	// XXX AUTOLOGIC not generating these
	l2rsp_packet_t l2_response;
	iorsp_packet_t ia_response;
	thread_idx_t ic_interrupt_thread_idx;

	/*AUTOLOGIC*/
	// Beginning of automatic wires (for undeclared instantiated-module outputs)
	logic		ia_ready [`NUM_CORES];	// From io_arbiter of io_arbiter.v
	logic [`TOTAL_THREADS-1:0] ic_thread_en;// From interrupt_controller of interrupt_controller.v
	logic		l2_ready [`NUM_CORES];	// From l2_cache of l2_cache.v
	// End of automatics

	initial
	begin
		assert(`NUM_CORES >= 1 && `NUM_CORES <= (1 << `CORE_ID_WIDTH));
	end

	interrupt_controller #(.BASE_ADDRESS('h60)) interrupt_controller(
		.io_read_data(ic_io_read_data),
		.*);

	l2_cache l2_cache(
		.l2_perf_events(perf_events[`L2_PERF_EVENTS - 1:0]),
		.*);

	always_ff @(posedge clk)
	begin
		if (io_address >= 'h130 && io_address <= 'h13c)
			io_read_source <= IO_PERF_COUNTERS;
		else
			io_read_source <= IO_ARBITER;

		// XXX currently interrupt controller has no read sources,
		// but it will.
	end

	always_comb
	begin
		case (io_read_source)
			IO_PERF_COUNTERS: selected_io_read_data = perf_io_read_data;
			IO_INT_CONTROLLER: selected_io_read_data = ic_io_read_data;
			default: selected_io_read_data = io_read_data; // External read
		endcase
	end

	io_arbiter io_arbiter(
		.io_read_data(selected_io_read_data),
		.*);

	performance_counters #(
		.NUM_EVENTS(`TOTAL_PERF_EVENTS),
		.BASE_ADDRESS('h120)
	) performance_counters(
		.io_read_data(perf_io_read_data),
		.*);

	genvar core_idx;
	generate
		for (core_idx = 0; core_idx < `NUM_CORES; core_idx++)
		begin : core_gen
			core #(.CORE_ID(core_id_t'(core_idx)), .RESET_PC(RESET_PC)) core(
				.l2i_request(l2i_request[core_idx]),
				.l2_ready(l2_ready[core_idx]),
				.ic_thread_en(ic_thread_en[core_idx * `THREADS_PER_CORE+:`THREADS_PER_CORE]),
				.ic_interrupt_pending(ic_interrupt_pending[core_idx * `THREADS_PER_CORE+:`THREADS_PER_CORE]),
				.wb_interrupt_ack(wb_interrupt_ack[core_idx * `THREADS_PER_CORE+:`THREADS_PER_CORE]),
				.ior_request(io_request[core_idx]),
				.ia_ready(ia_ready[core_idx]),
				.ia_response(ia_response),
				.core_perf_events(perf_events[`L2_PERF_EVENTS + `CORE_PERF_EVENTS * core_idx+:`CORE_PERF_EVENTS]),
				.*);
		end
	endgenerate
endmodule

// Local Variables:
// verilog-typedef-regexp:"_t$"
// verilog-auto-reset-widths:unbased
// End:
