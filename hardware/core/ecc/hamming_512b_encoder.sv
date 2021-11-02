`include "defines.svh"

import defines::*;


module hamming_encoder(
    input                             clk,
    input                             reset,

    // From thread_select_stage
    input cache_line_data_t           word_to_code,
    output hamming_512b_t             coded_word);


    //Actual code
    logic aux_0;
    logic aux_1;
    logic aux_3;
    
    always_comb begin : parity0
        aux_0 = word_to_code[0];
        aux_0 ^= word_to_code[1] ^ word_to_code[3];
        aux_0 ^= word_to_code[4] ^ word_to_code[6] ^ word_to_code[8] ^ word_to_code[10];
        for(int i = 11; i <= 25; i +=2)
            aux_0 ^= word_to_code[i];
        for(int i = 26; i <= 56; i +=2)
            aux_0 ^= word_to_code[i];
        for(int i = 57; i <= 119; i +=2)
            aux_0 ^= word_to_code[i];
        for(int i = 120; i <= 246; i +=2)
            aux_0 ^= word_to_code[i];
        for(int i = 247; i <= 501; i +=2)
            aux_0 ^= word_to_code[i];
        for(int i = 502; i <= 511; i +=2)
            aux_0 ^= word_to_code[i];
        coded_word[0] = aux_0;
    end
    always_comb begin : parity1
        aux_1 = word_to_code[0];
        aux_1 ^= (^word_to_code[3:2]);
        aux_1 ^= (^word_to_code[6:5]) ^ (^word_to_code[10:9]);
        for(int i = 12; i <= 25; i +=4)
            aux_1 ^= (^word_to_code[i+1:i]);
        for(int i = 27; i <= 56; i +=4)
            aux_1 ^= (^word_to_code[i+1:i]);
        for(int i = 58; i <= 119; i +=4)
            aux_1 ^= (^word_to_code[i+1:i]);
        for(int i = 121; i <= 246; i +=4)
            aux_1 ^= word_to_code[i+1:i];
        for(int i = 248; i <= 501; i +=4)
            aux_1 ^= word_to_code[i+1:i];
        coded_word[1] = aux_1 ^ (^word_to_code[504:503]) ^ (^word_to_code[508:507]) ^ word_to_code[511];
    end
        always_comb begin : parity3
        aux_3 = ^word_to_code[3:1];
        aux_3 ^= (^word_to_code[10:7]);
        aux_3 ^= (^word_to_code[17:14]) ^ (^word_to_code[25:22]);
        for(int i = 29; i <= 56; i +=8)
            aux_3 ^= (^word_to_code[i+3:i]);
        for(int i = 60; i <= 119; i +=8)
            aux_3 ^= (^word_to_code[i+3:i]);
        for(int i = 123; i <= 246; i +=8)
            aux_3 ^= (^word_to_code[i+3:i]);
        for(int i = 250; i <= 501; i +=8)
            aux_3 ^= (^word_to_code[i+3:i]);
        
        coded_word[3] = aux_3 ^ (^word_to_code[508:505]);
    end
    always_comb begin
        //Direct correspondece with the input
        coded_word[2]       <= word_to_code[0];
        coded_word[6:4]     <= word_to_code[3:1];
        coded_word[14:8]    <= word_to_code[10:4];
        coded_word[30:16]   <= word_to_code[25:11];
        coded_word[62:32]   <= word_to_code[56:26];
        coded_word[126:64]  <= word_to_code[119:57];
        coded_word[254:128] <= word_to_code[246:120];
        coded_word[510:256] <= word_to_code[501:247];
        coded_word[521:512] <= word_to_code[511:502];
        //Hamming bits
        coded_word[7]       <= (^word_to_code[10:4]) ^ (^word_to_code[25:18]) ^ (^word_to_code[40:33]) ^ (^word_to_code[56:49]) ^
                              (^word_to_code[71:64]) ^ (^word_to_code[87:80]) ^ (^word_to_code[103:96]) ^ (^word_to_code[119:112]) ^
                              (^word_to_code[134:127]) ^ (^word_to_code[150:143]) ^ (^word_to_code[166:159]) ^ (^word_to_code[182:175]) ^
                              (^word_to_code[198:191]) ^ (^word_to_code[214:217]) ^ (^word_to_code[230:223]) ^ (^word_to_code[246:239]) ^
                              (^word_to_code[261:254]) ^ (^word_to_code[277:270]) ^ (^word_to_code[293:286]) ^ (^word_to_code[309:302]) ^
                              (^word_to_code[325:318]) ^ (^word_to_code[341:334]) ^ (^word_to_code[357:350]) ^ (^word_to_code[373:366]) ^
                              (^word_to_code[389:382]) ^ (^word_to_code[405:398]) ^ (^word_to_code[421:414]) ^ (^word_to_code[437:430]) ^
                              (^word_to_code[453:446]) ^ (^word_to_code[469:462]) ^ (^word_to_code[485:478]) ^ (^word_to_code[501:494]) ^
                              (^word_to_code[511:509]);
        coded_word[15]      <= (^word_to_code[25:11]) ^ (^word_to_code[56:41]) ^ (^word_to_code[87:72]) ^ (^word_to_code[119:104]) ^
                              (^word_to_code[150:135]) ^ (^word_to_code[182:167]) ^ (^word_to_code[214:199]) ^ (^word_to_code[246:231]) ^
                              (^word_to_code[277:262]) ^ (^word_to_code[309:294]) ^ (^word_to_code[341:326]) ^ (^word_to_code[373:358]) ^
                              (^word_to_code[405:390]) ^ (^word_to_code[437:422]) ^ (^word_to_code[469:454]) ^ (^word_to_code[501:486]);
        coded_word[31]      <= (^word_to_code[56:26]) ^ (^word_to_code[119:88]) ^ (^word_to_code[182:151]) ^ (^word_to_code[246:215]) ^
                              (^word_to_code[309:278]) ^ (^word_to_code[373:342]) ^ (^word_to_code[437:406]) ^ (^word_to_code[501:470]);
        coded_word[63]      <= (^word_to_code[119:57]) ^ (^word_to_code[246:183]) ^ (^word_to_code[373:310]) ^ (^word_to_code[501:438]);
        coded_word[127]     <= (^word_to_code[246:120]) ^ (^word_to_code[501:374]);        
        coded_word[255]     <= ^word_to_code[501:247];        
        coded_word[511]     <= ^word_to_code[511:502];
    end

endmodule
