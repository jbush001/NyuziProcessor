//
// Writeback stage
//  - Handle aligning memory reads that are smaller than a word
//  - Determine what the source of the register writeback should be
//  - Control signals to control commit of values back to the register file
//

module writeback_stage(
	input					clk,
	input [31:0]			instruction_i,
	input [31:0]			pc_i,
	input [1:0]				strand_id_i,
	input [6:0]				writeback_reg_i,
	input					writeback_is_vector_i,	
	input	 				has_writeback_i,
	input [15:0]			mask_i,
	input 					cache_hit_i,
	output reg				writeback_is_vector_o = 0,	
	output reg				has_writeback_o = 0,
	output reg[6:0]			writeback_reg_o = 0,
	output reg[511:0]		writeback_value_o = 0,
	output reg[15:0]		mask_o = 0,
	input 					was_access_i,
	input [511:0]			ddata_i,
	input					dload_collision_i,
	input 					dstbuf_rollback_i,
	input [511:0]			result_i,
	input [3:0]				reg_lane_select_i,
	input [3:0]				cache_lane_select_i,
	output reg				rollback_request_o = 0,
	output reg[31:0]		rollback_address_o = 0,
	output 					suspend_request_o);

	reg[511:0]				writeback_value_nxt = 0;
	reg[15:0]				mask_nxt = 0;
	reg[31:0]				aligned_read_value = 0;
	reg[15:0]				half_aligned = 0;
	reg[7:0]				byte_aligned = 0;
	wire[31:0]				lane_value;

	wire is_control_register_transfer = instruction_i[31:30] == 2'b10
		&& instruction_i[28:25] == 4'b0110;
	wire is_load = instruction_i[31:30] == 2'b10 && instruction_i[29];
	wire[3:0] c_op_type = instruction_i[28:25];
	wire cache_miss = ~cache_hit_i && was_access_i && is_load && !dload_collision_i;

	always @*
	begin
		if (dload_collision_i)
		begin
			// Data came in one cycle too late.  Roll back and retry.
			rollback_address_o = pc_i - 4;
			rollback_request_o = 1;
		end
		else if (cache_miss || dstbuf_rollback_i)
		begin
			// Data cache read miss or store buffer rollback (full or synchronized store)
			rollback_address_o = pc_i - 4;
			rollback_request_o = 1;
		end
		else if (has_writeback_i && !writeback_is_vector_i
			&& writeback_reg_i[4:0] == 31 && is_load)
		begin
			// A load has occurred to PC, branch to that address
			// Note that we checked for a cache miss *before* we checked
			// this case, otherwise we'd just jump to address zero.
			rollback_address_o = aligned_read_value;
			rollback_request_o = 1;
		end
		else
		begin
			rollback_address_o = 0;
			rollback_request_o = 0;
		end
	end
	
	assign suspend_request_o = cache_miss || dstbuf_rollback_i;

	lane_select_mux lsm(
		.value_i(ddata_i),
		.value_o(lane_value),
		.lane_select_i(cache_lane_select_i));
	
	wire[511:0] endian_twiddled_data = {
		ddata_i[487:480], ddata_i[495:488], ddata_i[503:496], ddata_i[511:504], 
		ddata_i[455:448], ddata_i[463:456], ddata_i[471:464], ddata_i[479:472], 
		ddata_i[423:416], ddata_i[431:424], ddata_i[439:432], ddata_i[447:440], 
		ddata_i[391:384], ddata_i[399:392], ddata_i[407:400], ddata_i[415:408], 
		ddata_i[359:352], ddata_i[367:360], ddata_i[375:368], ddata_i[383:376], 
		ddata_i[327:320], ddata_i[335:328], ddata_i[343:336], ddata_i[351:344], 
		ddata_i[295:288], ddata_i[303:296], ddata_i[311:304], ddata_i[319:312], 
		ddata_i[263:256], ddata_i[271:264], ddata_i[279:272], ddata_i[287:280], 
		ddata_i[231:224], ddata_i[239:232], ddata_i[247:240], ddata_i[255:248], 
		ddata_i[199:192], ddata_i[207:200], ddata_i[215:208], ddata_i[223:216], 
		ddata_i[167:160], ddata_i[175:168], ddata_i[183:176], ddata_i[191:184], 
		ddata_i[135:128], ddata_i[143:136], ddata_i[151:144], ddata_i[159:152], 
		ddata_i[103:96], ddata_i[111:104], ddata_i[119:112], ddata_i[127:120], 
		ddata_i[71:64], ddata_i[79:72], ddata_i[87:80], ddata_i[95:88], 
		ddata_i[39:32], ddata_i[47:40], ddata_i[55:48], ddata_i[63:56], 
		ddata_i[7:0], ddata_i[15:8], ddata_i[23:16], ddata_i[31:24] 	
	};

	// Byte aligner.  result_i still contains the effective address,
	// so use that to determine where the data will appear.
	always @*
	begin
		case (result_i[1:0])
			2'b00: byte_aligned = lane_value[31:24];
			2'b01: byte_aligned = lane_value[23:16];
			2'b10: byte_aligned = lane_value[15:8];
			2'b11: byte_aligned = lane_value[7:0];
		endcase
	end

	// Halfword aligner.  Same as above.
	always @*
	begin
		case (result_i[1])
			1'b0: half_aligned = { lane_value[23:16], lane_value[31:24] };
			1'b1: half_aligned = { lane_value[7:0], lane_value[15:8] };
		endcase
	end

	// Pick the proper aligned result and sign extend as requested.
	always @*
	begin
		case (instruction_i[28:25])		// Load width
			// unsigned byte
			4'b0000: aligned_read_value = { 24'b0, byte_aligned };	

			// Signed byte
			4'b0001: aligned_read_value = { {24{byte_aligned[7]}}, byte_aligned }; 

			// Unsigned half-word
			4'b0010: aligned_read_value = { 16'b0, half_aligned };

			// Signed half-word
			4'b0011: aligned_read_value = { {16{half_aligned[15]}}, half_aligned };

			// Word (100) and others
			default: aligned_read_value = { lane_value[7:0], lane_value[15:8],
				lane_value[23:16], lane_value[31:24] };	
		endcase
	end

	always @*
	begin
		if (instruction_i[31:25] == 7'b1000101)
		begin
			// Synchronized store.  Success value comes back from cache
			writeback_value_nxt = ddata_i;
			mask_nxt = 16'hffff;
		end
		else if (is_load && !is_control_register_transfer)
		begin
			// Load result
			if (c_op_type[3] == 0 && c_op_type != 4'b0111)
			begin
				writeback_value_nxt = {16{aligned_read_value}}; // Scalar Load
				mask_nxt = 16'hffff;
			end
			else
			begin
				if (c_op_type == 4'b0111 || c_op_type == 4'b1000
					|| c_op_type == 4'b1001)
				begin
					// Block load
					mask_nxt = mask_i;	
					writeback_value_nxt = endian_twiddled_data;	// Vector Load
				end
				else 
				begin
					// Strided or gather load
					// Grab the appropriate lane.
					writeback_value_nxt = {16{aligned_read_value}};
					mask_nxt = (16'h8000 >> reg_lane_select_i) & mask_i;	// sg or strided
				end
			end
		end
		else
		begin
			// Arithmetic expression
			writeback_value_nxt = result_i;
			mask_nxt = mask_i;
		end
	end
	
	wire do_writeback = has_writeback_i && !rollback_request_o;

	always @(posedge clk)
	begin
		writeback_value_o 			<= #1 writeback_value_nxt;
		mask_o 						<= #1 mask_nxt;
		writeback_is_vector_o 		<= #1 writeback_is_vector_i;
		has_writeback_o 			<= #1 do_writeback;
		writeback_reg_o 			<= #1 writeback_reg_i;
	end
endmodule
