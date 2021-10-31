`include "defines.svh"

import defines::*;

module parity_encoder(
    // From thread_select_stage
    input scalar_t                    word_to_code,
    output parity_t                   coded_word);


    //Actual code
    always_comb begin
        coded_word = {words_to_code, ^words_to_code};
    end

endmodule
