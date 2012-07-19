//
// Handles arithmetic operations that take one cycle to complete.
// The output is not registered.
//

module single_cycle_scalar_alu(
    input [5:0]                 operation_i,
    input [31:0]                operand1_i,
    input [31:0]                operand2_i,
    output reg[31:0]            result_o = 0);
    
    reg[6:0]                    leading_zeroes = 0;
    reg[6:0]                    trailing_zeroes = 0;
    wire						carry;
    wire						_ignore;
    wire[31:0]					sum_difference;
    integer                     i, j;

	wire is_sub = operation_i != `OP_IADD;

	// Add/subtract, with XORs in front of a carry chain.
	assign { carry, sum_difference, _ignore } = { 1'b0, operand1_i, is_sub } 
		+ { is_sub, {32{is_sub}} ^ operand2_i, is_sub };

	// These flags are only valid if this is is_sub is true.  Otherwise ignored.
    wire negative = sum_difference[31]; 
    wire overflow =  operand2_i[31] == negative && operand1_i[31] != operand2_i[31];
    wire zero = sum_difference == 0;
    wire signed_gtr = overflow == negative;

    always @*
    begin
        trailing_zeroes = 32;
        for (i = 31; i >= 0; i = i - 1)
        begin
            if (operand2_i[i])
                trailing_zeroes = i;
		end
    end

    always @*
    begin
        leading_zeroes = 32;
        for (j = 0; j < 32; j = j + 1)
        begin
            if (operand2_i[j])
                leading_zeroes = 31 - j;
		end
    end

    always @*
    begin
        case (operation_i)
            `OP_OR: result_o = operand1_i | operand2_i;
            `OP_AND: result_o = operand1_i & operand2_i;
            `OP_UMINUS: result_o = -operand2_i;     
            `OP_XOR: result_o = operand1_i ^ operand2_i;      
            `OP_NOT: result_o = ~operand2_i;
            `OP_IADD,   
            `OP_ISUB: result_o = sum_difference;     
            `OP_ASR: result_o = operand2_i[31:5] == 0 ? { {32{operand1_i[31]}}, operand1_i } >> operand2_i[4:0] : {32{operand1_i[31]}};      
            `OP_LSR: result_o = operand2_i[31:5] == 0 ? { 32'd0, operand1_i } >> operand2_i[4:0] : 0;      
            `OP_LSL: result_o = operand2_i[31:5] == 0 ? operand1_i << operand2_i[4:0] : 0;
            `OP_CLZ: result_o = leading_zeroes;   
            `OP_CTZ: result_o = trailing_zeroes;
            `OP_COPY: result_o = operand2_i;   
            `OP_EQUAL: result_o = { {31{1'b0}}, zero };   
            `OP_NEQUAL: result_o = { {31{1'b0}}, ~zero }; 
            `OP_SIGTR: result_o = { {31{1'b0}}, signed_gtr & ~zero };
            `OP_SIGTE: result_o = { {31{1'b0}}, signed_gtr | zero }; 
            `OP_SILT: result_o = { {31{1'b0}}, ~signed_gtr & ~zero}; 
            `OP_SILTE: result_o = { {31{1'b0}}, ~signed_gtr | zero };
            `OP_UIGTR: result_o = { {31{1'b0}}, ~carry & ~zero };
            `OP_UIGTE: result_o = { {31{1'b0}}, ~carry | zero };
            `OP_UILT: result_o = { {31{1'b0}}, carry & ~zero };
            `OP_UILTE: result_o = { {31{1'b0}}, carry | zero };
            default:   result_o = 0;	// Will happen.  We technically don't care, but make consistent for simulation.
        endcase
    end
endmodule
