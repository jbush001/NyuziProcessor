//
// Performs any ALU operation that can complete in a single cycle
//

module single_cycle_alu(
	input [5:0]					operation_i,
	input [511:0]				operand1_i,
	input [511:0]				operand2_i,
	output reg[511:0]			result_o);
	
	wire[511:0]					difference;
	wire[15:0]					equal;
	wire[15:0]					negative;
	wire[15:0]					overflow;
	wire[511:0]					sum;
	wire[511:0]					asr;
	wire[511:0]					lsr;
	wire[511:0]					lsl;
	wire[31:0]					diff0;
	wire[31:0]					diff1;
	wire[31:0]					diff2;
	wire[31:0]					diff3;
	wire[31:0]					diff4;
	wire[31:0]					diff5;
	wire[31:0]					diff6;
	wire[31:0]					diff7;
	wire[31:0]					diff8;
	wire[31:0]					diff9;
	wire[31:0]					diff10;
	wire[31:0]					diff11;
	wire[31:0]					diff12;
	wire[31:0]					diff13;
	wire[31:0]					diff14;
	wire[31:0]					diff15;
	wire[511:0]					shuffled;
	
	initial
	begin
		result_o = 0;
	end

`ifdef SINGLE_LANE_ONLY
	assign diff15 = 0;
	assign diff14 = 0;
	assign diff13 = 0;
	assign diff12 = 0;
	assign diff11 = 0;
	assign diff10 = 0;
	assign diff9 = 0;
	assign diff8 = 0;
	assign diff7 = 0;
	assign diff6 = 0;
	assign diff5 = 0;
	assign diff4 = 0;
	assign diff3 = 0;
	assign diff2 = 0;
	assign diff1 = 0;
`else	
	assign diff15 = operand1_i[511:480] - operand2_i[511:480];
	assign diff14 = operand1_i[479:448] - operand2_i[479:448];
	assign diff13 = operand1_i[447:416] - operand2_i[447:416];
	assign diff12 = operand1_i[415:384] - operand2_i[415:384];
	assign diff11 = operand1_i[383:352] - operand2_i[383:352];
	assign diff10 = operand1_i[351:320] - operand2_i[351:320];
	assign diff9 = operand1_i[319:288] - operand2_i[319:288];
	assign diff8 = operand1_i[287:256] - operand2_i[287:256];
	assign diff7 = operand1_i[255:224] - operand2_i[255:224];
	assign diff6 = operand1_i[223:192] - operand2_i[223:192];
	assign diff5 = operand1_i[191:160] - operand2_i[191:160];
	assign diff4 = operand1_i[159:128] - operand2_i[159:128];
	assign diff3 = operand1_i[127:96] - operand2_i[127:96];
	assign diff2 = operand1_i[95:64] - operand2_i[95:64];
	assign diff1 = operand1_i[63:32] - operand2_i[63:32];
`endif
	assign diff0 = operand1_i[31:0] - operand2_i[31:0];
	
	assign difference = {
		diff15[31:0],
		diff14[31:0],
		diff13[31:0],
		diff12[31:0],
		diff11[31:0],
		diff10[31:0],
		diff9[31:0],
		diff8[31:0],
		diff7[31:0],
		diff6[31:0],
		diff5[31:0],
		diff4[31:0],
		diff3[31:0],
		diff2[31:0],
		diff1[31:0],
		diff0[31:0]
	};
	
	assign negative = { 
		diff15[31], 
		diff14[31], 
		diff13[31], 
		diff12[31], 
		diff11[31], 
		diff10[31], 
		diff9[31], 
		diff8[31], 
		diff7[31], 
		diff6[31], 
		diff5[31], 
		diff4[31], 
		diff3[31], 
		diff2[31], 
		diff1[31], 
		diff0[31]
	};
	
	assign overflow = {
		(operand2_i[511] == diff15[31]) && (operand1_i[511] != operand2_i[511]), 
		(operand2_i[479] == diff14[31]) && (operand1_i[479] != operand2_i[479]), 
		(operand2_i[447] == diff13[31]) && (operand1_i[447] != operand2_i[447]), 
		(operand2_i[415] == diff12[31]) && (operand1_i[415] != operand2_i[415]), 
		(operand2_i[383] == diff11[31]) && (operand1_i[383] != operand2_i[383]), 
		(operand2_i[351] == diff10[31]) && (operand1_i[351] != operand2_i[351]), 
		(operand2_i[319] == diff9[31]) && (operand1_i[319] != operand2_i[319]), 
		(operand2_i[287] == diff8[31]) && (operand1_i[287] != operand2_i[287]), 
		(operand2_i[255] == diff7[31]) && (operand1_i[255] != operand2_i[255]), 
		(operand2_i[223] == diff6[31]) && (operand1_i[223] != operand2_i[223]), 
		(operand2_i[191] == diff5[31]) && (operand1_i[191] != operand2_i[191]), 
		(operand2_i[159] == diff4[31]) && (operand1_i[159] != operand2_i[159]), 
		(operand2_i[127] == diff3[31]) && (operand1_i[127] != operand2_i[127]), 
		(operand2_i[95] == diff2[31]) && (operand1_i[95] != operand2_i[95]), 
		(operand2_i[63] == diff1[31]) && (operand1_i[63] != operand2_i[63]), 
		(operand2_i[31] == diff0[31]) && (operand1_i[31] != operand2_i[31]) 
	};

	assign equal = { 
		diff15[31:0] == 0, 
		diff14[31:0] == 0,
		diff13[31:0] == 0,
		diff12[31:0] == 0,
		diff11[31:0] == 0,
		diff10[31:0] == 0,
		diff9[31:0] == 0,
		diff8[31:0] == 0,
		diff7[31:0] == 0,
		diff6[31:0] == 0,
		diff5[31:0] == 0,
		diff4[31:0] == 0,
		diff3[31:0] == 0,
		diff2[31:0] == 0,
		diff1[31:0] == 0,
		diff0[31:0] == 0
	};

	assign sum = {
`ifdef SINGLE_LANE_ONLY
		480'd0,
`else
		operand1_i[511:480] + operand2_i[511:480],
		operand1_i[479:448] + operand2_i[479:448],
		operand1_i[447:416] + operand2_i[447:416],
		operand1_i[415:384] + operand2_i[415:384],
		operand1_i[383:352] + operand2_i[383:352],
		operand1_i[351:320] + operand2_i[351:320],
		operand1_i[319:288] + operand2_i[319:288],
		operand1_i[287:256] + operand2_i[287:256],
		operand1_i[255:224] + operand2_i[255:224],
		operand1_i[223:192] + operand2_i[223:192],
		operand1_i[191:160] + operand2_i[191:160],
		operand1_i[159:128] + operand2_i[159:128],
		operand1_i[127:96] + operand2_i[127:96],
		operand1_i[95:64] + operand2_i[95:64],
		operand1_i[63:32] + operand2_i[63:32],
`endif
		operand1_i[31:0] + operand2_i[31:0]
	};

	assign asr = {
`ifdef SINGLE_LANE_ONLY
		480'd0,
`else
		{ {32{operand1_i[31]}}, operand1_i[511:480] } >> operand2_i[511:480],
		{ {32{operand1_i[31]}}, operand1_i[479:448] } >> operand2_i[479:448],
		{ {32{operand1_i[31]}}, operand1_i[447:416] } >> operand2_i[447:416],
		{ {32{operand1_i[31]}}, operand1_i[415:384] } >> operand2_i[415:384],
		{ {32{operand1_i[31]}}, operand1_i[383:352] } >> operand2_i[383:352],
		{ {32{operand1_i[31]}}, operand1_i[351:320] } >> operand2_i[351:320],
		{ {32{operand1_i[31]}}, operand1_i[319:288] } >> operand2_i[319:288],
		{ {32{operand1_i[31]}}, operand1_i[287:256] } >> operand2_i[287:256],
		{ {32{operand1_i[31]}}, operand1_i[255:224] } >> operand2_i[255:224],
		{ {32{operand1_i[31]}}, operand1_i[223:192] } >> operand2_i[223:192],
		{ {32{operand1_i[31]}}, operand1_i[191:160] } >> operand2_i[191:160],
		{ {32{operand1_i[31]}}, operand1_i[159:128] } >> operand2_i[159:128],
		{ {32{operand1_i[31]}}, operand1_i[127:96] } >> operand2_i[127:96],
		{ {32{operand1_i[31]}}, operand1_i[95:64] } >> operand2_i[95:64],
		{ {32{operand1_i[31]}}, operand1_i[63:32] } >> operand2_i[63:32],
`endif
		{ {32{operand1_i[31]}}, operand1_i[31:0] } >> operand2_i[31:0]
	};
	
	assign lsr = {
`ifdef SINGLE_LANE_ONLY
		480'd0,
`else
		operand1_i[511:480] >> operand2_i[511:480],
		operand1_i[479:448] >> operand2_i[479:448],
		operand1_i[447:416] >> operand2_i[447:416],
		operand1_i[415:384] >> operand2_i[415:384],
		operand1_i[383:352] >> operand2_i[383:352],
		operand1_i[351:320] >> operand2_i[351:320],
		operand1_i[319:288] >> operand2_i[319:288],
		operand1_i[287:256] >> operand2_i[287:256],
		operand1_i[255:224] >> operand2_i[255:224],
		operand1_i[223:192] >> operand2_i[223:192],
		operand1_i[191:160] >> operand2_i[191:160],
		operand1_i[159:128] >> operand2_i[159:128],
		operand1_i[127:96] >> operand2_i[127:96],
		operand1_i[95:64] >> operand2_i[95:64],
		operand1_i[63:32] >> operand2_i[63:32],
`endif
		operand1_i[31:0] >> operand2_i[31:0]
	};

	assign lsl = {
`ifdef SINGLE_LANE_ONLY
		480'd0,
`else
		operand1_i[511:480] << operand2_i[511:480],
		operand1_i[479:448] << operand2_i[479:448],
		operand1_i[447:416] << operand2_i[447:416],
		operand1_i[415:384] << operand2_i[415:384],
		operand1_i[383:352] << operand2_i[383:352],
		operand1_i[351:320] << operand2_i[351:320],
		operand1_i[319:288] << operand2_i[319:288],
		operand1_i[287:256] << operand2_i[287:256],
		operand1_i[255:224] << operand2_i[255:224],
		operand1_i[223:192] << operand2_i[223:192],
		operand1_i[191:160] << operand2_i[191:160],
		operand1_i[159:128] << operand2_i[159:128],
		operand1_i[127:96] << operand2_i[127:96],
		operand1_i[95:64] << operand2_i[95:64],
		operand1_i[63:32] << operand2_i[63:32],
`endif
		operand1_i[31:0] << operand2_i[31:0]
	};
	
	vector_shuffler shu(
		.value_i(operand1_i),
		.shuffle_i(operand2_i),
		.result_o(shuffled));
	
	always @*
	begin
		case (operation_i)
			6'b000000: result_o = operand1_i | operand2_i;
			6'b000001: result_o = operand1_i & operand2_i;
			6'b000010: result_o = operand1_i & ~operand2_i;		
			6'b000011: result_o = operand1_i ^ operand2_i;		
			6'b000100: result_o = ~operand2_i;		

			6'b000101: result_o = sum;		
			6'b000110: result_o = difference;		
			6'b001001: result_o = asr;		
			6'b001010: result_o = lsr;		
			6'b001011: result_o = lsl;		
			6'b001101: result_o = shuffled;
			6'b001111: result_o = operand2_i;

			// Comparisons.  Coalesce result bits.
			6'b010000: result_o = { {496{1'b0}}, equal };	// ==
			6'b010001: result_o = { {496{1'b0}}, ~equal }; // !=

			6'b010010: result_o = { {496{1'b0}}, (overflow ^ ~negative) & ~equal }; // > (signed)
			6'b010011: result_o = { {496{1'b0}}, overflow ^ ~negative }; // >=
			6'b010100: result_o = { {496{1'b0}}, (overflow ^ negative) }; // <
			6'b010101: result_o = { {496{1'b0}}, (overflow ^ negative) | equal }; // <=

			6'b010110: result_o = { {496{1'b0}}, ~negative & ~equal }; // > (unsigned)
			6'b010111: result_o = { {496{1'b0}}, ~negative }; // >=
			6'b011000: result_o = { {496{1'b0}}, negative }; // <
			6'b011001: result_o = { {496{1'b0}}, negative | equal }; // <=

			default: result_o = 0;
		endcase
	end
endmodule
