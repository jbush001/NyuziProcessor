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
// Top level block for processor.  Contains all cores and L2 cache, connects
// to AXI system bus.
//

module nyuzi(
	input                 clk,
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
	l2rsp_packet_t l2_response;
	logic l2_ready[`NUM_CORES];
	logic[`NUM_CORES - 1:0] core_halt;
	ioreq_packet_t io_request[`NUM_CORES];
	logic ia_ready[`NUM_CORES];
	iorsp_packet_t ia_response;
	logic[`NUM_CORES - 1:0] perf_dcache_hit;
	logic[`NUM_CORES - 1:0] perf_dcache_miss;
	logic[`NUM_CORES - 1:0] perf_icache_hit;
	logic[`NUM_CORES - 1:0] perf_icache_miss;
	logic[`NUM_CORES - 1:0] perf_instruction_issue;
	logic[`NUM_CORES - 1:0] perf_instruction_retire;
	logic[`NUM_CORES - 1:0] perf_store_count;
	logic[`NUM_CORES - 1:0] perf_store_rollback;
	logic perf_l2_hit;		
	logic perf_l2_miss;		
	logic perf_l2_writeback;	

	assign processor_halt = |core_halt;

	genvar core_idx;
	generate
		for (core_idx = 0; core_idx < `NUM_CORES; core_idx++)
		begin : core_gen
			core #(.CORE_ID(core_idx)) core(
				.l2i_request(l2i_request[core_idx]),
				.l2_ready(l2_ready[core_idx]),
				.processor_halt(core_halt[core_idx]),
				.ior_request(io_request[core_idx]),
				.ia_ready(ia_ready[core_idx]),
				.ia_response(ia_response),
				.perf_dcache_hit(perf_dcache_hit[core_idx]),
				.perf_dcache_miss(perf_dcache_miss[core_idx]),
				.perf_icache_hit(perf_icache_hit[core_idx]),
				.perf_icache_miss(perf_icache_miss[core_idx]),
				.perf_instruction_issue(perf_instruction_issue[core_idx]),
				.perf_instruction_retire(perf_instruction_retire[core_idx]),
				.perf_store_count(perf_store_count[core_idx]),
				.perf_store_rollback(perf_store_rollback[core_idx]),
				.*);
		end
	endgenerate
	
	l2_cache l2_cache(.*);
	io_arbiter io_arbiter(.*);

	performance_counters #(.NUM_COUNTERS(3 + 8 * `NUM_CORES)) performance_counters(
		.perf_event({
			// Per core events (XXX should combine these)
			perf_dcache_hit,
			perf_dcache_miss,
			perf_icache_hit,
			perf_icache_miss,
			perf_instruction_issue,
			perf_instruction_retire,
			perf_store_count,
			perf_store_rollback,
			
			// Shared events
			perf_l2_hit,
			perf_l2_miss,		
			perf_l2_writeback}),
		.*);
endmodule

// Local Variables:
// verilog-typedef-regexp:"_t$"
// End:
