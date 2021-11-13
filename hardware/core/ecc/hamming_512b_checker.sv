`include "defines.svh"

import defines::*;

module hamming_512b_checker(
    input                             clk,
    input                             reset,
    // From thread_select_stage
    input hamming_512b_t              coded_word,
    output logic                      error, //1 = we detected one or more errors
    output logic                      corrected, //1 = the errors were corrected
    output hamming_512b_t             correct_word_hamming, //The hamming code after applying the corrections
    output cache_line_data_t          correct_word); //The word without hamming after applying the corrections

    cache_line_data_t useful_data;
    cache_line_data_t corrected_data;
    hamming_512b_t corrected_data_hamming;
    hamming_512b_t useful_data_hamming;
    logic [9:0]syndrome;
    logic [9:0]syn1; //From the input word
    logic [9:0]syn2; //Encoding the useful data from the input word
    logic parity;
    logic [1:0]error_type; //00 = No error, 11 = Single Error Correctable, 
                           //10 = Double error no correctable, 01 = Only the parity bit is wrong                     
    
    hamming_512b_encoder hamming_encoder(
        .clk          (clk),
        .reset        (reset),
        .word_to_code (useful_data),
        .coded_word   (useful_data_hamming)
    );

    always_comb begin : error_detection
        useful_data = {coded_word[521:512], coded_word[510:256], coded_word[254:128],
                       coded_word[126:64], coded_word[62:32], coded_word[30:16],
                       coded_word[14:8], coded_word[6:4], coded_word[2]};
        syn1 = {coded_word[511], coded_word[255], coded_word[127], coded_word[63], coded_word[31],
                coded_word[15], coded_word[7], coded_word[3], coded_word[1], coded_word[0]};
        syn2 = {useful_data_hamming[511], useful_data_hamming[255], useful_data_hamming[127],
                useful_data_hamming[63], useful_data_hamming[31], useful_data_hamming[15],
                useful_data_hamming[7], useful_data_hamming[3], useful_data_hamming[1],
                useful_data_hamming[0]};
        syndrome = syn1 ^ syn2;
        parity = coded_word[522] ^ useful_data_hamming[522];
        error_type[0] = parity;
        error_type[1] = |syndrome;        
    end
    
    int unsigned pos;
    always_comb begin : error_correction
        pos = syndrome;
        corrected_data_hamming = coded_word;
        corrected_data_hamming[pos-1] = ~(coded_word[pos-1]);
        corrected_data = {corrected_data_hamming[521:512], corrected_data_hamming[510:256], corrected_data_hamming[254:128],
                          corrected_data_hamming[126:64], corrected_data_hamming[62:32], corrected_data_hamming[30:16],
                          corrected_data_hamming[14:8], corrected_data_hamming[6:4], corrected_data_hamming[2]};
    end

    assign error = |error_type;
    assign corrected = &error_type;
    assign correct_word = (error_type == 2'b11) ? corrected_data : useful_data;
    assign correct_word_hamming = (error_type == 2'b11) ? corrected_data_hamming : useful_data_hamming;

endmodule
