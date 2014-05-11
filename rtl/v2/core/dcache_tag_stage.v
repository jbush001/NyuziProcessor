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
	
	// From writeback stage                     
	input logic                                 wb_rollback_en,
	input thread_idx_t                          wb_rollback_thread_idx);

	l1d_addr_t request_addr_nxt;
	l1d_set_idx_t request_set;
	logic is_io_address;
	logic memory_access_en;

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
				.rd1_en(memory_access_en && !is_io_address),
				.rd1_addr(request_addr_nxt.set_idx),
				.rd1_data(dt_tag[way_idx]),
				.rd2_en(rc_snoop_en),
				.rd2_addr(rc_snoop_set),
				.rd2_data(dt_snoop_tag[way_idx]),
				.wr_en(rc_dtag_update_en_oh[way_idx]),
				.wr_addr(rc_dtag_update_set),
				.wr_data(rc_dtag_update_tag),
				.wr_byte_en(0),	// unused
				.*);

			always_ff @(posedge clk, posedge reset)
			begin
				if (reset)
				begin
					for (int set_idx = 0; set_idx < `L1D_SETS; set_idx++)
						line_states[set_idx] <= STATE_INVALID;
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
