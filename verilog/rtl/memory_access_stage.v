//
// - Issue memory reads and writes to data cache
// - Aligns small write values correctly
// - Control register transfers are handled here.
//

`include "instruction_format.h"

module memory_access_stage
	#(parameter				CORE_ID = 30'd0)

	(input					clk,
	output reg [511:0]		data_to_dcache = 0,
	output 					dcache_write,
	output [63:0] 			write_mask_o,
	input [31:0]			instruction_i,
	output reg[31:0]		instruction_o = 0,
	input[1:0]				strand_i,
	output reg[1:0]			strand_o = 0,
	input					flush_i,
	input [31:0]			pc_i,
	output reg[31:0]		pc_o = 0,
	input[511:0]			store_value_i,
	input					has_writeback_i,
	input[6:0]				writeback_reg_i,
	input					writeback_is_vector_i,	
	output reg 				has_writeback_o = 0,
	output reg[6:0]			writeback_reg_o = 0,
	output reg				writeback_is_vector_o = 0,
	input [15:0]			mask_i,
	output reg[15:0]		mask_o = 0,
	input [511:0]			result_i,
	output reg [511:0]		result_o = 0,
	input [3:0]				reg_lane_select_i,
	output reg[3:0]			reg_lane_select_o = 0,
	output reg[3:0]			cache_lane_select_o = 0,
	output reg[3:0]			strand_enable_o = 4'b0001,
	output reg[31:0]		dcache_addr = 0,
	output reg				dcache_request = 0,
	output 					dcache_req_sync,
	output reg				was_access_o = 0,
	output [1:0]			dcache_req_strand,
	input [31:0]			strided_offset_i,
	output reg[31:0]		strided_offset_o = 0,
	input [31:0]			base_addr_i);
	
	reg[511:0]				result_nxt = 0;
	reg[31:0]				_test_cr7 = 0;
	reg[3:0]				byte_write_mask = 0;
	reg[15:0]				word_write_mask = 0;
	wire[31:0]				lane_value;
	wire[31:0]				strided_ptr;
	wire[31:0]				scatter_gather_ptr;
	reg[3:0]				cache_lane_select_nxt = 0;
	reg						unaligned_memory_address = 0;
	
	wire[3:0] c_op_type = instruction_i[28:25];
	wire is_fmt_c = instruction_i[31:30] == 2'b10;	
	assign dcache_req_strand = strand_i;

	wire is_control_register_transfer = instruction_i[31:30] == 2'b10
		&& c_op_type == `MEM_CONTROL_REG;

	assign dcache_write = instruction_i[31:29] == 3'b100 
		&& !is_control_register_transfer && !flush_i;

	// word_write_mask
	always @*
	begin
		case (c_op_type)
			`MEM_BLOCK, `MEM_BLOCK_M, `MEM_BLOCK_IM:	// Block vector access
				word_write_mask = mask_i;
			
			`MEM_STRIDED, `MEM_STRIDED_M, `MEM_STRIDED_IM,	// Strided vector access 
			`MEM_SCGATH, `MEM_SCGATH_M, `MEM_SCGATH_IM:	// Scatter/Gather access
			begin
				if (mask_i & (16'h8000 >> reg_lane_select_i))
					word_write_mask = (16'h8000 >> cache_lane_select_nxt);
				else
					word_write_mask = 0;
			end

			default:	// Scalar access
				word_write_mask = 16'h8000 >> cache_lane_select_nxt;
		endcase
	end

	wire[511:0] endian_twiddled_data = {
		store_value_i[487:480], store_value_i[495:488], store_value_i[503:496], store_value_i[511:504], 
		store_value_i[455:448], store_value_i[463:456], store_value_i[471:464], store_value_i[479:472], 
		store_value_i[423:416], store_value_i[431:424], store_value_i[439:432], store_value_i[447:440], 
		store_value_i[391:384], store_value_i[399:392], store_value_i[407:400], store_value_i[415:408], 
		store_value_i[359:352], store_value_i[367:360], store_value_i[375:368], store_value_i[383:376], 
		store_value_i[327:320], store_value_i[335:328], store_value_i[343:336], store_value_i[351:344], 
		store_value_i[295:288], store_value_i[303:296], store_value_i[311:304], store_value_i[319:312], 
		store_value_i[263:256], store_value_i[271:264], store_value_i[279:272], store_value_i[287:280], 
		store_value_i[231:224], store_value_i[239:232], store_value_i[247:240], store_value_i[255:248], 
		store_value_i[199:192], store_value_i[207:200], store_value_i[215:208], store_value_i[223:216], 
		store_value_i[167:160], store_value_i[175:168], store_value_i[183:176], store_value_i[191:184], 
		store_value_i[135:128], store_value_i[143:136], store_value_i[151:144], store_value_i[159:152], 
		store_value_i[103:96], store_value_i[111:104], store_value_i[119:112], store_value_i[127:120], 
		store_value_i[71:64], store_value_i[79:72], store_value_i[87:80], store_value_i[95:88], 
		store_value_i[39:32], store_value_i[47:40], store_value_i[55:48], store_value_i[63:56], 
		store_value_i[7:0], store_value_i[15:8], store_value_i[23:16], store_value_i[31:24] 	
	};

	lane_select_mux stval_mux(
		.value_i(store_value_i),
		.value_o(lane_value),
		.lane_select_i(reg_lane_select_i));


	always @*
	begin
		case (c_op_type)
			`MEM_B, `MEM_BX: // Byte
				unaligned_memory_address = 0;

			`MEM_S, `MEM_SX: // 16 bits
				unaligned_memory_address = result_i[0] != 0;	// Must be 2 byte aligned

			`MEM_L, `MEM_SYNC, `MEM_CONTROL_REG, // 32 bits
			`MEM_SCGATH, `MEM_SCGATH_M, `MEM_SCGATH_IM,	
			`MEM_STRIDED, `MEM_STRIDED_M, `MEM_STRIDED_IM:	
				unaligned_memory_address = result_i[1:0] != 0; // Must be 4 byte aligned

			default: // Vector
				unaligned_memory_address = result_i[5:0] != 0; // Must be 64 byte aligned
		endcase
	end

	// byte_write_mask and data_to_dcache.
	always @*
	begin
		case (c_op_type)
			`MEM_B, `MEM_BX: // Byte
			begin
				case (result_i[1:0])
					2'b00:
					begin
						byte_write_mask = 4'b1000;
						data_to_dcache = {16{ store_value_i[7:0], 24'd0 }};
					end

					2'b01:
					begin
						byte_write_mask = 4'b0100;
						data_to_dcache = {16{ 8'd0, store_value_i[7:0], 16'd0 }};
					end

					2'b10:
					begin
						byte_write_mask = 4'b0010;
						data_to_dcache = {16{ 16'd0, store_value_i[7:0], 8'd0 }};
					end

					2'b11:
					begin
						byte_write_mask = 4'b0001;
						data_to_dcache = {16{ 24'd0, store_value_i[7:0] }};
					end
				endcase
			end

			`MEM_S, `MEM_SX: // 16 bits
			begin
				if (result_i[1] == 1'b0)
				begin
					byte_write_mask = 4'b1100;
					data_to_dcache = {16{store_value_i[7:0], store_value_i[15:8], 16'd0 }};
				end
				else
				begin
					byte_write_mask = 4'b0011;
					data_to_dcache = {16{16'd0, store_value_i[7:0], store_value_i[15:8] }};
				end
			end

			`MEM_L, `MEM_SYNC, `MEM_CONTROL_REG: // 32 bits
			begin
				byte_write_mask = 4'b1111;
				data_to_dcache = {16{store_value_i[7:0], store_value_i[15:8], store_value_i[23:16], 
					store_value_i[31:24] }};
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

	assign strided_ptr = base_addr_i[31:0] + strided_offset_i;
	lane_select_mux ptr_mux(
		.value_i(result_i),
		.lane_select_i(reg_lane_select_i),
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
				dcache_addr = { result_i[31:6], 6'd0 };
				cache_lane_select_nxt = result_i[5:2];
			end
		endcase
	end

	always @*
	begin
		if (flush_i)
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
					&& (mask_i & (16'h8000 >> reg_lane_select_i)) != 0;
			end
		end
		else
			dcache_request = 0;
	end
	
	assign dcache_req_sync = c_op_type == `MEM_SYNC;
	
	assign write_mask_o = {
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
			if (instruction_i[4:0] == 0)	// Strand ID register
				result_nxt = { CORE_ID, strand_i };
			else if (instruction_i[4:0] == 7)
				result_nxt = _test_cr7;	
			else if (instruction_i[4:0] == 30)
				result_nxt = strand_enable_o;
			else
				result_nxt = 0;
		end
		else
			result_nxt = result_i;
	end

	// Transfer to control register
	always @(posedge clk)
	begin
		if (!flush_i && is_control_register_transfer && instruction_i[29] == 1'b0)
		begin
			if (instruction_i[4:0] == 7)
				_test_cr7 <= #1 store_value_i[31:0];
			else if (instruction_i[4:0] == 30)
				strand_enable_o <= #1 store_value_i[3:0];
			else if (instruction_i[4:0] == 31)
				strand_enable_o <= #1 0;	// HALT
		end
	end
	
	always @(posedge clk)
	begin
		strand_o					<= #1 strand_i;
		writeback_reg_o 			<= #1 writeback_reg_i;
		writeback_is_vector_o 		<= #1 writeback_is_vector_i;
		mask_o 						<= #1 mask_i;
		result_o 					<= #1 result_nxt;
		reg_lane_select_o			<= #1 reg_lane_select_i;
		cache_lane_select_o			<= #1 cache_lane_select_nxt;
		was_access_o				<= #1 dcache_request;
		pc_o						<= #1 pc_i;
		strided_offset_o			<= #1 strided_offset_i;

		if (flush_i)
		begin
			instruction_o 				<= #1 `NOP;
			has_writeback_o 			<= #1 0;
		end
		else
		begin	
			instruction_o 				<= #1 instruction_i;
			has_writeback_o 			<= #1 has_writeback_i;
		end
	end
	
	assertion #("Unaligned memory access") a0(clk, unaligned_memory_address
		&& dcache_request);
endmodule
