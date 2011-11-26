//
// Queue pending stores.
//

module store_buffer
	#(parameter ADDR_SIZE = 26)
	(input 						clk,
	input [ADDR_SIZE - 1:0]		addr_i,
	input [511:0]				data_i,
	input						write_i,
	input [63:0]				mask_i,
	output reg[511:0]			data_o,
	output reg[63:0]			mask_o,
	output 						full_o,
	
	output 						l2_write_o,
	input						l2_ack_i,
	output reg[ADDR_SIZE - 1:0] l2_addr_o,
	output reg[511:0]			l2_data_o,
	output reg[63:0]			l2_mask_o);

	reg							store_latched;

	assign l2_write_o = store_latched;
	assign full_o = store_latched && !l2_ack_i;

	initial
	begin
		data_o = 0;
		mask_o = 0;
		l2_addr_o = 0;
		l2_data_o = 0;
		l2_mask_o = 0;
		store_latched = 0;
	end

	always @(posedge clk)
	begin
		if (write_i)
		begin
			// Debug
			// synthesis translate_off
			if (full_o)
			begin
				$display("Error: write to full store buffer");
				$finish;
			end
			// synthesis translate_on

			l2_addr_o 		<= #1 addr_i;
			l2_data_o 		<= #1 data_i;
			l2_mask_o		<= #1 mask_i;
			store_latched	<= #1 1;
		end
		else if (l2_ack_i)
			store_latched 	<= #1 0;

		data_o 				<= #1 l2_data_o;
		if (addr_i == l2_addr_o)
			mask_o 			<= #1 l2_mask_o;
		else
			mask_o 			<= #1 0;
	end
endmodule
