//
// - Performs arithmetic operations
// - Detects conditional branches and resolves them
// - Issues address to data cache for tag check
// - Handles bypassing of register results that have not been committed
//     to register file.
//

module execute_stage(
	input					clk,
	input [31:0]			instruction_i,
	output reg[31:0]		instruction_o,
	input [31:0]			pc_i,
	output reg[31:0]		pc_o,
	input [31:0] 			scalar_value1_i,
	input [4:0]				scalar_sel1_i,
	input [31:0] 			scalar_value2_i,
	input [4:0]				scalar_sel2_i,
	input [511:0] 			vector_value1_i,
	input [4:0]				vector_sel1_i,
	input [511:0] 			vector_value2_i,
	input [4:0]				vector_sel2_i,
	input [31:0] 			immediate_i,
	input [2:0] 			mask_src_i,
	input 					op1_is_vector_i,
	input [1:0] 			op2_src_i,
	input					store_value_is_vector_i,
	output reg[511:0]		store_value_o,
	input	 				has_writeback_i,
	input [4:0]				writeback_reg_i,
	input					writeback_is_vector_i,	
	output reg 				has_writeback_o,
	output reg[4:0]			writeback_reg_o,
	output reg				writeback_is_vector_o,
	output reg[15:0]		mask_o,
	output reg[511:0]		result_o,
	input [5:0]				alu_op_i,
	output reg[31:0]		daddress_o,
	output reg				daccess_o,
	input [3:0]				reg_lane_select_i,
	output reg[3:0]			reg_lane_select_o,
	input [4:0]				bypass1_register,		// mem access stage
	input					bypass1_has_writeback,
	input					bypass1_is_vector,
	input [511:0]			bypass1_value,
	input [15:0]			bypass1_mask,
	input [4:0]				bypass2_register,		// writeback stage
	input					bypass2_has_writeback,
	input					bypass2_is_vector,
	input [511:0]			bypass2_value,
	input [15:0]			bypass2_mask,
	input [4:0]				bypass3_register,		// post writeback
	input					bypass3_has_writeback,
	input					bypass3_is_vector,
	input [511:0]			bypass3_value,
	input [15:0]			bypass3_mask,
	output reg				rollback_request_o,
	output reg[31:0]		rollback_address_o,
	input					flush_i,
	output reg[3:0]			cache_lane_select_o,
	input [31:0]			strided_offset_i,
	output reg [31:0]		strided_offset_o,
	output reg				was_access_o);
	
	reg[511:0]				op1;
	reg[511:0] 				op2;
	wire[511:0] 			single_cycle_result;
	wire[511:0]				multi_cycle_result;
	reg[511:0]				store_value_nxt;
	reg[15:0]				mask_val;
	wire[511:0]				vector_value1_bypassed;
	wire[511:0] 			vector_value2_bypassed;
	reg[31:0] 				scalar_value1_bypassed;
	reg[31:0] 				scalar_value2_bypassed;
	wire[3:0]				c_op_type;
	wire					is_fmt_c;
	wire					is_multi_cycle_latency;
	reg[31:0]				instruction_nxt;
	reg		 				has_writeback_nxt;
	reg[4:0]				writeback_reg_nxt;
	reg						writeback_is_vector_nxt;
	reg[31:0]				pc_nxt;
	reg[511:0]				result_nxt;
	reg[15:0]				mask_nxt;

	// Track instructions with multi-cycle latency.
	reg[31:0]				instruction1;
	reg[31:0]				pc1;
	reg		 				has_writeback1;
	reg[4:0]				writeback_reg1;
	reg						writeback_is_vector1;	
	reg[15:0]				mask1;
	reg[31:0]				instruction2;
	reg[31:0]				pc2;
	reg		 				has_writeback2;
	reg[4:0]				writeback_reg2;
	reg						writeback_is_vector2;	
	reg[15:0]				mask2;
	reg[31:0]				instruction3;
	reg[31:0]				pc3;
	reg		 				has_writeback3;
	reg[4:0]				writeback_reg3;
	reg						writeback_is_vector3;	
	reg[15:0]				mask3;
	wire					is_control_register_transfer;
	wire					is_fmt_a;
	wire					is_fmt_b;
	wire[31:0]				strided_ptr;
	wire[31:0]				scatter_gather_ptr;
	reg[3:0]				cache_lane_select_nxt;
	wire					is_call;
	
	initial
	begin
		instruction_o = 0;
		pc_o = 0;
		store_value_o = 0;
		has_writeback_o = 0;
		writeback_reg_o = 0;
		writeback_is_vector_o = 0;
		mask_o = 0;
		result_o = 0;
		daddress_o = 0;
		daccess_o = 0;
		reg_lane_select_o = 0;
		rollback_request_o = 0;
		rollback_address_o = 0;
		cache_lane_select_o = 0;
		was_access_o = 0;
		op1 = 0;
		op2 = 0;
		store_value_nxt = 0;
		mask_val = 0;
		scalar_value1_bypassed = 0;
		scalar_value2_bypassed = 0;
		instruction_nxt = 0;
		has_writeback_nxt = 0;
		writeback_reg_nxt = 0;
		writeback_is_vector_nxt = 0;
		pc_nxt = 0;
		result_nxt = 0;
		mask_nxt = 0;
		instruction1 = 0;
		pc1 = 0;
		has_writeback1 = 0;
		writeback_reg1 = 0;
		writeback_is_vector1 = 0;
		mask1 = 0;
		instruction2 = 0;
		pc2 = 0;
		has_writeback2 = 0;
		writeback_reg2 = 0;
		writeback_is_vector2 = 0;
		mask2 = 0;
		instruction3 = 0;
		pc3 = 0;
		has_writeback3 = 0;
		writeback_reg3 = 0;
		writeback_is_vector3 = 0;
		mask3 = 0;
		cache_lane_select_nxt = 0;
		strided_offset_o = 0;
	end

	// Note: is_multi_cycle_latency must match the result computed in
	// strand select stage.
	assign is_fmt_a = instruction_i[31:29] == 3'b110;	
	assign is_fmt_b = instruction_i[31] == 1'b0;
	assign is_fmt_c = instruction_i[31:30] == 2'b10;	
	assign is_multi_cycle_latency = (is_fmt_a && instruction_i[28] == 1)
		|| (is_fmt_a && instruction_i[28:23] == 6'b000111)	// Integer multiply
		|| (is_fmt_b && instruction_i[30:26] == 5'b00111);	// Integer multiply
	assign is_control_register_transfer = c_op_type == 4'b0110;
	assign is_call = instruction_i[31:25] == 7'b1111100;

	// scalar_value1_bypassed
	always @*
	begin
		if (scalar_sel1_i == 31)
			scalar_value1_bypassed = pc_i;
		else if (scalar_sel1_i == writeback_reg_o && has_writeback_o
			&& !writeback_is_vector_o)
			scalar_value1_bypassed = result_o[31:0];
		else if (scalar_sel1_i == bypass1_register && bypass1_has_writeback
			&& !bypass1_is_vector)
			scalar_value1_bypassed = bypass1_value[31:0];
		else if (scalar_sel1_i == bypass2_register && bypass2_has_writeback
			&& !bypass2_is_vector)
			scalar_value1_bypassed = bypass2_value[31:0];
		else if (scalar_sel1_i == bypass3_register && bypass3_has_writeback
			&& !bypass3_is_vector)
			scalar_value1_bypassed = bypass3_value[31:0];
		else 
			scalar_value1_bypassed = scalar_value1_i;	
	end

	always @*
	begin
		if (scalar_sel2_i == 31)
			scalar_value2_bypassed = pc_i;
		else if (scalar_sel2_i == writeback_reg_o && has_writeback_o
			&& !writeback_is_vector_o)
			scalar_value2_bypassed = result_o[31:0];
		else if (scalar_sel2_i == bypass1_register && bypass1_has_writeback
			&& !bypass1_is_vector)
			scalar_value2_bypassed = bypass1_value[31:0];
		else if (scalar_sel2_i == bypass2_register && bypass2_has_writeback
			&& !bypass2_is_vector)
			scalar_value2_bypassed = bypass2_value[31:0];
		else if (scalar_sel2_i == bypass3_register && bypass3_has_writeback
			&& !bypass3_is_vector)
			scalar_value2_bypassed = bypass3_value[31:0];
		else 
			scalar_value2_bypassed = scalar_value2_i;	
	end

	// vector_value1_bypassed
	vector_bypass_unit vbu1(
		.register_sel_i(vector_sel1_i), 
		.data_i(vector_value1_i),	
		.value_o(vector_value1_bypassed),
		.bypass1_register_i(writeback_reg_o),	
		.bypass1_write_i(has_writeback_o && writeback_is_vector_o),
		.bypass1_value_i(result_o),
		.bypass1_mask_i(mask_o),
		.bypass2_register_i(bypass1_register),	
		.bypass2_write_i(bypass1_has_writeback && bypass1_is_vector),
		.bypass2_value_i(bypass1_value),
		.bypass2_mask_i(bypass1_mask),
		.bypass3_register_i(bypass2_register),	
		.bypass3_write_i(bypass2_has_writeback && bypass2_is_vector),
		.bypass3_value_i(bypass2_value),
		.bypass3_mask_i(bypass2_mask),
		.bypass4_register_i(bypass3_register),	
		.bypass4_write_i(bypass3_has_writeback && bypass3_is_vector),
		.bypass4_value_i(bypass3_value),
		.bypass4_mask_i(bypass3_mask));

	// vector_value2_bypassed
	vector_bypass_unit vbu2(
		.register_sel_i(vector_sel2_i), 
		.data_i(vector_value2_i),	
		.value_o(vector_value2_bypassed),
		.bypass1_register_i(writeback_reg_o),	
		.bypass1_write_i(has_writeback_o && writeback_is_vector_o),
		.bypass1_value_i(result_o),
		.bypass1_mask_i(mask_o),
		.bypass2_register_i(bypass1_register),	
		.bypass2_write_i(bypass1_has_writeback && bypass1_is_vector),
		.bypass2_value_i(bypass1_value),
		.bypass2_mask_i(bypass1_mask),
		.bypass3_register_i(bypass2_register),	
		.bypass3_write_i(bypass2_has_writeback && bypass2_is_vector),
		.bypass3_value_i(bypass2_value),
		.bypass3_mask_i(bypass2_mask),
		.bypass4_register_i(bypass3_register),	
		.bypass4_write_i(bypass3_has_writeback && bypass3_is_vector),
		.bypass4_value_i(bypass3_value),
		.bypass4_mask_i(bypass3_mask));

	// op1
	always @*
	begin
		if (op1_is_vector_i)
			op1 = vector_value1_bypassed;
		else
			op1 = {16{scalar_value1_bypassed}};
	end

	// op2
	always @*
	begin
		case (op2_src_i)
			2'b00: op2 = {16{scalar_value2_bypassed}};
			2'b01: op2 = vector_value2_bypassed;
			2'b10: op2 = {16{immediate_i}};
			default: op2 = 0;
		endcase
	end
	
	// mask
	always @*
	begin
		case (mask_src_i)
			3'b000:	mask_val = scalar_value1_bypassed[15:0];
			3'b001:	mask_val = ~scalar_value1_bypassed[15:0];
			3'b010:	mask_val = scalar_value2_bypassed[15:0];
			3'b011:	mask_val = ~scalar_value2_bypassed[15:0];
			3'b100: mask_val = 16'hffff;
			default: mask_val = 16'hffff;
		endcase
	end
	
	// store_value_nxt
	always @*
	begin
		if (store_value_is_vector_i)
			store_value_nxt = vector_value2_bypassed;
		else
			store_value_nxt = { {15{32'd0}}, scalar_value2_bypassed };
	end	

	single_cycle_alu salu(
		.operation_i(alu_op_i),
		.operand1_i(op1),
		.operand2_i(op2),
		.result_o(single_cycle_result));
		
	multi_cycle_vector_alu malu(
		.clk(clk),
		.operation_i(alu_op_i),
		.operand1_i(op1),
		.operand2_i(op2),
		.result_o(multi_cycle_result));

	assign c_op_type = instruction_i[28:25];

	// Note that we use op1 as the base instead of single_cycle_result,
	// since the immediate value is not applied to the base pointer.
	assign strided_ptr = op1[31:0] + strided_offset_i;
	lane_select_mux lsm(
		.value_i(single_cycle_result),
		.lane_select_i(reg_lane_select_i),
		.value_o(scatter_gather_ptr));
	
	// We issue the tag request in parallel with the execute stage, so these
	// are not registered.
	always @*
	begin
		case (c_op_type)
			4'b1010, 4'b1011, 4'b1100:	// Strided vector access 
			begin
				daddress_o = { strided_ptr[31:6], 6'd0 };
				cache_lane_select_nxt = strided_ptr[5:2];
			end

			4'b1101, 4'b1110, 4'b1111:	// Scatter/Gather access
			begin
				daddress_o = { scatter_gather_ptr[31:6], 6'd0 };
				cache_lane_select_nxt = scatter_gather_ptr[5:2];
			end
		
			default: // Block vector access or Scalar transfer
			begin
				daddress_o = { single_cycle_result[31:6], 6'd0 };
				cache_lane_select_nxt = single_cycle_result[5:2];
			end
		endcase
	end
		
	always @*
	begin
		if (flush_i)
			daccess_o = 0;
		else if (is_fmt_c)
		begin
			// Note that we check the mask bit for this lane.
			if (c_op_type == 4'b0111 || c_op_type ==  4'b1000
				|| c_op_type == 4'b1001)
			begin
				daccess_o = 1;		
			end
			else
			begin
				daccess_o = !is_control_register_transfer
					&& (mask_val & (16'h8000 >> reg_lane_select_i)) != 0;
			end
		end
		else
			daccess_o =0;
	end
	
	// Branch control
	always @*
	begin
		if (!is_fmt_c && has_writeback_i && writeback_reg_i == 31
			&& !writeback_is_vector_i)
		begin
			// Arithmetic operation with PC destination, interpret as a branch
			// Can't do this with a memory load in this stage, because the
			// result isn't available yet.
			rollback_request_o = 1;
			rollback_address_o = single_cycle_result[31:0];
		end
		else if (instruction_i[31:28] == 4'b1111)
		begin
			case (instruction_i[27:25])
				3'b000: rollback_request_o = op1[15:0] == 16'hffff;	// ball
				3'b001: rollback_request_o = op1[31:0] == 32'd0; // bzero
				3'b010: rollback_request_o = op1[31:0] != 32'd0; // bnzero
				3'b011: rollback_request_o = 1; // goto
				3'b100: rollback_request_o = 1; // call 
				default: rollback_request_o = 1;// don't care
			endcase
			
			rollback_address_o = pc_i + { {12{instruction_i[24]}}, instruction_i[24:5] };
		end
		else
		begin
			rollback_request_o = 0;
			rollback_address_o = 0;
		end
	end

	// Track multi-cycle instructions
	always @(posedge clk)
	begin
		if (is_multi_cycle_latency)
		begin
			instruction1 			<= #1 instruction_i;
			pc1 					<= #1 pc_i;
			has_writeback1 			<= #1 has_writeback_i;
			writeback_reg1 			<= #1 writeback_reg_i;
			writeback_is_vector1 	<= #1 writeback_is_vector_i;
			mask1 					<= #1 mask_val;
		end
		else
		begin
			// Single cycle latency
			instruction1 			<= #1 32'd0;
			pc1 					<= #1 32'd0;
			has_writeback1  		<= #1 1'd0;
			writeback_reg1 			<= #1 5'd0;
			writeback_is_vector1 	<= #1 1'd0;
			mask1 					<= #1 0;
		end
		
		instruction2 				<= #1 instruction1;
		pc2 						<= #1 pc1;
		has_writeback2 				<= #1 has_writeback1;
		writeback_reg2 				<= #1 writeback_reg1;
		writeback_is_vector2		<= #1 writeback_is_vector1;
		mask2 						<= #1 mask1;

		instruction3 				<= #1 instruction2;
		pc3							<= #1 pc2;
		has_writeback3 				<= #1 has_writeback2;
		writeback_reg3 				<= #1 writeback_reg2;
		writeback_is_vector3		<= #1 writeback_is_vector2;
		mask3 						<= #1 mask2;
	end

	// This is the place where pipelines of different lengths merge. There
	// is a structural hazard here, as two instructions can arrive at the
	// same time.  We don't attempt to resolve that here: the strand scheduler
	// will do that.
	always @*
	begin
		if (instruction3 != 0)	// If instruction2 is not NOP
		begin
			// Multi-cycle result
			instruction_nxt = instruction3;
			writeback_reg_nxt = writeback_reg3;
			writeback_is_vector_nxt = writeback_is_vector3;
			has_writeback_nxt = has_writeback3;
			pc_nxt = pc3;
			mask_nxt = mask3;
			if (instruction3[28:23] == 6'b101100
				|| instruction3[28:23] == 6'b101101
				|| instruction3[28:23] == 6'b101110
				|| instruction3[28:23] == 6'b101111)
			begin
				// This is a comparison.  Coalesce the results.
				result_nxt = { multi_cycle_result[480],
					multi_cycle_result[448],
					multi_cycle_result[416],
					multi_cycle_result[384],
					multi_cycle_result[352],
					multi_cycle_result[320],
					multi_cycle_result[288],
					multi_cycle_result[256],
					multi_cycle_result[224],
					multi_cycle_result[192],
					multi_cycle_result[160],
					multi_cycle_result[128],
					multi_cycle_result[96],
					multi_cycle_result[64],
					multi_cycle_result[32],
					multi_cycle_result[0] };
			end
			else
				result_nxt = multi_cycle_result;
		end
		else
		begin
			// Single cycle result
			instruction_nxt = instruction_i;
			writeback_reg_nxt = writeback_reg_i;
			writeback_is_vector_nxt = writeback_is_vector_i;
			has_writeback_nxt = has_writeback_i;
			pc_nxt = pc_i;
			mask_nxt = mask_val;
			if (is_call)
				result_nxt = { 480'd0, pc_i };
			else
				result_nxt = single_cycle_result;
		end
	end

	always @(posedge clk)
	begin
		if (flush_i)
		begin
			instruction_o 				<= #1 0;
			writeback_reg_o 			<= #1 0;
			writeback_is_vector_o 		<= #1 0;
			has_writeback_o 			<= #1 0;
			result_o 					<= #1 0;
			store_value_o				<= #1 0;
			mask_o						<= #1 0;
			reg_lane_select_o			<= #1 0;
			pc_o						<= #1 0;
			cache_lane_select_o			<= #1 0;
			was_access_o 				<= #1 0;
			strided_offset_o			<= #1 0;
		end
		else
		begin
			instruction_o 				<= #1 instruction_nxt;
			writeback_reg_o 			<= #1 writeback_reg_nxt;
			writeback_is_vector_o 		<= #1 writeback_is_vector_nxt;
			has_writeback_o 			<= #1 has_writeback_nxt;
			pc_o						<= #1 pc_nxt;
			result_o 					<= #1 result_nxt;
			store_value_o				<= #1 store_value_nxt;
			mask_o						<= #1 mask_nxt;
			reg_lane_select_o			<= #1 reg_lane_select_i;
			cache_lane_select_o			<= #1 cache_lane_select_nxt;
			was_access_o 				<= #1 daccess_o;
			strided_offset_o			<= #1 strided_offset_i;
		end
		
	end
endmodule
