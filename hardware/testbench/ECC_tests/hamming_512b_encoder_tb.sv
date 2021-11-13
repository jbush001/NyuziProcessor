`include "defines.svh"

import defines::*;

module hamming_encoder_tb();

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

    cache_line_data_t in_word;
    hamming_512b_t out_word;

    hamming_encoder dut(
        .clk (clk),
        .reset (reset),
        .word_to_code(in_word),
        .coded_word(out_word)
    );

    initial begin
      in_word = 0;
      #20;
      if (out_word != 522'h0) begin
        $displayh("Value of out_word: %p", out_word);
          $error("Error coding 0");
      end
      in_word = 1;
      #20;
      if (out_word != 524'h40000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000007) begin
        $error("Error coding 1");
        $displayh("Value of in_word: %h", in_word);
        $displayh("Value of out_word: %h", out_word);
      end
      in_word = 512'h2;
      #20;
      if (out_word != 524'h40000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000019) begin
        $error("Error coding 2");
        $displayh("Value of in_word: %h", in_word);
        $displayh("Value of out_word: %h", out_word);
      end
	  in_word = 512'h3;
      #20;
      if (out_word != 524'h0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001E) begin
        $error("Error coding 2");
        $displayh("Value of in_word: %h", in_word);
        $displayh("Value of out_word: %h", out_word);
      end
      in_word = 512'h4;
      #20;
      if (out_word != 524'h4000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002A) begin
        $error("Error coding 2");
        $displayh("Value of in_word: %h", in_word);
        $displayh("Value of out_word: %h", out_word);
      end
      in_word = 512'h5;
      #20;
      if (out_word != 524'h0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002D) begin
        $error("Error coding 2");
        $displayh("Value of in_word: %h", in_word);
        $displayh("Value of out_word: %h", out_word);
      end
      in_word = 512'h6;
      #20;
      if (out_word != 524'h00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000033) begin
        $error("Error coding 2");
        $displayh("Value of in_word: %h", in_word);
        $displayh("Value of out_word: %h", out_word);
      end
      in_word = 512'h7;
      #20;
      if (out_word != 524'h40000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000034) begin
        $error("Error coding 2");
        $displayh("Value of in_word: %h", in_word);
        $displayh("Value of out_word: %h", out_word);
      end
      in_word = 512'h8;
      #20;
      if (out_word != 524'h0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000004B) begin
        $error("Error coding 2");
        $displayh("Value of in_word: %h", in_word);
        $displayh("Value of out_word: %h", out_word);
      end
      in_word = 512'h9;
      #20;
      if (out_word != 524'h4000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000004C) begin
        $error("Error coding 2");
        $displayh("Value of in_word: %h", in_word);
        $displayh("Value of out_word: %h", out_word);
      end
      in_word = 512'hA;
      #20;
      if (out_word != 524'h40000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000052) begin
        $error("Error coding 2");
        $displayh("Value of in_word: %h", in_word);
        $displayh("Value of out_word: %h", out_word);
      end
      in_word = 512'hB;
      #20;
      if (out_word != 524'h00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000055) begin
        $error("Error coding 2");
        $displayh("Value of in_word: %h", in_word);
        $displayh("Value of out_word: %h", out_word);
      end
      in_word = 512'hC;
      #20;
      if (out_word != 524'h40000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000061) begin
        $error("Error coding 2");
        $displayh("Value of in_word: %h", in_word);
        $displayh("Value of out_word: %h", out_word);
      end
      in_word = 512'hD;
      #20;
      if (out_word != 524'h00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000066) begin
        $error("Error coding 2");
        $displayh("Value of in_word: %h", in_word);
        $displayh("Value of out_word: %h", out_word);
      end
      in_word = 512'hE;
      #20;
      if (out_word != 524'h00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000078) begin
        $error("Error coding 2");
        $displayh("Value of in_word: %h", in_word);
        $displayh("Value of out_word: %h", out_word);
      end
      in_word = 512'hF;
      #20;
      if (out_word != 524'h4000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000007F) begin
        $error("Error coding 2");
        $displayh("Value of in_word: %h", in_word);
        $displayh("Value of out_word: %h", out_word);
      end
    end
endmodule