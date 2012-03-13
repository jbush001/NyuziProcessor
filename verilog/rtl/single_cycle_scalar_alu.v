
module single_cycle_scalar_alu(
    input [5:0]                 operation_i,
    input [31:0]                operand1_i,
    input [31:0]                operand2_i,
    output reg[31:0]            result_o = 0);
    
    reg[6:0]                    leading_zeroes = 0;
    reg[6:0]                    trailing_zeroes = 0;
    integer                     i, j;

    wire[31:0] difference = operand1_i - operand2_i;
    wire negative = difference[31]; 
    wire overflow =  operand2_i[31] == difference[31] && operand1_i[31] != operand2_i[31];
    wire equal = difference == 0;
    
    always @*
    begin
        trailing_zeroes = 32;
        for (i = 31; i >= 0; i = i - 1)
            if (operand2_i[i])
                trailing_zeroes = i;
    end

    always @*
    begin
        leading_zeroes = 32;
        for (j = 0; j < 32; j = j + 1)
            if (operand2_i[j])
                leading_zeroes = 31 - j;
    end

    always @*
    begin
        case (operation_i)
            6'b000000: result_o = operand1_i | operand2_i;
            6'b000001: result_o = operand1_i & operand2_i;
            6'b000010: result_o = -operand2_i;     
            6'b000011: result_o = operand1_i ^ operand2_i;      
            6'b000100: result_o = ~operand2_i;
            6'b000101: result_o = operand1_i + operand2_i;      
            6'b000110: result_o = difference;     
            6'b001001: result_o = { {32{operand1_i[31]}}, operand1_i } >> operand2_i;      
            6'b001010: result_o = operand1_i >> operand2_i;      
            6'b001011: result_o = operand1_i << operand2_i;
            6'b001100: result_o = leading_zeroes;   
            6'b001110: result_o = trailing_zeroes;
            6'b001111: result_o = operand2_i;   // copy
            6'b010000: result_o = { {31{1'b0}}, equal };   // ==
            6'b010001: result_o = { {31{1'b0}}, ~equal }; // !=
            6'b010010: result_o = { {31{1'b0}}, (overflow ^ ~negative) & ~equal }; // > (signed)
            6'b010011: result_o = { {31{1'b0}}, overflow ^ ~negative }; // >=
            6'b010100: result_o = { {31{1'b0}}, (overflow ^ negative) }; // <
            6'b010101: result_o = { {31{1'b0}}, (overflow ^ negative) | equal }; // <=
            6'b010110: result_o = { {31{1'b0}}, ~negative & ~equal }; // > (unsigned)
            6'b010111: result_o = { {31{1'b0}}, ~negative }; // >=
            6'b011000: result_o = { {31{1'b0}}, negative }; // <
            6'b011001: result_o = { {31{1'b0}}, negative | equal }; // <=
            default:   result_o = 0;	// Will happen.  We technically don't care, but make consistent for simulation.
        endcase
    end
endmodule
