module single_cycle_alu(
	input [5:0]					operation_i,
	input [511:0]				operand1_i,
	input [511:0]				operand2_i,
	output reg[511:0]			result_o);
	
	wire[511:0]					difference;
	wire[15:0]					is_equal;
	wire[15:0]					is_negative;
	wire[511:0]					sum;
	wire[511:0]					asr;
	wire[511:0]					lsr;
	wire[511:0]					lsl;
	
	initial
	begin
		result_o = 0;
	end
	
	assign difference = {
		operand1_i[511:480] - operand2_i[511:480],
		operand1_i[479:448] - operand2_i[479:448],
		operand1_i[447:416] - operand2_i[447:416],
		operand1_i[415:384] - operand2_i[415:384],
		operand1_i[383:352] - operand2_i[383:352],
		operand1_i[351:320] - operand2_i[351:320],
		operand1_i[319:288] - operand2_i[319:288],
		operand1_i[287:256] - operand2_i[287:256],
		operand1_i[255:224] - operand2_i[255:224],
		operand1_i[223:192] - operand2_i[223:192],
		operand1_i[191:160] - operand2_i[191:160],
		operand1_i[159:128] - operand2_i[159:128],
		operand1_i[127:96] - operand2_i[127:96],
		operand1_i[95:64] - operand2_i[95:64],
		operand1_i[63:32] - operand2_i[63:32],
		operand1_i[31:0] - operand2_i[31:0]
	};
	
	assign is_negative = { 
		difference[511], 
		difference[479],
		difference[447],
		difference[415],
		difference[383],
		difference[351],
		difference[319],
		difference[287],
		difference[255],
		difference[223],
		difference[191],
		difference[159],
		difference[127],
		difference[95],
		difference[63],
		difference[31]
	};

	assign is_equal = { 
		difference[511:480] == 0, 
		difference[479:448] == 0,
		difference[447:416] == 0,
		difference[415:384] == 0,
		difference[383:352] == 0,
		difference[351:320] == 0,
		difference[319:288] == 0,
		difference[287:256] == 0,
		difference[255:224] == 0,
		difference[223:192] == 0,
		difference[191:160] == 0,
		difference[159:128] == 0,
		difference[127:96] == 0,
		difference[95:64] == 0,
		difference[63:32] == 0,
		difference[31:0] == 0
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
			6'b001101: result_o = { {496{1'b0}}, is_equal };	// ==
			6'b001110: result_o = { {496{1'b0}}, ~is_equal }; // !=
			6'b001111: result_o = { {496{1'b0}}, ~is_negative }; // >
			6'b010000: result_o = { {496{1'b0}}, ~is_negative | is_equal }; // >=
			6'b010001: result_o = { {496{1'b0}}, is_negative }; // <
			6'b010010: result_o = { {496{1'b0}}, is_negative | is_equal }; // <=
			default: result_o = 0;
		endcase
	end
endmodule
