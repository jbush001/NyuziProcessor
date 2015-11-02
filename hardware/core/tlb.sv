// 
// Copyright 2015 Jeff Bush
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
// Translation lookaside buffer.
// Caches virtual to physical address translations.
//
// XXX WIP: need to make updates handle duplicates. They will need to be moved a 
// cycle later and read SRAM to determine if the data is already present. 
// Invalidate should do this as well.
//

module tlb
	#(parameter NUM_ENTRIES = 16)

	(input               clk,
	input                reset,

	// Command
	input                lookup_en,
	input                update_en,
	input                invalidate_en,
	input                invalidate_all,
	input page_index_t   request_vpage_idx,
	input page_index_t   update_ppage_idx,

	// Response
	output page_index_t  lookup_ppage_idx,
	output logic         lookup_hit);

	localparam NUM_WAYS = 4;
	localparam NUM_SETS = NUM_ENTRIES / NUM_WAYS;
	localparam SET_INDEX_WIDTH = $clog2(NUM_SETS);
	localparam WAY_INDEX_WIDTH = $clog2(NUM_WAYS);

	logic[WAY_INDEX_WIDTH - 1:0] update_way;
	logic[NUM_WAYS - 1:0] way_hit_oh;
	page_index_t way_ppage_idx[NUM_WAYS];
	page_index_t request_vpage_idx_latched;
	logic[SET_INDEX_WIDTH - 1:0] request_set_idx;

	assign request_set_idx = request_vpage_idx[SET_INDEX_WIDTH - 1:0];

	genvar way_idx;
	generate
		for (way_idx = 0; way_idx < NUM_WAYS; way_idx++)
		begin : way_gen
			page_index_t way_vpage_idx;
			logic way_valid;
			logic entry_valid[NUM_SETS];
		
			sram_1r1w #(
				.SIZE(NUM_SETS), 
				.DATA_WIDTH(`PAGE_NUM_BITS * 2),
				.READ_DURING_WRITE("NEW_DATA")
			) tlb_paddr_sram(
				.read_en(lookup_en),
				.read_addr(request_set_idx),
				.read_data({way_vpage_idx, way_ppage_idx[way_idx]}),
				.write_en(update_en && update_way == WAY_INDEX_WIDTH'(way_idx)),
				.write_addr(request_vpage_idx[SET_INDEX_WIDTH - 1:0]),
				.write_data({request_vpage_idx, update_ppage_idx}),
				.*);

			always_ff @(posedge clk, posedge reset)
			begin
				if (reset)
				begin
					for (int set_idx = 0; set_idx < NUM_SETS; set_idx++)
						entry_valid[set_idx] <= 0;

					/*AUTORESET*/
					// Beginning of autoreset for uninitialized flops
					way_valid <= '0;
					// End of automatics
				end
				else
				begin
					if (lookup_en)
						way_valid <= entry_valid[request_set_idx];

					for (int set_idx = 0; set_idx < NUM_SETS; set_idx++)
					begin
						if (invalidate_en && (invalidate_all
							|| request_vpage_idx[SET_INDEX_WIDTH - 1:0] == SET_INDEX_WIDTH'(set_idx)))
						begin
							entry_valid[set_idx] <= 0;
						end
						else if (update_en && update_way == WAY_INDEX_WIDTH'(way_idx)
							&& request_vpage_idx[SET_INDEX_WIDTH - 1:0] == SET_INDEX_WIDTH'(set_idx))
						begin
							entry_valid[set_idx] <= 1;
						end
					end
				end
			end
				
			assign way_hit_oh[way_idx] = way_valid && way_vpage_idx == request_vpage_idx_latched;
		end
	endgenerate

	assign lookup_hit = |way_hit_oh;
	always_comb
	begin
		// Enabled mux. Use OR to avoid inferring priority encoder.
		lookup_ppage_idx = 0;
		for (int i = 0; i < NUM_WAYS; i++)
		begin
			if (way_hit_oh[i])
				lookup_ppage_idx |= way_ppage_idx[i]; 
		end
	end
	
	always_ff @(posedge clk, posedge reset)
	begin
		if (reset)
		begin
			/*AUTORESET*/
			// Beginning of autoreset for uninitialized flops
			request_vpage_idx_latched <= '0;
			update_way <= '0;
			// End of automatics
		end
		else
		begin
			assert($onehot0({lookup_en, update_en, invalidate_en}));
		
`ifdef SIMULATION
			// These are triggered from the same stage, so should never
			// occur together.
			assert(!(update_en && invalidate_en));

			// Make sure we don't have duplicate entries in a set
			// If this happens, it is a software bug, since hardware
			// does nothing to prevent it.
			if (!$onehot0(way_hit_oh))
			begin
				$display("%m duplicate TLB entry %08x ways %b", {request_vpage_idx_latched, 
					{$clog2(`PAGE_SIZE){1'b0}}}, way_hit_oh);
				$finish;
			end
`endif
			if (lookup_en)
				request_vpage_idx_latched <= request_vpage_idx;

			if (update_en)
				update_way <= update_way + 1;
		end
	end
endmodule

// Local Variables:
// verilog-typedef-regexp:"_t$"
// verilog-auto-reset-widths:unbased
// End:
