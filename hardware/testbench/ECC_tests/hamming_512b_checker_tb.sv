`include "defines.svh"

import defines::*;

module hamming_checker_tb();

    logic clk, reset;

  	initial begin
  		$dumpfile("dump.vcd");
  		$dumpvars;
  		#10000 
  		$finish;
	end  
  
  initial begin
        clk = 0;
        reset = 0;
    end

    hamming_512b_t in_word;
    hamming_512b_t out_word_hamming;
    logic out_error;
    logic out_corrected;
    cache_line_data_t out_word;

    hamming_512b_checker dut(
        .clk (clk),
        .reset (reset),
        .coded_word(in_word),
        .error(out_error),
        .corrected(out_corrected),
        .correct_word_hamming(out_word_hamming),
        .correct_word(out_word)
    );

    initial begin
      in_word = 524'h0;
      #20;
      if (out_word != 512'h0) begin
        $error("Error decoding 0");
        $displayh("Value of in_word: %h", in_word);
        $displayh("Value of out_word: %h", out_word);
        $display("Error: %b  Corrected: %b", out_error, out_corrected);
      end
      //4 -> The 3rd bit flipped, should be corrected to 0
      in_word = 524'h4;
      #20;
      if (out_word != 512'h0) begin
        $error("Error correcting 4");
        $displayh("Value of in_word: %h", in_word);
        $displayh("Value of out_word: %h", out_word);
        $display("Error: %b  Corrected: %b", out_error, out_corrected);
        if (!out_error) begin
          $error("Error in the error signal");
          $displayh("Value of in_word: %h", in_word);
          $displayh("Value of out_word: %h", out_word);
          $display("Error: %b  Corrected: %b", out_error, out_corrected);
        end
        if (!out_corrected) begin
          $error("Error in the corrected signal");
          $displayh("Value of in_word: %h", in_word);
          $displayh("Value of out_word: %h", out_word);
          $display("Error: %b  Corrected: %b", out_error, out_corrected);
        end
      end
      //10 -> The 5th bit flipped, should be corrected to 0
      in_word = 524'h10;
      #20;
      if (out_word != 512'h0) begin
        $error("Error correcting 10");
        $displayh("Value of in_word: %h", in_word);
        $displayh("Value of out_word: %h", out_word);
        $display("Error: %b  Corrected: %b", out_error, out_corrected);
        if (!out_error) begin
          $error("Error in the error signal");
          $displayh("Value of in_word: %h", in_word);
          $displayh("Value of out_word: %h", out_word);
          $display("Error: %b  Corrected: %b", out_error, out_corrected);
        end
        if (!out_corrected) begin
          $error("Error in the corrected signal");
          $displayh("Value of in_word: %h", in_word);
          $displayh("Value of out_word: %h", out_word);
          $display("Error: %b  Corrected: %b", out_error, out_corrected);
        end
      end
      //14 -> The 3rd and 5th bits flipped. Not correctable, just detectable
      in_word = 524'h14;
      #20;
      if (!out_error) begin
        $error("Error detecting an error in 14");
        $displayh("Value of in_word: %h", in_word);
        $displayh("Value of out_word: %h", out_word);
        $display("Error: %b  Corrected: %b", out_error, out_corrected);
      end
      if (out_error && out_corrected) begin
        $error("Error correcting an error in C");
        $displayh("Value of in_word: %h", in_word);
        $displayh("Value of out_word: %h", out_word);
        $display("Error: %b  Corrected: %b", out_error, out_corrected);
      end
      //2 -> The 2nd bit flipped. Only the parity bit is wrong
      in_word = 524'h2;
      #20;
      if (out_word != 512'h0) begin
        $error("Error decoding 0");
        $displayh("Value of in_word: %h", in_word);
        $displayh("Value of out_word: %h", out_word);
        $display("Error: %b  Corrected: %b", out_error, out_corrected);
      end
      if (!out_error) begin
        $error("Error detecting an error in 2");
        $displayh("Value of in_word: %h", in_word);
        $displayh("Value of out_word: %h", out_word);
        $display("Error: %b  Corrected: %b", out_error, out_corrected);
      end
      //Correct encoding for 0x9
      in_word = 524'h4000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000004C;
      #20;
      if (out_word != 512'h9) begin
        $error("Error decoding 9");
        $displayh("Value of in_word: %h", in_word);
        $displayh("Value of out_word: %h", out_word);
        $display("Error: %b  Corrected: %b", out_error, out_corrected);
      end
      //Correct encoding for 0xF
      in_word = 524'h4000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000007F;
      #20;
      if (out_word != 512'hF) begin
        $error("Error decoding F");
        $displayh("Value of in_word: %h", in_word);
        $displayh("Value of out_word: %h", out_word);
        $display("Error: %b  Corrected: %b", out_error, out_corrected);
      end
      //Correct encoding for 0x10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
      in_word = 524'h4408000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000b;
      #20;
      if (out_word != 512'h10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000) begin
        $error("Error decoding 10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000");
        $displayh("Value of in_word: %h", in_word);
        $displayh("Value of out_word: %h", out_word);
        $display("Error: %b  Corrected: %b", out_error, out_corrected);
      end
      //Correct encoding for 0xAAAA
      in_word = 524'h15AAD9;
      #20;
      if (out_word != 512'hAAAA) begin
        $error("Error decoding AAAA");
        $displayh("Value of in_word: %h", in_word);
        $displayh("Value of out_word: %h", out_word);
        $display("Error: %b  Corrected: %b", out_error, out_corrected);
      end
      //Correct encoding for 0x11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
      in_word = 524'h0442222222222222222222222222222222222222222222222222222222222222222111111111111111111111111111111110888888888888888c444444422221107;
      #20;
      if (out_word != 512'h11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111) begin
        $error("Error decoding 11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111");
        $displayh("Value of in_word: %h", in_word);
        $displayh("Value of out_word: %h", out_word);
        $display("Error: %b  Corrected: %b", out_error, out_corrected);
      end
      //The overall parity bit flipped
      in_word = 524'h40000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
      #20;
      if (!out_error || (out_error && out_corrected)) begin
        $error("Error detecting an error in overall parity bit");
        $displayh("Value of in_word: %h", in_word);
        $displayh("Value of out_word: %h", out_word);
        $display("Error: %b  Corrected: %b", out_error, out_corrected);
      end
    end
endmodule