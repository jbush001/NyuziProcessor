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

`include "instruction_format.h"

//
// CPU pipeline memory access stage
// - Issue memory reads and writes to data cache
// - Aligns small write values correctly
// - Control register transfers are handled here.
//

module memory_access_stage
	#(parameter				CORE_ID = 30'd0)

	(input					clk,
	input					reset,
	output reg [511:0]		data_to_dcache,
	output 					dcache_load,
	output 					dcache_store,
	output					dcache_flush,
	output					dcache_stbar,
	output [63:0] 			dcache_store_mask,
	input [31:0]			ex_instruction,
	output reg[31:0]		ma_instruction,
	input[1:0]				ex_strand,
	output reg[1:0]			ma_strand,
	input					squash_ma,
	input [31:0]			ex_pc,
	output reg[31:0]		ma_pc,
	input[511:0]			ex_store_value,
	input					ex_has_writeback,
	input[6:0]				ex_writeback_reg,
	input					ex_writeback_is_vector,	
	output reg 				ma_has_writeback,
	output reg[6:0]			ma_writeback_reg,
	output reg				ma_writeback_is_vector,
	input [15:0]			ex_mask,
	output reg[15:0]		ma_mask,
	input [511:0]			ex_result,
	output reg [511:0]		ma_result,
	input [3:0]				ex_reg_lane_select,
	output reg[3:0]			ma_reg_lane_select,
	output reg[3:0]			ma_cache_lane_select,
	output reg[31:0]		dcache_addr,
	output 					dcache_req_sync,
	output reg				ma_was_load,
	output [1:0]			dcache_req_strand,
	input [31:0]			ex_strided_offset,
	output reg[31:0]		ma_strided_offset,
	input [31:0]			ex_base_addr,
	output[4:0]				cr_index,
	output 					cr_read_en,
	output					cr_write_en,
	output[31:0]			cr_write_value,
	input[31:0]				cr_read_value);
	
	wire[511:0]				result_nxt;
	reg[3:0]				byte_write_mask;
	reg[15:0]				word_write_mask;
	wire[31:0]				lane_value;
	wire[31:0]				strided_ptr;
	wire[31:0]				scatter_gather_ptr;
	reg[3:0]				cache_lane_select_nxt;
	reg						unaligned_memory_address;
	
	wire is_fmt_c = ex_instruction[31:30] == 2'b10;	
	wire is_load = ex_instruction[29] == 1'b1;
	wire[3:0] c_op_type = ex_instruction[28:25];
	wire is_fmt_d = ex_instruction[31:28] == 4'b1110;
	wire[2:0] d_op_type = ex_instruction[27:25];
	assign dcache_req_strand = ex_strand;

	wire is_control_register_transfer = is_fmt_c && c_op_type == `MEM_CONTROL_REG;
	wire is_block_transfer = (c_op_type == `MEM_BLOCK || c_op_type ==  `MEM_BLOCK_M
		|| c_op_type == `MEM_BLOCK_IM);
	wire is_lane_masked = is_block_transfer 
		? ex_mask != 0 
		: (ex_mask & (1 << ex_reg_lane_select)) != 0;
	wire do_load_store = is_fmt_c && !is_control_register_transfer && !squash_ma
		&& is_lane_masked;

	assign dcache_load = do_load_store && is_load;
	assign dcache_store = do_load_store && !is_load;
	assign dcache_flush = is_fmt_d && d_op_type == `CACHE_DFLUSH && !squash_ma;
	assign dcache_stbar = is_fmt_d && d_op_type == `CACHE_STBAR && !squash_ma;
	assign dcache_req_sync = c_op_type == `MEM_SYNC;

	assert_false #("flush, store, and stbar are mutually exclusive, more than one specified") a1(
		.clk(clk), .test(dcache_load + dcache_store + dcache_flush + dcache_stbar > 1));

	assign cr_read_en = is_control_register_transfer && is_load;
	assign cr_write_en = is_control_register_transfer && !squash_ma && !is_load;
	assign cr_index = ex_instruction[4:0];
	assign cr_write_value = ex_store_value[31:0];
	assign result_nxt = is_control_register_transfer ? cr_read_value : ex_result;

	// word_write_mask
	always @*
	begin
		case (c_op_type)
			`MEM_BLOCK, `MEM_BLOCK_M, `MEM_BLOCK_IM:	// Block vector access
				word_write_mask = ex_mask;
			
			`MEM_STRIDED, `MEM_STRIDED_M, `MEM_STRIDED_IM,	// Strided vector access 
			`MEM_SCGATH, `MEM_SCGATH_M, `MEM_SCGATH_IM:	// Scatter/Gather access
			begin
				if (ex_mask & (1 << ex_reg_lane_select))
					word_write_mask = (16'h8000 >> cache_lane_select_nxt);
				else
					word_write_mask = 0;
			end

			default:	// Scalar access
				word_write_mask = 16'h8000 >> cache_lane_select_nxt;
		endcase
	end

	wire[511:0] endian_twiddled_data = {
		ex_store_value[487:480], ex_store_value[495:488], ex_store_value[503:496], ex_store_value[511:504], 
		ex_store_value[455:448], ex_store_value[463:456], ex_store_value[471:464], ex_store_value[479:472], 
		ex_store_value[423:416], ex_store_value[431:424], ex_store_value[439:432], ex_store_value[447:440], 
		ex_store_value[391:384], ex_store_value[399:392], ex_store_value[407:400], ex_store_value[415:408], 
		ex_store_value[359:352], ex_store_value[367:360], ex_store_value[375:368], ex_store_value[383:376], 
		ex_store_value[327:320], ex_store_value[335:328], ex_store_value[343:336], ex_store_value[351:344], 
		ex_store_value[295:288], ex_store_value[303:296], ex_store_value[311:304], ex_store_value[319:312], 
		ex_store_value[263:256], ex_store_value[271:264], ex_store_value[279:272], ex_store_value[287:280], 
		ex_store_value[231:224], ex_store_value[239:232], ex_store_value[247:240], ex_store_value[255:248], 
		ex_store_value[199:192], ex_store_value[207:200], ex_store_value[215:208], ex_store_value[223:216], 
		ex_store_value[167:160], ex_store_value[175:168], ex_store_value[183:176], ex_store_value[191:184], 
		ex_store_value[135:128], ex_store_value[143:136], ex_store_value[151:144], ex_store_value[159:152], 
		ex_store_value[103:96], ex_store_value[111:104], ex_store_value[119:112], ex_store_value[127:120], 
		ex_store_value[71:64], ex_store_value[79:72], ex_store_value[87:80], ex_store_value[95:88], 
		ex_store_value[39:32], ex_store_value[47:40], ex_store_value[55:48], ex_store_value[63:56], 
		ex_store_value[7:0], ex_store_value[15:8], ex_store_value[23:16], ex_store_value[31:24] 	
	};

	lane_select_mux stval_mux(
		.value_i(ex_store_value),
		.value_o(lane_value),
		.lane_select_i(ex_reg_lane_select));

	always @*
	begin
		case (c_op_type)
			`MEM_B, `MEM_BX: // Byte
				unaligned_memory_address = 0;

			`MEM_S, `MEM_SX: // 16 bits
				unaligned_memory_address = ex_result[0] != 0;	// Must be 2 byte aligned

			`MEM_L, `MEM_SYNC, `MEM_CONTROL_REG, // 32 bits
			`MEM_SCGATH, `MEM_SCGATH_M, `MEM_SCGATH_IM,	
			`MEM_STRIDED, `MEM_STRIDED_M, `MEM_STRIDED_IM:	
				unaligned_memory_address = ex_result[1:0] != 0; // Must be 4 byte aligned

			default: // Vector
				unaligned_memory_address = ex_result[5:0] != 0; // Must be 64 byte aligned
		endcase
	end

	// byte_write_mask and data_to_dcache.
	always @*
	begin
		case (c_op_type)
			`MEM_B, `MEM_BX: // Byte
			begin
				case (ex_result[1:0])
					2'b00:
					begin
						byte_write_mask = 4'b1000;
						data_to_dcache = {16{ ex_store_value[7:0], 24'd0 }};
					end

					2'b01:
					begin
						byte_write_mask = 4'b0100;
						data_to_dcache = {16{ 8'd0, ex_store_value[7:0], 16'd0 }};
					end

					2'b10:
					begin
						byte_write_mask = 4'b0010;
						data_to_dcache = {16{ 16'd0, ex_store_value[7:0], 8'd0 }};
					end

					2'b11:
					begin
						byte_write_mask = 4'b0001;
						data_to_dcache = {16{ 24'd0, ex_store_value[7:0] }};
					end
				endcase
			end

			`MEM_S, `MEM_SX: // 16 bits
			begin
				if (ex_result[1] == 1'b0)
				begin
					byte_write_mask = 4'b1100;
					data_to_dcache = {16{ex_store_value[7:0], ex_store_value[15:8], 16'd0 }};
				end
				else
				begin
					byte_write_mask = 4'b0011;
					data_to_dcache = {16{16'd0, ex_store_value[7:0], ex_store_value[15:8] }};
				end
			end

			`MEM_L, `MEM_SYNC, `MEM_CONTROL_REG: // 32 bits
			begin
				byte_write_mask = 4'b1111;
				data_to_dcache = {16{ex_store_value[7:0], ex_store_value[15:8], ex_store_value[23:16], 
					ex_store_value[31:24] }};
			end

			`MEM_SCGATH, `MEM_SCGATH_M, `MEM_SCGATH_IM,	
			`MEM_STRIDED, `MEM_STRIDED_M, `MEM_STRIDED_IM:
			begin
				byte_write_mask = 4'b1111;
				data_to_dcache = {16{lane_value[7:0], lane_value[15:8], lane_value[23:16], 
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
	lane_select_mux ptr_mux(
		.value_i(ex_result),
		.lane_select_i(ex_reg_lane_select),
		.value_o(scatter_gather_ptr));

	// We issue the tag request in parallel with the memory access stage, so these
	// are not registered.
	always @*
	begin
		case (c_op_type)
			`MEM_STRIDED, `MEM_STRIDED_M, `MEM_STRIDED_IM:	// Strided vector access 
			begin
				dcache_addr = { strided_ptr[31:6], 6'd0 };
				cache_lane_select_nxt = strided_ptr[5:2];
			end

			`MEM_SCGATH, `MEM_SCGATH_M, `MEM_SCGATH_IM:	// Scatter/Gather access
			begin
				dcache_addr = { scatter_gather_ptr[31:6], 6'd0 };
				cache_lane_select_nxt = scatter_gather_ptr[5:2];
			end
		
			default: // Block vector access or Scalar transfer
			begin
				dcache_addr = { ex_result[31:6], 6'd0 };
				cache_lane_select_nxt = ex_result[5:2];
			end
		endcase
	end
	
	assign dcache_store_mask = {
		word_write_mask[15] & byte_write_mask[3],
		word_write_mask[15] & byte_write_mask[2],
		word_write_mask[15] & byte_write_mask[1],
		word_write_mask[15] & byte_write_mask[0],
		word_write_mask[14] & byte_write_mask[3],
		word_write_mask[14] & byte_write_mask[2],
		word_write_mask[14] & byte_write_mask[1],
		word_write_mask[14] & byte_write_mask[0],
		word_write_mask[13] & byte_write_mask[3],
		word_write_mask[13] & byte_write_mask[2],
		word_write_mask[13] & byte_write_mask[1],
		word_write_mask[13] & byte_write_mask[0],
		word_write_mask[12] & byte_write_mask[3],
		word_write_mask[12] & byte_write_mask[2],
		word_write_mask[12] & byte_write_mask[1],
		word_write_mask[12] & byte_write_mask[0],
		word_write_mask[11] & byte_write_mask[3],
		word_write_mask[11] & byte_write_mask[2],
		word_write_mask[11] & byte_write_mask[1],
		word_write_mask[11] & byte_write_mask[0],
		word_write_mask[10] & byte_write_mask[3],
		word_write_mask[10] & byte_write_mask[2],
		word_write_mask[10] & byte_write_mask[1],
		word_write_mask[10] & byte_write_mask[0],
		word_write_mask[9] & byte_write_mask[3],
		word_write_mask[9] & byte_write_mask[2],
		word_write_mask[9] & byte_write_mask[1],
		word_write_mask[9] & byte_write_mask[0],
		word_write_mask[8] & byte_write_mask[3],
		word_write_mask[8] & byte_write_mask[2],
		word_write_mask[8] & byte_write_mask[1],
		word_write_mask[8] & byte_write_mask[0],
		word_write_mask[7] & byte_write_mask[3],
		word_write_mask[7] & byte_write_mask[2],
		word_write_mask[7] & byte_write_mask[1],
		word_write_mask[7] & byte_write_mask[0],
		word_write_mask[6] & byte_write_mask[3],
		word_write_mask[6] & byte_write_mask[2],
		word_write_mask[6] & byte_write_mask[1],
		word_write_mask[6] & byte_write_mask[0],
		word_write_mask[5] & byte_write_mask[3],
		word_write_mask[5] & byte_write_mask[2],
		word_write_mask[5] & byte_write_mask[1],
		word_write_mask[5] & byte_write_mask[0],
		word_write_mask[4] & byte_write_mask[3],
		word_write_mask[4] & byte_write_mask[2],
		word_write_mask[4] & byte_write_mask[1],
		word_write_mask[4] & byte_write_mask[0],
		word_write_mask[3] & byte_write_mask[3],
		word_write_mask[3] & byte_write_mask[2],
		word_write_mask[3] & byte_write_mask[1],
		word_write_mask[3] & byte_write_mask[0],
		word_write_mask[2] & byte_write_mask[3],
		word_write_mask[2] & byte_write_mask[2],
		word_write_mask[2] & byte_write_mask[1],
		word_write_mask[2] & byte_write_mask[0],
		word_write_mask[1] & byte_write_mask[3],
		word_write_mask[1] & byte_write_mask[2],
		word_write_mask[1] & byte_write_mask[1],
		word_write_mask[1] & byte_write_mask[0],
		word_write_mask[0] & byte_write_mask[3],
		word_write_mask[0] & byte_write_mask[2],
		word_write_mask[0] & byte_write_mask[1],
		word_write_mask[0] & byte_write_mask[0]
	};

	always @(posedge clk, posedge reset)
	begin
		if (reset)
		begin
			/*AUTORESET*/
			// Beginning of autoreset for uninitialized flops
			ma_cache_lane_select <= 4'h0;
			ma_has_writeback <= 1'h0;
			ma_instruction <= 32'h0;
			ma_mask <= 16'h0;
			ma_pc <= 32'h0;
			ma_reg_lane_select <= 4'h0;
			ma_result <= 512'h0;
			ma_strand <= 2'h0;
			ma_strided_offset <= 32'h0;
			ma_was_load <= 1'h0;
			ma_writeback_is_vector <= 1'h0;
			ma_writeback_reg <= 7'h0;
			// End of automatics
		end
		else
		begin
			ma_strand					<= ex_strand;
			ma_writeback_reg 			<= ex_writeback_reg;
			ma_writeback_is_vector 		<= ex_writeback_is_vector;
			ma_mask 					<= ex_mask;
			ma_result 					<= result_nxt;
			ma_reg_lane_select			<= ex_reg_lane_select;
			ma_cache_lane_select		<= cache_lane_select_nxt;
			ma_was_load					<= dcache_load;
			ma_pc						<= ex_pc;
			ma_strided_offset			<= ex_strided_offset;

			if (squash_ma)
			begin
				ma_instruction 			<= `NOP;
				ma_has_writeback 		<= 0;
			end
			else
			begin	
				ma_instruction 			<= ex_instruction;
				ma_has_writeback 		<= ex_has_writeback;
			end
		end
	end
	
	// synthesis translate_off
	always @(posedge clk)
	begin
		if (unaligned_memory_address && (dcache_load || dcache_store))
		begin
			$display("FAULT: PC %08x accessed bad memory address %08x\n",
				ex_pc, ex_result[31:0]);
			$finish;
		end
	end
	// synthesis translate_on
endmodule
