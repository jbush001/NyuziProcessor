module lane_select_mux(
	input [511:0]			value_i,
	input[3:0]				lane_select_i,
	output reg[31:0]		value_o);
	
	initial
		value_o = 0;
	
	always @*
	begin
		case (lane_select_i)
			4'd0:	value_o = value_i[511:480];
			4'd1:	value_o = value_i[479:448];
			4'd2:	value_o = value_i[447:416];
			4'd3:	value_o = value_i[415:384];
			4'd4:	value_o = value_i[383:352];
			4'd5:	value_o = value_i[351:320];
			4'd6:	value_o = value_i[319:288];
			4'd7:	value_o = value_i[287:256];
			4'd8:	value_o = value_i[255:224];
			4'd9:	value_o = value_i[223:192];
			4'd10:	value_o = value_i[191:160];
			4'd11:	value_o = value_i[159:128];
			4'd12:	value_o = value_i[127:96];
			4'd13:	value_o = value_i[95:64];
			4'd14:	value_o = value_i[63:32];
			4'd15:	value_o = value_i[31:0];
		endcase
	end
endmodule