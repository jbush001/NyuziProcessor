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
    logic out_error;
    logic out_corrected;
    cache_line_data_t out_word;

    hamming_512b_checker dut(
        .clk (clk),
        .reset (reset),
        .coded_word(in_word),
        .error(out_error),
        .corrected(out_corrected),
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
      //8 -> The 4th bit flipped, should be corrected to 0
      in_word = 524'h8;
      #20;
      if (out_word != 512'h0) begin
        $error("Error correcting 8");
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
      //C -> The 3rd and 4th bits flipped. Not correctable, just detectable
      in_word = 524'hC;
      #20;
      if (out_word == 512'h0) begin
        $error("Error decoding 0");
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
      in_word = 524'hC;
      #20;
    end
endmodule