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
// Instruction Pipeline L1 Data cache tag stage.
// Contains tags and cache line states.  These are queried when a memory access 
// occurs.  There is one cycle of latency to fetch these, so they will be 
// checked by the next stage. The L1 data cache is set associative. There is a 
// separate block of tag ram for each way, which are read in parallel.  The next
// stage will check them to see if there is a cache hit on one of the ways.
//

module dcache_tag_stage
	(input                                      clk,
	input                                       reset,
                                                
	// From operand fetch stage                 
	input vector_t                              of_operand1,
	input vector_t                              of_operand2,
	input vector_lane_mask_t                    of_mask_value,
	input vector_t                              of_store_value,
	input                                       of_instruction_valid,
	input decoded_instruction_t                 of_instruction,
	input thread_idx_t                          of_thread_idx,
	input subcycle_t                            of_subcycle,
                                                
	// to dcache data stage                     
	output                                      dt_instruction_valid,
	output decoded_instruction_t                dt_instruction,
	output vector_lane_mask_t                   dt_mask_value,
	output thread_idx_t                         dt_thread_idx,
	output l1d_addr_t                           dt_request_addr,
	output vector_t                             dt_store_value,
	output subcycle_t                           dt_subcycle,
	output logic                                dt_valid[`L1D_WAYS],
	output l1d_tag_t                            dt_tag[`L1D_WAYS],
	
	// from dcache_data_stage
	input                                       dd_update_lru_en,
	input l1d_way_idx_t                         dd_update_lru_way,
	
	// From l2_interface
	input                                       l2i_dcache_lru_fill_en,
	input l1d_set_idx_t                         l2i_dcache_lru_fill_set,
	input [`L1D_WAYS - 1:0]                     l2i_dtag_update_en_oh,
	input l1d_set_idx_t                         l2i_dtag_update_set,
	input l1d_tag_t                             l2i_dtag_update_tag,
	input                                       l2i_dtag_update_valid,
	input                                       l2i_snoop_en,
	input l1d_set_idx_t                         l2i_snoop_set,

	// To l2_interface
	output logic                                dt_snoop_valid[`L1D_WAYS],
	output l1d_tag_t                            dt_snoop_tag[`L1D_WAYS],
	output l1d_way_idx_t                        dt_fill_lru,
	
	// From writeback stage                     
	input logic                                 wb_rollback_en,
	input thread_idx_t                          wb_rollback_thread_idx);

	l1d_addr_t request_addr_nxt;
	l1d_set_idx_t request_set;
	logic is_io_address;
	logic memory_read_en;
	logic memory_access_en;

	assign memory_access_en = of_instruction_valid 
		&& (!wb_rollback_en || wb_rollback_thread_idx != of_thread_idx) 
		&& of_instruction.pipeline_sel == PIPE_MEM;
	assign memory_read_en = memory_access_en && of_instruction.is_load;
	assign is_io_address = request_addr_nxt[31:16] == 16'hffff;
	assign request_addr_nxt = of_operand1[~of_subcycle] + of_instruction.immediate_value;

	//
	// Way metadata
	//
	genvar way_idx;
	generate
		for (way_idx = 0; way_idx < `L1D_WAYS; way_idx++)
		begin : way_tag_gen
			logic line_valid[`L1D_SETS];

			sram_2r1w #(
				.DATA_WIDTH($bits(l1d_tag_t)), 
				.SIZE(`L1D_SETS),
				.READ_DURING_WRITE("NEW_DATA")
			) sram_tags(
				.read1_en(memory_read_en && !is_io_address),
				.read1_addr(request_addr_nxt.set_idx),
				.read1_data(dt_tag[way_idx]),
				.read2_en(l2i_snoop_en),
				.read2_addr(l2i_snoop_set),
				.read2_data(dt_snoop_tag[way_idx]),
				.write_en(l2i_dtag_update_en_oh[way_idx]),
				.write_addr(l2i_dtag_update_set),
				.write_data(l2i_dtag_update_tag),
				.*);

			always_ff @(posedge clk, posedge reset)
			begin
				if (reset)
				begin
					for (int set_idx = 0; set_idx < `L1D_SETS; set_idx++)
						line_valid[set_idx] <= 0;
				end
				else 
				begin
					if (l2i_dtag_update_en_oh[way_idx])
						line_valid[l2i_dtag_update_set] <= l2i_dtag_update_valid;
					
					// Fetch cache line state for pipeline
					if (memory_read_en && !is_io_address)
					begin
						if (l2i_dtag_update_en_oh[way_idx] && l2i_dtag_update_set == request_addr_nxt.set_idx)
							dt_valid[way_idx] <= l2i_dtag_update_valid;	// Bypass
						else
							dt_valid[way_idx] <= line_valid[request_addr_nxt.set_idx];
					end

					// Fetch cache line state for snoop
					if (l2i_snoop_en)
					begin
						if (l2i_dtag_update_en_oh[way_idx] && l2i_dtag_update_set == l2i_snoop_set)
							dt_snoop_valid[way_idx] <= l2i_dtag_update_valid;	// Bypass
						else
							dt_snoop_valid[way_idx] <= line_valid[l2i_snoop_set];
					end
				end
			end
		end
	endgenerate

	cache_lru #(.NUM_WAYS(`L1D_WAYS), .NUM_SETS(`L1D_SETS)) lru(
		.fill_en(l2i_dcache_lru_fill_en),
		.fill_set(l2i_dcache_lru_fill_set),
		.fill_way(dt_fill_lru),
		.access_en(memory_access_en),
		.access_set(request_addr_nxt.set_idx),
		.access_update_en(dd_update_lru_en),
		.access_update_way(dd_update_lru_way),
		.*);

	always_ff @(posedge clk, posedge reset)
	begin
		if (reset)
		begin
			/*AUTORESET*/
			// Beginning of autoreset for uninitialized flops
			dt_instruction <= 1'h0;
			dt_instruction_valid <= 1'h0;
			dt_mask_value <= 1'h0;
			dt_request_addr <= 1'h0;
			dt_store_value <= 1'h0;
			dt_subcycle <= 1'h0;
			dt_thread_idx <= 1'h0;
			// End of automatics
		end
		else
		begin
			assert($onehot0(l2i_dtag_update_en_oh));
			dt_instruction_valid <= memory_access_en;
			dt_instruction <= of_instruction;
			dt_mask_value <= of_mask_value;
			dt_thread_idx <= of_thread_idx;
			dt_request_addr <= request_addr_nxt;
			dt_store_value <= of_store_value;
			dt_subcycle <= of_subcycle;
		end
	end
endmodule

// Local Variables:
// verilog-typedef-regexp:"_t$"
// End:
