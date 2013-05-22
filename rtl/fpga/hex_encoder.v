module hex_encoder(
	output reg[6:0] encoded,
	input [3:0] value);

	always @*
	begin
		case (value)
			'h0: encoded = 7'b0111111;
			'h1: encoded = 7'b1111001;
			'h2: encoded = 7'b0100100;
			'h3: encoded = 7'b0110000;
			'h4: encoded = 7'b0011001;
			'h5: encoded = 7'b0010010;
			'h6: encoded = 7'b0000010;
			'h7: encoded = 7'b1111000;
			'h8: encoded = 7'b0000000;
			'h9: encoded = 7'b0010000;
			'hA: encoded = 7'b0001000;
			'hB: encoded = 7'b0000011;
			'hC: encoded = 7'b1000110;
			'hD: encoded = 7'b0100001;
			'hE: encoded = 7'b0000110;
			'hF: encoded = 7'b0001110;
		endcase	
	end
endmodule
