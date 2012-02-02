module vector_register_file(
	input 					clk,
	input [6:0] 			sel1_i,
	input [6:0] 			sel2_i,
	output reg [511:0] 		value1_o = 0,
	output reg [511:0] 		value2_o = 0,
	input [6:0]				write_reg_i,
	input [511:0]			write_value_i,
	input [15:0]			write_mask_i,
	input					write_en_i);
	
	parameter NUM_REGISTERS = 4 * 32;

	// 128 registers total (32 per strand * 4 strands)
	reg[31:0]				lane15[0:NUM_REGISTERS - 1];
	reg[31:0]				lane14[0:NUM_REGISTERS - 1];
	reg[31:0]				lane13[0:NUM_REGISTERS - 1];
	reg[31:0]				lane12[0:NUM_REGISTERS - 1];
	reg[31:0]				lane11[0:NUM_REGISTERS - 1];
	reg[31:0]				lane10[0:NUM_REGISTERS - 1];
	reg[31:0]				lane9[0:NUM_REGISTERS - 1];
	reg[31:0]				lane8[0:NUM_REGISTERS - 1];
	reg[31:0]				lane7[0:NUM_REGISTERS - 1];
	reg[31:0]				lane6[0:NUM_REGISTERS - 1];
	reg[31:0]				lane5[0:NUM_REGISTERS - 1];
	reg[31:0]				lane4[0:NUM_REGISTERS - 1];
	reg[31:0]				lane3[0:NUM_REGISTERS - 1];
	reg[31:0]				lane2[0:NUM_REGISTERS - 1];
	reg[31:0]				lane1[0:NUM_REGISTERS - 1];
	reg[31:0]				lane0[0:NUM_REGISTERS - 1];
	integer					i;
	
	initial
	begin
		// synthesis translate_off
		for (i = 0; i < NUM_REGISTERS; i = i + 1)
		begin
			lane15[i] = 0;
			lane14[i] = 0;
			lane13[i] = 0;
			lane12[i] = 0;
			lane11[i] = 0;
			lane10[i] = 0;
			lane9[i] = 0;
			lane8[i] = 0;
			lane7[i] = 0;
			lane6[i] = 0;
			lane5[i] = 0;
			lane4[i] = 0;
			lane3[i] = 0;
			lane2[i] = 0;
			lane1[i] = 0;
			lane0[i] = 0;
		end	
		
		// synthesis translate_on
	end
	
	always @(posedge clk)
	begin
		value1_o <= #1 {
			lane15[sel1_i],
			lane14[sel1_i],
			lane13[sel1_i],
			lane12[sel1_i],
			lane11[sel1_i],
			lane10[sel1_i],
			lane9[sel1_i],
			lane8[sel1_i],
			lane7[sel1_i],
			lane6[sel1_i],
			lane5[sel1_i],
			lane4[sel1_i],
			lane3[sel1_i],
			lane2[sel1_i],
			lane1[sel1_i],
			lane0[sel1_i]
		};
			
		value2_o <= #1 {
			lane15[sel2_i],
			lane14[sel2_i],
			lane13[sel2_i],
			lane12[sel2_i],
			lane11[sel2_i],
			lane10[sel2_i],
			lane9[sel2_i],
			lane8[sel2_i],
			lane7[sel2_i],
			lane6[sel2_i],
			lane5[sel2_i],
			lane4[sel2_i],
			lane3[sel2_i],
			lane2[sel2_i],
			lane1[sel2_i],
			lane0[sel2_i]
		};

		if (write_en_i)
		begin
			$display("[st %d] v%d{%b} <= %x", write_reg_i[6:5], write_reg_i[4:0], write_mask_i, write_value_i);
			
			if (write_mask_i[15]) lane15[write_reg_i] <= #1 write_value_i[511:480];
			if (write_mask_i[14]) lane14[write_reg_i] <= #1 write_value_i[479:448];
			if (write_mask_i[13]) lane13[write_reg_i] <= #1 write_value_i[447:416];
			if (write_mask_i[12]) lane12[write_reg_i] <= #1 write_value_i[415:384];
			if (write_mask_i[11]) lane11[write_reg_i] <= #1 write_value_i[383:352];
			if (write_mask_i[10]) lane10[write_reg_i] <= #1 write_value_i[351:320];
			if (write_mask_i[9]) lane9[write_reg_i] <= #1 write_value_i[319:288];
			if (write_mask_i[8]) lane8[write_reg_i] <= #1 write_value_i[287:256];
			if (write_mask_i[7]) lane7[write_reg_i] <= #1 write_value_i[255:224];
			if (write_mask_i[6]) lane6[write_reg_i] <= #1 write_value_i[223:192];
			if (write_mask_i[5]) lane5[write_reg_i] <= #1 write_value_i[191:160];
			if (write_mask_i[4]) lane4[write_reg_i] <= #1 write_value_i[159:128];
			if (write_mask_i[3]) lane3[write_reg_i] <= #1 write_value_i[127:96];
			if (write_mask_i[2]) lane2[write_reg_i] <= #1 write_value_i[95:64];
			if (write_mask_i[1]) lane1[write_reg_i] <= #1 write_value_i[63:32];
			if (write_mask_i[0]) lane0[write_reg_i] <= #1 write_value_i[31:0];
		end
	end

endmodule
