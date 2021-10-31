`include "defines.svh"

import defines::*;

module parity_encoder(
    // From thread_select_stage
    input parity_t                    coded_word,
    output logic                      error);


    //Actual code
    always_comb begin
        error = ^coded_word;
    end

endmodule
