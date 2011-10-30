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
	wire[32:0]					diff0;
	wire[32:0]					diff1;
	wire[32:0]					diff2;
	wire[32:0]					diff3;
	wire[32:0]					diff4;
	wire[32:0]					diff5;
	wire[32:0]					diff6;
	wire[32:0]					diff7;
	wire[32:0]					diff8;
	wire[32:0]					diff9;
	wire[32:0]					diff10;
	wire[32:0]					diff11;
	wire[32:0]					diff12;
	wire[32:0]					diff13;
	wire[32:0]					diff14;
	wire[32:0]					diff15;
	
	initial
	begin
		result_o = 0;
	end
	
	assign diff15 = { 1'b0, operand1_i[511:480] } - { 1'b0, operand2_i[511:480] };
	assign diff14 = { 1'b0, operand1_i[479:448] } - { 1'b0, operand2_i[479:448] };
	assign diff13 = { 1'b0, operand1_i[447:416] } - { 1'b0, operand2_i[447:416] };
	assign diff12 = { 1'b0, operand1_i[415:384] } - { 1'b0, operand2_i[415:384] };
	assign diff11 = { 1'b0, operand1_i[383:352] } - { 1'b0, operand2_i[383:352] };
	assign diff10 = { 1'b0, operand1_i[351:320] } - { 1'b0, operand2_i[351:320] };
	assign diff9 = { 1'b0, operand1_i[319:288] } - { 1'b0, operand2_i[319:288] };
	assign diff8 = { 1'b0, operand1_i[287:256] } - { 1'b0, operand2_i[287:256] };
	assign diff7 = { 1'b0, operand1_i[255:224] } - { 1'b0, operand2_i[255:224] };
	assign diff6 = { 1'b0, operand1_i[223:192] } - { 1'b0, operand2_i[223:192] };
	assign diff5 = { 1'b0, operand1_i[191:160] } - { 1'b0, operand2_i[191:160] };
	assign diff4 = { 1'b0, operand1_i[159:128] } - { 1'b0, operand2_i[159:128] };
	assign diff3 = { 1'b0, operand1_i[127:96] } - { 1'b0, operand2_i[127:96] };
	assign diff2 = { 1'b0, operand1_i[95:64] } - { 1'b0, operand2_i[95:64] };
	assign diff1 = { 1'b0, operand1_i[63:32] } - { 1'b0, operand2_i[63:32] };
	assign diff0 = { 1'b0, operand1_i[31:0] } - { 1'b0, operand2_i[31:0] };
	
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
		diff15[32], 
		diff14[32], 
		diff13[32], 
		diff12[32], 
		diff11[32], 
		diff10[32], 
		diff9[32], 
		diff8[32], 
		diff7[32], 
		diff6[32], 
		diff5[32], 
		diff4[32], 
		diff3[32], 
		diff2[32], 
		diff1[32], 
		diff0[32] 
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
		operand1_i[31:0] + operand2_i[31:0]
	};

	assign asr = {
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
		{ {32{operand1_i[31]}}, operand1_i[31:0] } >> operand2_i[31:0]
	};
	
	assign lsr = {
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
		operand1_i[31:0] >> operand2_i[31:0]
	};

	assign lsl = {
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
		operand1_i[31:0] << operand2_i[31:0]
	};
	
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

			// Comparisons.  Coalesce result bits.
			6'b001101: result_o = { {496{1'b0}}, equal };	// ==
			6'b001110: result_o = { {496{1'b0}}, ~equal }; // !=

			6'b001111: result_o = { {496{1'b0}}, ~negative }; // > (signed)
			6'b010000: result_o = { {496{1'b0}}, ~negative | equal }; // >=
			6'b010001: result_o = { {496{1'b0}}, negative }; // <
			6'b010010: result_o = { {496{1'b0}}, negative | equal }; // <=

			6'b010101: result_o = { {496{1'b0}}, ~overflow }; // > (unsigned)
			6'b010110: result_o = { {496{1'b0}}, ~overflow | equal }; // >=
			6'b010111: result_o = { {496{1'b0}}, overflow }; // <
			6'b011000: result_o = { {496{1'b0}}, overflow | equal }; // <=

			default: result_o = 0;
		endcase
	end
endmodule
