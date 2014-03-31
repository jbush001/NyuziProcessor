// 
// Copyright 2011-2012 Jeff Bush
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

`include "defines.v"

//
// Instruction pipeline memory access stage
// - Issue memory reads and writes to data cache
// - Aligns small write values correctly
// - Control register transfers are handled here.
//

module memory_access_stage
	#(parameter CORE_ID = 30'd0)

	(input                                  clk,
	input                                   reset,

	// From rollback controller
	input                                   rb_squash_ma,

	// Signals from execute stage
	input [31:0]                            ex_instruction,
	input [`STRAND_INDEX_WIDTH - 1:0]       ex_strand,
	input [`VECTOR_BITS - 1:0]              ex_store_value,
	input [`REG_IDX_WIDTH - 1:0]            ex_writeback_reg,
	input                                   ex_enable_scalar_writeback,	
	input                                   ex_enable_vector_writeback,	
	input [31:0]                            ex_pc,
	input [`VECTOR_LANES - 1:0]             ex_mask,
	input [`VECTOR_BITS - 1:0]              ex_result,
	input [3:0]                             ex_reg_lane_select,
	input [31:0]                            ex_strided_offset,
	input [31:0]                            ex_base_addr,

	// Signals to writeback stage
	output logic[`STRAND_INDEX_WIDTH - 1:0] ma_strand,
	output logic[31:0]                      ma_instruction,
	output logic[31:0]                      ma_pc,
	output logic[`REG_IDX_WIDTH - 1:0]      ma_writeback_reg,
	output logic                            ma_enable_scalar_writeback,	
	output logic                            ma_enable_vector_writeback,	
	output logic[`VECTOR_LANES - 1:0]       ma_mask,
	output logic [`VECTOR_BITS - 1:0]       ma_result,
	output logic[3:0]                       ma_reg_lane_select,
	output logic[3:0]                       ma_cache_lane_select,
	output logic                            ma_was_load,
	output logic[31:0]                      ma_strided_offset,
	output logic                            ma_alignment_fault,
	output logic                            ma_was_io,
	output logic[31:0]                      ma_io_response,

	// Signals to control registers
	output control_register_t               ma_cr_index,
	output                                  ma_cr_read_en,
	output                                  ma_cr_write_en,
	output[31:0]                            ma_cr_write_value,
	input[31:0]                             cr_read_value,
	
	// Memory mapped device IO
	output                                  io_write_en,
	output                                  io_read_en,
	output[31:0]                            io_address,
	output[31:0]                            io_write_data,
	input [31:0]                            io_read_data,
	
	// Signals to data cache/store buffer
	output logic[25:0]                      dcache_addr,
	output                                  dcache_req_sync,
	output [`STRAND_INDEX_WIDTH - 1:0]      dcache_req_strand,
	output logic [`CACHE_LINE_BITS - 1:0]   data_to_dcache,
	output                                  dcache_load,
	output                                  dcache_store,
	output                                  dcache_flush,
	output                                  dcache_stbar,
	output                                  dcache_dinvalidate,
	output                                  dcache_iinvalidate,
	output [`CACHE_LINE_BYTES - 1:0]        dcache_store_mask);
	
	logic[`VECTOR_BITS - 1:0] result_nxt;
	logic[3:0] byte_write_mask;
	logic[`VECTOR_LANES - 1:0] word_write_mask;
	logic[31:0] lane_value;
	logic[31:0] strided_ptr;
	logic[31:0] scatter_gather_ptr;
	logic[3:0] cache_lane_select_nxt;
	logic unaligned_memory_address;
	logic bad_io;
		
	wire is_fmt_c = ex_instruction[31:30] == 2'b10;	
	wire is_load = ex_instruction[29] == 1'b1;
	fmtc_op_t fmtc_op;
	assign fmtc_op = fmtc_op_t'(ex_instruction[28:25]);
	wire is_fmt_d = ex_instruction[31:28] == 4'b1110;
	fmtd_op_t fmtd_op;
	assign fmtd_op = fmtd_op_t'(ex_instruction[27:25]);
	assign dcache_req_strand = ex_strand;

	wire is_control_register_transfer = is_fmt_c && fmtc_op == MEM_CONTROL_REG;
	wire is_block_transfer = (fmtc_op == MEM_BLOCK || fmtc_op ==  MEM_BLOCK_M
		|| fmtc_op == MEM_BLOCK_IM);
	wire is_lane_masked = is_block_transfer 
		? ex_mask != 0 
		: (ex_mask & (1 << ex_reg_lane_select)) != 0;
	wire do_load_store = is_fmt_c && !is_control_register_transfer && !rb_squash_ma
		&& is_lane_masked && !unaligned_memory_address;
	wire bad_memory_access = is_fmt_c && !is_control_register_transfer && !rb_squash_ma
		&& (unaligned_memory_address || bad_io);

	wire is_io_address = &ex_result[31:16];
	assign io_write_data = ex_store_value[31:0];
	assign io_address = { 16'b0, ex_result[15:0] };
	assign io_write_en = do_load_store && !is_load && is_io_address;
	assign io_read_en = do_load_store && is_load && is_io_address;

	assign bad_io = is_io_address && fmtc_op != MEM_L;

	assign dcache_load = do_load_store && is_load && !is_io_address;
	assign dcache_store = do_load_store && !is_load && !is_io_address;
	assign dcache_flush = is_fmt_d && fmtd_op == CACHE_DFLUSH && !rb_squash_ma;
	assign dcache_stbar = is_fmt_d && fmtd_op == CACHE_STBAR && !rb_squash_ma;
	assign dcache_dinvalidate = is_fmt_d && fmtd_op == CACHE_DINVALIDATE && !rb_squash_ma;
	assign dcache_iinvalidate = is_fmt_d && fmtd_op == CACHE_IINVALIDATE && !rb_squash_ma;
	assign dcache_req_sync = fmtc_op == MEM_SYNC;

	assign ma_cr_read_en = is_control_register_transfer && is_load;
	assign ma_cr_write_en = is_control_register_transfer && !rb_squash_ma && !is_load;
	assign ma_cr_index = control_register_t'(ex_instruction[4:0]);
	assign ma_cr_write_value = ex_store_value[31:0];
	assign result_nxt = is_control_register_transfer ? cr_read_value : ex_result;

	// word_write_mask
	always_comb
	begin
		unique case (fmtc_op)
			MEM_BLOCK, MEM_BLOCK_M, MEM_BLOCK_IM:	// Block vector access
				word_write_mask = ex_mask;
			
			MEM_STRIDED, MEM_STRIDED_M, MEM_STRIDED_IM,	// Strided vector access 
			MEM_SCGATH, MEM_SCGATH_M, MEM_SCGATH_IM:	// Scatter/Gather access
			begin
				if (ex_mask & (1 << ex_reg_lane_select))
					word_write_mask = (1 << (`CACHE_LINE_WORDS - cache_lane_select_nxt - 1));
				else
					word_write_mask = 0;
			end

			default:	// Scalar access
				word_write_mask = 1 << (`CACHE_LINE_WORDS - cache_lane_select_nxt - 1);
		endcase
	end

	logic[`CACHE_LINE_BITS - 1:0] endian_twiddled_data;
	endian_swapper dcache_endian_swapper[`CACHE_LINE_WORDS - 1:0](
		.inval(ex_store_value),
		.endian_twiddled_data(endian_twiddled_data));

	multiplexer #(.WIDTH(32), .NUM_INPUTS(`VECTOR_LANES)) stval_mux(
		.in(ex_store_value),
		.out(lane_value),
		.select(ex_reg_lane_select));

	always_comb
	begin
		unique case (fmtc_op)
			MEM_B, MEM_BX: // Byte
				unaligned_memory_address = 0;

			MEM_S, MEM_SX: // 16 bits
				unaligned_memory_address = ex_result[0] != 0;	// Must be 2 byte aligned

			MEM_L, MEM_SYNC, MEM_CONTROL_REG, // 32 bits
			MEM_SCGATH, MEM_SCGATH_M, MEM_SCGATH_IM:
				unaligned_memory_address = ex_result[1:0] != 0; // Must be 4 byte aligned

			MEM_STRIDED, MEM_STRIDED_M, MEM_STRIDED_IM:	
				unaligned_memory_address = strided_ptr[1:0] != 0; // Must be 4 byte aligned

			default: // Vector
				// Must be vector width aligned
				unaligned_memory_address = ex_result[$clog2(`VECTOR_LANES * 4) - 1:0] != 0; 
		endcase
	end

	// byte_write_mask and data_to_dcache.
	always_comb
	begin
		unique case (fmtc_op)
			MEM_B, MEM_BX: // Byte
			begin
				unique case (ex_result[1:0])
					2'b00:
					begin
						byte_write_mask = 4'b1000;
						data_to_dcache = {`CACHE_LINE_WORDS{ex_store_value[7:0], 24'd0}};
					end

					2'b01:
					begin
						byte_write_mask = 4'b0100;
						data_to_dcache = {`CACHE_LINE_WORDS{8'd0, ex_store_value[7:0], 16'd0}};
					end

					2'b10:
					begin
						byte_write_mask = 4'b0010;
						data_to_dcache = {`CACHE_LINE_WORDS{16'd0, ex_store_value[7:0], 8'd0}};
					end

					2'b11:
					begin
						byte_write_mask = 4'b0001;
						data_to_dcache = {`CACHE_LINE_WORDS{24'd0, ex_store_value[7:0]}};
					end
				endcase
			end

			MEM_S, MEM_SX: // 16 bits
			begin
				if (ex_result[1] == 1'b0)
				begin
					byte_write_mask = 4'b1100;
					data_to_dcache = {`CACHE_LINE_WORDS{ex_store_value[7:0], ex_store_value[15:8], 16'd0}};
				end
				else
				begin
					byte_write_mask = 4'b0011;
					data_to_dcache = {`CACHE_LINE_WORDS{16'd0, ex_store_value[7:0], ex_store_value[15:8]}};
				end
			end

			MEM_L, MEM_SYNC, MEM_CONTROL_REG: // 32 bits
			begin
				byte_write_mask = 4'b1111;
				data_to_dcache = {`CACHE_LINE_WORDS{ex_store_value[7:0], ex_store_value[15:8], ex_store_value[23:16], 
					ex_store_value[31:24] }};
			end

			MEM_SCGATH, MEM_SCGATH_M, MEM_SCGATH_IM,	
			MEM_STRIDED, MEM_STRIDED_M, MEM_STRIDED_IM:
			begin
				byte_write_mask = 4'b1111;
				data_to_dcache = {`CACHE_LINE_WORDS{lane_value[7:0], lane_value[15:8], lane_value[23:16], 
					lane_value[31:24] }};
			end

			default: // Vector
			begin
				byte_write_mask = 4'b1111;
				data_to_dcache = endian_twiddled_data;
			end
		endcase
	end

	assign strided_ptr = ex_base_addr[31:0] + ex_strided_offset;
	multiplexer #(.WIDTH(32), .NUM_INPUTS(`VECTOR_LANES)) ptr_mux(
		.in(ex_result),
		.select(ex_reg_lane_select),
		.out(scatter_gather_ptr));

	// We issue the tag request in parallel with the memory access stage, so these
	// are not registered.
	always_comb
	begin
		unique case (fmtc_op)
			MEM_STRIDED, MEM_STRIDED_M, MEM_STRIDED_IM:	// Strided vector access 
			begin
				dcache_addr = strided_ptr[31:6];
				cache_lane_select_nxt = strided_ptr[5:2];
			end

			MEM_SCGATH, MEM_SCGATH_M, MEM_SCGATH_IM:	// Scatter/Gather access
			begin
				dcache_addr = scatter_gather_ptr[31:6];
				cache_lane_select_nxt = scatter_gather_ptr[5:2];
			end
		
			default: // Block vector access or Scalar transfer
			begin
				dcache_addr = ex_result[31:6];
				cache_lane_select_nxt = ex_result[5:2];
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
			assign dcache_store_mask[mask_idx] = word_write_mask[mask_idx / 4]
				& byte_write_mask[mask_idx & 3];
		end
	endgenerate

	always_ff @(posedge clk, posedge reset)
	begin
		if (reset)
		begin
			/*AUTORESET*/
			// Beginning of autoreset for uninitialized flops
			ma_alignment_fault <= 1'h0;
			ma_cache_lane_select <= 4'h0;
			ma_enable_scalar_writeback <= 1'h0;
			ma_enable_vector_writeback <= 1'h0;
			ma_instruction <= 32'h0;
			ma_io_response <= 32'h0;
			ma_mask <= {(1+(`VECTOR_LANES-1)){1'b0}};
			ma_pc <= 32'h0;
			ma_reg_lane_select <= 4'h0;
			ma_result <= {(1+(`VECTOR_BITS-1)){1'b0}};
			ma_strand <= {(1+(`STRAND_INDEX_WIDTH-1)){1'b0}};
			ma_strided_offset <= 32'h0;
			ma_was_io <= 1'h0;
			ma_was_load <= 1'h0;
			ma_writeback_reg <= {(1+(`REG_IDX_WIDTH-1)){1'b0}};
			// End of automatics
		end
		else
		begin
			assert($onehot0({dcache_load, dcache_store, dcache_flush, dcache_stbar}));

			ma_strand <= ex_strand;
			ma_writeback_reg <= ex_writeback_reg;
			ma_mask <= ex_mask;
			ma_result <= result_nxt;
			ma_reg_lane_select <= ex_reg_lane_select;
			ma_cache_lane_select <= cache_lane_select_nxt;
			ma_was_load <= dcache_load;
			ma_pc <= ex_pc;
			ma_strided_offset <= ex_strided_offset;
			ma_was_io <= is_io_address;
			ma_io_response <= io_read_data;

			if (rb_squash_ma)
			begin
				ma_instruction <= `NOP;
				ma_enable_scalar_writeback <= 0;	
				ma_enable_vector_writeback <= 0;
				ma_alignment_fault <= 0;
			end
			else
			begin	
				ma_instruction <= ex_instruction;
				ma_enable_scalar_writeback <= ex_enable_scalar_writeback;	
				ma_enable_vector_writeback <= ex_enable_vector_writeback;
				ma_alignment_fault <= bad_memory_access;
			end
		end
	end
endmodule

// Local Variables:
// verilog-typedef-regexp:"_t$"
// End:

