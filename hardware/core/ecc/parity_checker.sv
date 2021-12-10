`include "defines.svh"

import defines::*;

module parity_checker #(
    DATA_WIDTH = 32)
    (
    input logic [DATA_WIDTH:0]        coded_word,
    output logic [DATA_WIDTH-1:0]     data,
    output logic                      error);


    //Actual code
    always_comb begin
        data = coded_word[DATA_WIDTH:1];
        error = ^coded_word;
    end

endmodule
