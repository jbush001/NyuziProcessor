module multi_cycle_scalar_alu
	#(parameter EXPONENT_WIDTH = 8, 
	parameter SIGNIFICAND_WIDTH = 23,
	parameter TOTAL_WIDTH = 1 + EXPONENT_WIDTH + SIGNIFICAND_WIDTH,
	parameter SIGNIFICAND_PRODUCT_WIDTH = (SIGNIFICAND_WIDTH + 2) * 2)

	(input									clk,
	input [5:0]								operation_i,
	input [TOTAL_WIDTH - 1:0]				operand1_i,
	input [TOTAL_WIDTH - 1:0]				operand2_i,
	output reg [TOTAL_WIDTH - 1:0]			result_o);

	reg[5:0] 								operation2;
	reg[5:0] 								operation3;
	reg[5:0] 								operation4;
	wire[5:0] 								add1_operand_align_shift;
	wire[SIGNIFICAND_WIDTH + 2:0] 			add1_significand1;
	wire[SIGNIFICAND_WIDTH + 2:0] 			add1_significand2;
	wire[EXPONENT_WIDTH - 1:0] 				add1_exponent1;
	wire[EXPONENT_WIDTH - 1:0] 				add1_exponent2;
	wire 									add1_result_is_inf;
	wire 									add1_result_is_nan;
	wire[5:0] 								add1_operation;
	wire 									add1_exponent2_larger;
	wire[EXPONENT_WIDTH - 1:0] 				add2_exponent; 
	wire[SIGNIFICAND_WIDTH + 2:0] 			add2_significand1;
	wire[SIGNIFICAND_WIDTH + 2:0] 			add2_significand2;
	wire 									add2_result_is_inf;
	wire 									add2_result_is_nan;
	wire[5:0] 								add2_operation;
	wire[SIGNIFICAND_WIDTH + 2:0] 			add3_significand;
	wire 									add3_sign;
	wire[EXPONENT_WIDTH - 1:0] 				add3_exponent; 
	wire[5:0] 								add3_operation;
	wire 									add3_result_is_inf;
	wire 									add3_result_is_nan;
	wire [EXPONENT_WIDTH - 1:0] 			mul1_exponent;
	wire 									mul1_sign;
	reg [EXPONENT_WIDTH - 1:0] 				mul2_exponent;
	reg 									mul2_sign;
	wire [SIGNIFICAND_PRODUCT_WIDTH - 1:0]	mul3_significand;
	reg [EXPONENT_WIDTH - 1:0] 				mul3_exponent;
	reg 									mul3_sign;
	reg[(SIGNIFICAND_WIDTH + 1) * 2 - 1:0] 	mux_significand;
	reg[EXPONENT_WIDTH - 1:0] 				mux_exponent; 
	reg 									mux_sign;
	reg 									mux_result_is_inf;
	reg 									mux_result_is_nan;
	wire[EXPONENT_WIDTH - 1:0] 				norm_exponent;
	wire[SIGNIFICAND_WIDTH - 1:0] 			norm_significand;
	wire									norm_sign;
	wire[5:0] 								norm_operation;
	wire 									norm_result_is_inf;
	wire 									norm_result_is_nan;
	wire 									result_equal;
	wire 									result_negative;
	wire[31:0]								int_result;
	reg[31:0]								multiplicand;
	reg[31:0]								multiplier;
	wire[63:0]								mult_product;
	wire[31:0]								mul1_muliplicand;
	wire[31:0]								mul1_multiplier;

	initial
	begin
		result_o = 0;
		operation2 = 0;
		operation3 = 0;
		operation4 = 0;
		mux_significand = 0;
		mux_exponent = 0; 
		mux_sign = 0;
		mux_result_is_inf = 0;
		mux_result_is_nan = 0;
		multiplicand = 0;
		multiplier = 0;
	end

	fp_adder_stage1 add1(
		.clk(clk),
		.operation_i(operation_i),
		.operand1_i(operand1_i),
		.operand2_i(operand2_i),
		.operand_align_shift_o(add1_operand_align_shift),
		.significand1_o(add1_significand1),
		.exponent1_o(add1_exponent1),
		.significand2_o(add1_significand2),
		.exponent2_o(add1_exponent2),
		.result_is_inf_o(add1_result_is_inf),
		.result_is_nan_o(add1_result_is_nan),
		.exponent2_larger_o(add1_exponent2_larger));
		
	fp_adder_stage2 add2(
		.clk(clk),
		.operation_i(operation2),
		.operand_align_shift_i(add1_operand_align_shift),
		.significand1_i(add1_significand1),
		.significand2_i(add1_significand2),
		.exponent1_i(add1_exponent1),
		.exponent2_i(add1_exponent2),
		.exponent2_larger_i(add1_exponent2_larger),
		.result_is_inf_i(add1_result_is_inf),
		.result_is_inf_o(add2_result_is_inf),
		.result_is_nan_i(add1_result_is_nan),
		.result_is_nan_o(add2_result_is_nan),
		.exponent_o(add2_exponent),
		.significand1_o(add2_significand1),
		.significand2_o(add2_significand2));

	fp_adder_stage3 add3(
		.clk(clk),
		.operation_i(operation3),
		.significand1_i(add2_significand1),
		.significand2_i(add2_significand2),
		.significand_o(add3_significand),
		.sign_o(add3_sign),
		.exponent_i(add2_exponent),
		.exponent_o(add3_exponent),
		.result_is_inf_i(add2_result_is_inf),
		.result_is_inf_o(add3_result_is_inf),
		.result_is_nan_i(add2_result_is_nan),
		.result_is_nan_o(add3_result_is_nan));

	fp_multiplier_stage1 mul1(
		.clk(clk),
		.operation_i(operation_i),
		.operand1_i(operand1_i),
		.operand2_i(operand2_i),
		.significand1_o(mul1_muliplicand),
		.significand2_o(mul1_multiplier),
		.exponent_o(mul1_exponent),
		.sign_o(mul1_sign));

	// Mux results into the multiplier
	always @*
	begin
		if (operation_i == 6'b000111)
		begin
			// Integer multiply instruction
			multiplicand = operand1_i;
			multiplier = operand2_i;
		end
		else
		begin
			// Floating point multiply
			multiplicand = mul1_muliplicand;
			multiplier = mul1_multiplier;
		end
	
	end

	integer_multiplier imul(
		.clk(clk),
		.multiplicand_i(multiplicand),
		.multiplier_i(multiplier),
		.product_o(mult_product));

	always @(posedge clk)
	begin
		mul2_exponent 				<= #1 mul1_exponent;
		mul2_sign 					<= #1 mul1_sign;
		mul3_exponent 				<= #1 mul2_exponent;
		mul3_sign 					<= #1 mul2_sign;
	end

	// Select the appropriate pipeline to feed into the (shared) normalization
	// stage
	always @*
	begin
		if (operation4 == 6'b100010 || operation4 == 6'b101010)
		begin
			// Selection multiplication result
			mux_significand = mult_product[(SIGNIFICAND_WIDTH + 1) * 2 - 1:0];
			mux_exponent = mul3_exponent;
			mux_sign = mul3_sign;
			mux_result_is_inf = 0;		// XXX not hooked up
			mux_result_is_nan = 0;		// XXX not hooked up
		end
		else
		begin
			// Select adder pipeline result
			// XXX mux_significand is 48 bits, but rhs is 49 bits
			mux_significand = { add3_significand, {SIGNIFICAND_WIDTH{1'b0}} };
			mux_exponent = add3_exponent;
			mux_sign = add3_sign;
			mux_result_is_inf = add3_result_is_inf;
			mux_result_is_nan = add3_result_is_nan;
		end
	end

	fp_normalize norm(
		.clk(clk),
		.significand_i(mux_significand),
		.exponent_i(mux_exponent),
		.significand_o(norm_significand),
		.exponent_o(norm_exponent),
		.sign_i(mux_sign),
		.sign_o(norm_sign),
		.operation_i(operation4),
		.result_is_inf_i(mux_result_is_inf),
		.result_is_inf_o(norm_result_is_inf),
		.result_is_nan_i(mux_result_is_nan),
		.result_is_nan_o(norm_result_is_nan));
		
	fp_convert convert(
		.sign_i(mul3_sign),
		.exponent_i(mul3_exponent),
		.significand_i(mult_product[SIGNIFICAND_PRODUCT_WIDTH - 1:0]),
		.result_o(int_result));

	assign result_equal = norm_exponent == 0 && norm_significand == 0;
	assign result_negative = norm_sign == 1;

	// Put the results back together, handling exceptional conditions
	always @*
	begin
		case (operation4)
			6'b000111: result_o = mult_product[31:0];	// Int multiply, truncate result
			6'b110000: result_o = int_result;		// sftoi
			6'b101100: result_o = !result_equal & !result_negative; // Greater than
			6'b101110: result_o = result_negative;   // Less than
			6'b101101: result_o = !result_negative;      // Greater than or equal
			6'b101111: result_o = result_equal || result_negative; // Less than or equal
			default:
			begin
				// Not a comparison, take the result as is.
				if (norm_result_is_nan)
					result_o = { 1'b1, {EXPONENT_WIDTH{1'b1}}, {SIGNIFICAND_WIDTH{1'b1}} }; // nan
				else if (norm_result_is_inf)
					result_o = { 1'b0, {EXPONENT_WIDTH{1'b1}}, {SIGNIFICAND_WIDTH{1'b0}} };	// inf
				else
					result_o = { norm_sign, norm_exponent, norm_significand };
			end
		endcase
	end
	
	always @(posedge clk)
	begin
		operation2 <= operation_i;
		operation3 <= operation2;
		operation4 <= operation3;
	end
endmodule
