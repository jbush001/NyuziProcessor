`include "defines.svh"

import defines::*;


module hamming_encoder(
    input                             clk,
    input                             reset,

    // From thread_select_stage
    input scalar_t                    word_to_code,
    output hamming_32b_t              coded_word);

    logic parity[5:0];
    //Actual code
    always_comb begin
        //Direct correspondece with the input
        coded_word[2]     = word_to_code[0];
        coded_word[6:4]   = word_to_code[3:1];
        coded_word[14:8]  = word_to_code[10:4];
        coded_word[30:16] = word_to_code[25:11];
        coded_word[37:32] = word_to_code[31:26];
        //Hamming bits
        parity[0]       = word_to_code[0] ^ word_to_code[1] ^ word_to_code[3] ^ word_to_code[4] ^ word_to_code[6] ^ word_to_code[8] ^
                            word_to_code[10] ^ word_to_code[11] ^ word_to_code[13] ^ word_to_code[15] ^ word_to_code[17] ^ word_to_code[19] ^
                            word_to_code[21] ^ word_to_code[23] ^ word_to_code[25] ^ word_to_code[26] ^ word_to_code[28] ^ word_to_code[30];
        parity[1]       = word_to_code[0] ^ word_to_code[2] ^ word_to_code[3] ^ word_to_code[5] ^ word_to_code[6] ^ word_to_code[9] ^
                            word_to_code[10] ^ word_to_code[12] ^ word_to_code[13] ^ word_to_code[16] ^ word_to_code[17] ^ word_to_code[20] ^
                            word_to_code[21] ^ word_to_code[24] ^ word_to_code[25] ^ word_to_code[27] ^ word_to_code[28] ^ word_to_code[31];
        parity[2]       = word_to_code[1] ^ word_to_code[2] ^ word_to_code[3] ^ word_to_code[7] ^ word_to_code[8] ^ word_to_code[9] ^
                            word_to_code[10] ^ word_to_code[14] ^ word_to_code[15] ^ word_to_code[16] ^ word_to_code[17] ^ word_to_code[22] ^
                            word_to_code[23] ^ word_to_code[24] ^ word_to_code[25] ^ word_to_code[29] ^ word_to_code[30] ^ word_to_code[31];
        parity[3]       = word_to_code[4] ^ word_to_code[5] ^ word_to_code[6] ^ word_to_code[7] ^ word_to_code[8] ^ word_to_code[9] ^
                            word_to_code[10] ^ word_to_code[18] ^ word_to_code[19] ^ word_to_code[20] ^ word_to_code[21] ^ word_to_code[22] ^
                            word_to_code[23] ^ word_to_code[24] ^ word_to_code[25];
        parity[4]       = word_to_code[11] ^ word_to_code[12] ^ word_to_code[13] ^ word_to_code[14] ^ word_to_code[15] ^ word_to_code[16] ^
                            word_to_code[17] ^ word_to_code[18] ^ word_to_code[19] ^ word_to_code[20] ^ word_to_code[21] ^ word_to_code[22] ^
                            word_to_code[23] ^ word_to_code[24] ^ word_to_code[25];
        parity[5]       = word_to_code[26] ^ word_to_code[27] ^ word_to_code[28] ^ word_to_code[29] ^ word_to_code[30] ^ word_to_code[31];
    end

    assign coded_word[0]  = parity[0];
    assign coded_word[1]  = parity[1];
    assign coded_word[3]  = parity[2];
    assign coded_word[7]  = parity[3];
    assign coded_word[15] = parity[4];
    assign coded_word[31] = parity[5];
    assign coded_word[38]  = (^word_to_code) ^ (^parity);

endmodule
