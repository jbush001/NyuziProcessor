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

module dcache_data_stage(
	input                                 clk,
	input                                 reset,
                                         
	// From dcache tag stage             
	input                                 dt_instruction_valid,
	input decoded_instruction_t           dt_instruction,
	input [`VECTOR_LANES - 1:0]           dt_mask_value,
	input thread_idx_t                    dt_thread_idx,
	input scalar_t                        dt_request_addr,
	input vector_t                        dt_store_value,
	input subcycle_t                      dt_subcycle,
                                         
	// To writeback stage                
	output                                dd_instruction_valid,
	output decoded_instruction_t          dd_instruction,
	output [`VECTOR_LANES - 1:0]          dd_mask_value,
	output thread_idx_t                   dd_thread_idx,
	output scalar_t                       dd_request_addr,
	output subcycle_t                     dd_subcycle,
                                         
	// From writeback stage              
	input logic                           wb_rollback_en,
	input thread_idx_t                    wb_rollback_thread_idx,
	input pipeline_sel_t                  wb_rollback_pipeline,
	                                     
	// XXX placeholder for simulation
	output scalar_t                       SIM_dcache_request_addr,
	output logic                          SIM_dcache_read_en,
	output logic                          SIM_dcache_write_en,
	output logic[`CACHE_LINE_BITS - 1:0]  SIM_dcache_write_data,
	output logic[`CACHE_LINE_BYTES - 1:0] SIM_dcache_write_mask);

	logic[`VECTOR_LANES - 1:0] word_write_mask;
	logic[3:0] byte_write_mask;
	logic[$clog2(`CACHE_LINE_WORDS):0] cache_lane_select_nxt;
	logic[`CACHE_LINE_BITS - 1:0] endian_twiddled_data;
	scalar_t lane_value;
	logic is_io_address;
	scalar_t scatter_gather_ptr;

	assign is_io_address = dt_request_addr[31:16] == 16'hffff;
	assign SIM_dcache_read_en = dt_instruction_valid && dt_instruction.is_memory_access 
		&& dt_instruction.is_load && !is_io_address;
	assign SIM_dcache_write_en = dt_instruction_valid && dt_instruction.is_memory_access 
		&& !dt_instruction.is_load && !is_io_address && dt_instruction.memory_access_type != MEM_CONTROL_REG;

	always_comb
	begin
		SIM_dcache_request_addr = 0;
		cache_lane_select_nxt = 0;
		
		unique case (dt_instruction.memory_access_type)
			MEM_STRIDED, MEM_STRIDED_M, MEM_STRIDED_IM:	// Strided vector access 
			begin
//				SIM_dcache_request_addr = strided_ptr[31:6];
//				cache_lane_select_nxt = strided_ptr[5:2];
			end

			MEM_SCGATH, MEM_SCGATH_M, MEM_SCGATH_IM:	// Scatter/Gather access
			begin
				SIM_dcache_request_addr = dt_request_addr[31:6];
				cache_lane_select_nxt = dt_request_addr[5:2];
			end
		
			default: // Block vector access or Scalar transfer
			begin
				SIM_dcache_request_addr = { dt_request_addr[31:`CACHE_LINE_OFFSET_BITS], {`CACHE_LINE_OFFSET_BITS{1'b0}} };
				cache_lane_select_nxt = dt_request_addr[`CACHE_LINE_OFFSET_BITS - 1:2];
			end
		endcase
	end

	// word_write_mask
	always_comb
	begin
		word_write_mask = 0;
		unique case (dt_instruction.memory_access_type)
			MEM_BLOCK, MEM_BLOCK_M, MEM_BLOCK_IM:	// Block vector access
				word_write_mask = dt_mask_value;
			
			MEM_STRIDED, MEM_STRIDED_M, MEM_STRIDED_IM,	// Strided vector access 
			MEM_SCGATH, MEM_SCGATH_M, MEM_SCGATH_IM:	// Scatter/Gather access
			begin
				if (dt_mask_value & (1 << dt_subcycle))
					word_write_mask = (1 << (`CACHE_LINE_WORDS - cache_lane_select_nxt - 1));
				else
					word_write_mask = 0;
			end

			default:	// Scalar access
				word_write_mask = 1 << (`CACHE_LINE_WORDS - cache_lane_select_nxt - 1);
		endcase
	end

	// Endian swap vector data
	genvar swap_word;
	generate
		for (swap_word = 0; swap_word < `CACHE_LINE_BYTES / 4; swap_word++)
		begin : swapper
			assign endian_twiddled_data[swap_word * 32+:8] = dt_store_value[swap_word][24+:8];
			assign endian_twiddled_data[swap_word * 32 + 8+:8] = dt_store_value[swap_word][16+:8];
			assign endian_twiddled_data[swap_word * 32 + 16+:8] = dt_store_value[swap_word][8+:8];
			assign endian_twiddled_data[swap_word * 32 + 24+:8] = dt_store_value[swap_word][0+:8];
		end
	endgenerate

	assign lane_value = dt_store_value[0];	// XXX for scatter gather, need a lane index

	// byte_write_mask and SIM_dcache_write_data.
	always_comb
	begin
		unique case (dt_instruction.memory_access_type)
			MEM_B, MEM_BX: // Byte
			begin
				unique case (dt_request_addr[1:0])
					2'b00:
					begin
						byte_write_mask = 4'b1000;
						SIM_dcache_write_data = {`CACHE_LINE_WORDS{dt_store_value[0][7:0], 24'd0}};
					end

					2'b01:
					begin
						byte_write_mask = 4'b0100;
						SIM_dcache_write_data = {`CACHE_LINE_WORDS{8'd0, dt_store_value[0][7:0], 16'd0}};
					end

					2'b10:
					begin
						byte_write_mask = 4'b0010;
						SIM_dcache_write_data = {`CACHE_LINE_WORDS{16'd0, dt_store_value[0][7:0], 8'd0}};
					end

					2'b11:
					begin
						byte_write_mask = 4'b0001;
						SIM_dcache_write_data = {`CACHE_LINE_WORDS{24'd0, dt_store_value[0][7:0]}};
					end
				endcase
			end

			MEM_S, MEM_SX: // 16 bits
			begin
				if (dt_request_addr[1] == 1'b0)
				begin
					byte_write_mask = 4'b1100;
					SIM_dcache_write_data = {`CACHE_LINE_WORDS{dt_store_value[0][7:0], dt_store_value[0][15:8], 16'd0}};
				end
				else
				begin
					byte_write_mask = 4'b0011;
					SIM_dcache_write_data = {`CACHE_LINE_WORDS{16'd0, dt_store_value[0][7:0], dt_store_value[0][15:8]}};
				end
			end

			MEM_L, MEM_SYNC: // 32 bits
			begin
				byte_write_mask = 4'b1111;
				SIM_dcache_write_data = {`CACHE_LINE_WORDS{dt_store_value[0][7:0], dt_store_value[0][15:8], 
					dt_store_value[0][23:16], dt_store_value[0][31:24] }};
			end

			MEM_SCGATH, MEM_SCGATH_M, MEM_SCGATH_IM,	
			MEM_STRIDED, MEM_STRIDED_M, MEM_STRIDED_IM:
			begin
				byte_write_mask = 4'b1111;
				SIM_dcache_write_data = {`CACHE_LINE_WORDS{lane_value[7:0], lane_value[15:8], lane_value[23:16], 
					lane_value[31:24] }};
			end

			default: // Vector
			begin
				byte_write_mask = 4'b1111;
				SIM_dcache_write_data = endian_twiddled_data;
			end
		endcase
	end

	// Generate store mask signals.  word_write_mask corresponds to lanes, byte_write_mask
	// corresponds to bytes within a word.  Note that byte_write_mask will always
	// have all bits set if word_write_mask has more than one bit set. That is:
	// we are either selecting some number of words within the cache line for
	// a vector transfer or some bytes within a specific word for a scalar transfer.
	genvar mask_idx;
	generate
		for (mask_idx = 0; mask_idx < `CACHE_LINE_BYTES; mask_idx++)
		begin : genmask
			assign SIM_dcache_write_mask[mask_idx] = word_write_mask[mask_idx / 4]
				& byte_write_mask[mask_idx & 3];
		end
	endgenerate
		
	always_ff @(posedge clk, posedge reset)
	begin
		if (reset)
		begin
			/*AUTORESET*/
			// Beginning of autoreset for uninitialized flops
			dd_instruction <= 1'h0;
			dd_instruction_valid <= 1'h0;
			dd_mask_value <= {(1+(`VECTOR_LANES-1)){1'b0}};
			dd_request_addr <= 1'h0;
			dd_subcycle <= 1'h0;
			dd_thread_idx <= 1'h0;
			// End of automatics
		end
		else
		begin
			dd_instruction_valid <= dt_instruction_valid && (!wb_rollback_en || wb_rollback_thread_idx != dt_thread_idx
				|| wb_rollback_pipeline != PIPE_MEM);
			dd_instruction <= dt_instruction;
			dd_mask_value <= dt_mask_value;
			dd_thread_idx <= dt_thread_idx;
			dd_request_addr <= dt_request_addr;
			dd_subcycle <= dt_subcycle;
			
			if (is_io_address && dt_instruction_valid && dt_instruction.is_memory_access && !dt_instruction.is_load)
				$write("%c", dt_store_value[0][7:0]);
		end
	end
endmodule

// Local Variables:
// verilog-typedef-regexp:"_t$"
// End:
