//
// CPU pipeline memory access stage
// - Issue memory reads and writes to data cache
// - Aligns small write values correctly
// - Control register transfers are handled here.
//

`include "instruction_format.h"

module memory_access_stage
	#(parameter				CORE_ID = 30'd0)

	(input					clk,
	output reg [511:0]		data_to_dcache = 0,
	output 					dcache_store,
	output					dcache_flush,
	output [63:0] 			dcache_store_mask,
	input [31:0]			ex_instruction,
	output reg[31:0]		ma_instruction = 0,
	input[1:0]				ex_strand,
	output reg[1:0]			ma_strand = 0,
	input					flush_ma,
	input [31:0]			ex_pc,
	output reg[31:0]		ma_pc = 0,
	input[511:0]			ex_store_value,
	input					ex_has_writeback,
	input[6:0]				ex_writeback_reg,
	input					ex_writeback_is_vector,	
	output reg 				ma_has_writeback = 0,
	output reg[6:0]			ma_writeback_reg = 0,
	output reg				ma_writeback_is_vector = 0,
	input [15:0]			ex_mask,
	output reg[15:0]		ma_mask = 0,
	input [511:0]			ex_result,
	output reg [511:0]		ma_result = 0,
	input [3:0]				ex_reg_lane_select,
	output reg[3:0]			ma_reg_lane_select = 0,
	output reg[3:0]			ma_cache_lane_select = 0,
	output reg[3:0]			ma_strand_enable = 4'b0001,
	output reg[31:0]		dcache_addr = 0,
	output reg				dcache_request = 0,
	output 					dcache_req_sync,
	output reg				ma_was_access = 0,
	output [1:0]			dcache_req_strand,
	input [31:0]			ex_strided_offset,
	output reg[31:0]		ma_strided_offset = 0,
	input [31:0]			ex_base_addr);
	
	reg[511:0]				result_nxt = 0;
	reg[31:0]				_test_cr7 = 0;
	reg[3:0]				byte_write_mask = 0;
	reg[15:0]				word_write_mask = 0;
	wire[31:0]				lane_value;
	wire[31:0]				strided_ptr;
	wire[31:0]				scatter_gather_ptr;
	reg[3:0]				cache_lane_select_nxt = 0;
	reg						unaligned_memory_address = 0;
	
	wire[3:0] c_op_type = ex_instruction[28:25];
	wire is_fmt_c = ex_instruction[31:30] == 2'b10;	
	assign dcache_req_strand = ex_strand;

	wire is_control_register_transfer = ex_instruction[31:30] == 2'b10
		&& c_op_type == `MEM_CONTROL_REG;

	assign dcache_store = ex_instruction[31:29] == 3'b100 
		&& !is_control_register_transfer && !flush_ma;
	assign dcache_flush = ex_instruction[31:25] == 7'b1110_010
		&& !flush_ma;

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

	always @*
	begin
		if (flush_ma)
			dcache_request = 0;
		else if (is_fmt_c)
		begin
			// Note that we check the mask bit for this lane.
			if (c_op_type == `MEM_BLOCK || c_op_type ==  `MEM_BLOCK_M
				|| c_op_type == `MEM_BLOCK_IM)
			begin
				dcache_request = 1;		
			end
			else
			begin
				dcache_request = !is_control_register_transfer
					&& (ex_mask & (1 << ex_reg_lane_select)) != 0;
			end
		end
		else
			dcache_request = 0;
	end
	
	assign dcache_req_sync = c_op_type == `MEM_SYNC;
	
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
	
	// Transfer from control register
	always @*
	begin
		if (is_control_register_transfer)
		begin
			if (ex_instruction[4:0] == 0)	// Strand ID register
				result_nxt = { CORE_ID, ex_strand };
			else if (ex_instruction[4:0] == 7)
				result_nxt = _test_cr7;	
			else if (ex_instruction[4:0] == 30)
				result_nxt = ma_strand_enable;
			else
				result_nxt = 0;
		end
		else
			result_nxt = ex_result;
	end

	// Transfer to control register
	always @(posedge clk)
	begin
		if (!flush_ma && is_control_register_transfer && ex_instruction[29] == 1'b0)
		begin
			if (ex_instruction[4:0] == 7)
				_test_cr7 <= #1 ex_store_value[31:0];
			else if (ex_instruction[4:0] == 30)
				ma_strand_enable <= #1 ex_store_value[3:0];
			else if (ex_instruction[4:0] == 31)
				ma_strand_enable <= #1 0;	// HALT
		end
	end
	
	always @(posedge clk)
	begin
		ma_strand					<= #1 ex_strand;
		ma_writeback_reg 			<= #1 ex_writeback_reg;
		ma_writeback_is_vector 		<= #1 ex_writeback_is_vector;
		ma_mask 					<= #1 ex_mask;
		ma_result 					<= #1 result_nxt;
		ma_reg_lane_select			<= #1 ex_reg_lane_select;
		ma_cache_lane_select		<= #1 cache_lane_select_nxt;
		ma_was_access				<= #1 dcache_request;
		ma_pc						<= #1 ex_pc;
		ma_strided_offset			<= #1 ex_strided_offset;

		if (flush_ma)
		begin
			ma_instruction 			<= #1 `NOP;
			ma_has_writeback 		<= #1 0;
		end
		else
		begin	
			ma_instruction 			<= #1 ex_instruction;
			ma_has_writeback 		<= #1 ex_has_writeback;
		end
	end
	
	assertion #("Unaligned memory access") a0(clk, unaligned_memory_address
		&& dcache_request);
endmodule
