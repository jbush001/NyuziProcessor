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
// L1 Data cache tag stage.
// Contains tags and cache line states.  These are queried when a memory access 
// occurs.  There is one cycle of latency to fetch these, so they will be 
// checked by the next stage.
//

module dcache_tag_stage
	(input                                      clk,
	input                                       reset,
                                                
	// From operand fetch stage                 
	input vector_t                              of_operand1,
	input vector_t                              of_operand2,
	input [`VECTOR_LANES - 1:0]                 of_mask_value,
	input vector_t                              of_store_value,
	input                                       of_instruction_valid,
	input decoded_instruction_t                 of_instruction,
	input thread_idx_t                          of_thread_idx,
	input subcycle_t                            of_subcycle,
                                                
	// to dcache data stage                     
	output                                      dt_instruction_valid,
	output decoded_instruction_t                dt_instruction,
	output [`VECTOR_LANES - 1:0]                dt_mask_value,
	output thread_idx_t                         dt_thread_idx,
	output l1d_addr_t                           dt_request_addr,
	output vector_t                             dt_store_value,
	output subcycle_t                           dt_subcycle,
	output cache_line_state_t                   dt_state[`L1D_WAYS],
	output l1d_tag_t                            dt_tag[`L1D_WAYS],
	output logic[2:0]                           dt_lru_flags,
	
	// from dcache_data_stage
	input                                       dd_update_lru_en,
	input [2:0]                                 dd_update_lru_flags,
	input l1d_set_idx_t                         dd_update_lru_set,
	
	// From ring controller
	input [`L1D_WAYS - 1:0]                     rc_dtag_update_en_oh,
	input l1d_set_idx_t                         rc_dtag_update_set,
	input l1d_tag_t                             rc_dtag_update_tag,
	input cache_line_state_t                    rc_dtag_update_state,
	input                                       rc_snoop_en,
	input l1d_set_idx_t                         rc_snoop_set,

	// To ring controller
	output cache_line_state_t                   dt_snoop_state[`L1D_WAYS],
	output l1d_tag_t                            dt_snoop_tag[`L1D_WAYS],
	output l1d_way_idx_t                        dt_snoop_lru,
	
	// From writeback stage                     
	input logic                                 wb_rollback_en,
	input thread_idx_t                          wb_rollback_thread_idx);

	l1d_addr_t request_addr_nxt;
	l1d_set_idx_t request_set;
	logic is_io_address;
	logic memory_access_en;
	logic[2:0] snoop_lru_flags;

	assign memory_access_en = of_instruction_valid && (!wb_rollback_en 
		|| wb_rollback_thread_idx != of_thread_idx) && of_instruction.pipeline_sel == PIPE_MEM;
	assign is_io_address = request_addr_nxt[31:16] == 16'hffff;
	
	always_comb
	begin
		if (of_instruction.memory_access_type == MEM_SCGATH 
			|| of_instruction.memory_access_type == MEM_SCGATH_M
			|| of_instruction.memory_access_type == MEM_SCGATH_IM)
		begin
			request_addr_nxt = of_operand1[`VECTOR_LANES - 1 - of_subcycle] + of_instruction.immediate_value;
		end
		else
			request_addr_nxt = of_operand1[0] + of_instruction.immediate_value;
	end
	
	// Way metadata
	genvar way_idx;
	generate
		for (way_idx = 0; way_idx < `L1D_WAYS; way_idx++)
		begin : way_tags
			cache_line_state_t line_states[`L1D_SETS];

			sram_2r1w #(.DATA_WIDTH($bits(l1d_tag_t)), .SIZE(`L1D_SETS)) tag_ram(
				.read1_en(memory_access_en && !is_io_address),
				.read1_addr(request_addr_nxt.set_idx),
				.read1_data(dt_tag[way_idx]),
				.read2_en(rc_snoop_en),
				.read2_addr(rc_snoop_set),
				.read2_data(dt_snoop_tag[way_idx]),
				.write_en(rc_dtag_update_en_oh[way_idx]),
				.write_addr(rc_dtag_update_set),
				.write_data(rc_dtag_update_tag),
				.write_byte_en(0),	// unused
				.*);

			always_ff @(posedge clk, posedge reset)
			begin
				if (reset)
				begin
					for (int set_idx = 0; set_idx < `L1D_SETS; set_idx++)
						line_states[set_idx] <= CL_STATE_INVALID;
				end
				else 
				begin
					if (rc_dtag_update_en_oh[way_idx])
						line_states[rc_dtag_update_set] <= rc_dtag_update_state;
					
					// Fetch cache line state for pipeline
					if (memory_access_en && !is_io_address)
					begin
						if (rc_dtag_update_en_oh[way_idx] && rc_dtag_update_set == request_addr_nxt.set_idx)
							dt_state[way_idx] <= rc_dtag_update_state;	// Bypass
						else
							dt_state[way_idx] <= line_states[request_addr_nxt.set_idx];
					end

					// Fetch cache line state for snoop
					if (rc_snoop_en)
					begin
						if (rc_dtag_update_en_oh[way_idx] && rc_dtag_update_set == rc_snoop_set)
							dt_snoop_state[way_idx] <= rc_dtag_update_state;	// Bypass
						else
							dt_snoop_state[way_idx] <= line_states[rc_snoop_set];
					end
				end
			end
		end
	endgenerate

	// least-recently-used list for each cache set.  This is used to select which 
	// line to evict when necessary.
	//
	// This uses a pseudo-LRU algorithm
	// The current state of each set is represented by 3 bits.  Imagine a tree:
	//
	//        b
	//      /   \
	//     a     c
	//    / \   / \
	//   0   1 2   3
	//
	// The letters a, b, and c represent the 3 bits which indicate a path to the 
	// *least recently used* element. A 0 stored in a node indicates the left node 
	// and a 1 the right. Each time an element is moved to the MRU, the bits along 
	// its path are set to the opposite direction.
	sram_2r1w #(.DATA_WIDTH(3), .SIZE(`L1D_SETS)) lru_data(
		.read1_en(memory_access_en),
		.read1_addr(request_addr_nxt.set_idx),
		.read1_data(dt_lru_flags),
		.read2_en(rc_snoop_en),
		.read2_addr(rc_snoop_set),
		.read2_data(snoop_lru_flags),
		.write_en(dd_update_lru_en),
		.write_addr(dd_update_lru_set),
		.write_data(dd_update_lru_flags),
		.write_byte_en(0),	// Unused
		.*);
	
	always_comb
	begin
		casez (snoop_lru_flags)
			3'b00?: dt_snoop_lru = 0;
			3'b10?: dt_snoop_lru = 1;
			3'b?10: dt_snoop_lru = 2;
			3'b?11: dt_snoop_lru = 3;
		endcase
	end
	
	always_ff @(posedge clk, posedge reset)
	begin
		if (reset)
		begin
			/*AUTORESET*/
			// Beginning of autoreset for uninitialized flops
			dt_instruction <= 1'h0;
			dt_instruction_valid <= 1'h0;
			dt_mask_value <= {(1+(`VECTOR_LANES-1)){1'b0}};
			dt_request_addr <= 1'h0;
			dt_store_value <= 1'h0;
			dt_subcycle <= 1'h0;
			dt_thread_idx <= 1'h0;
			// End of automatics
		end
		else
		begin
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
