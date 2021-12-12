`include "defines.svh"

import defines::*;

module parity_encoder #(
    DATA_WIDTH = 32)
    (
    input [DATA_WIDTH - 1:0]          word_to_code,
    output [DATA_WIDTH:0]             coded_word);


    always_comb begin
        coded_word = {word_to_code, ^word_to_code};
    end

endmodule
