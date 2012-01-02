//
// Queue pending stores.
//

module store_buffer
	#(parameter						TAG_WIDTH = 21,
	parameter						SET_INDEX_WIDTH = 5,
	parameter						WAY_INDEX_WIDTH = 2)

	(input 							clk,
	output [3:0]					store_complete_o,
	output [SET_INDEX_WIDTH - 1:0]	store_complete_set_o,
	input [TAG_WIDTH - 1:0]			tag_i,
	input [SET_INDEX_WIDTH - 1:0]	set_i,
	input [511:0]					data_i,
	input							write_i,
	input [63:0]					mask_i,
	output reg[511:0]				data_o = 0,
	output reg[63:0]				mask_o = 0,
	output 							full_o,
	output							pci_valid_o,
	input							pci_ack_i,
	output [3:0]					pci_id_o,
	output [1:0]					pci_op_o,
	output [1:0]					pci_way_o,
	output [25:0]					pci_address_o,
	output [511:0]					pci_data_o,
	output [63:0]					pci_mask_o,
	input 							cpi_valid_i,
	input [3:0]						cpi_id_i,
	input [1:0]						cpi_op_i,
	input 							cpi_allocate_i,
	input [1:0]						cpi_way_i,
	input [511:0]					cpi_data_i);

	parameter						STATE_IDLE = 0;
	parameter						STATE_WAIT_L2_ACK = 1;
	parameter						STATE_L2_ISSUED = 2;

	reg[1:0]						load_state_ff = STATE_IDLE;
	reg[1:0]						load_state_nxt = STATE_IDLE;
	reg[511:0]						store_data = 0;
	reg[63:0]						store_mask = 0;
	reg [TAG_WIDTH - 1:0] 			store_tag = 0;
	reg [SET_INDEX_WIDTH - 1:0]		store_set = 0;

	assign pci_valid_o = load_state_ff == STATE_WAIT_L2_ACK;
	
	// Note that, if we will not be full in the next cycle, go ahead
	// and let someone perform a write
	assign full_o = load_state_ff != STATE_IDLE && !l2_store_complete;

	wire l2_store_complete = load_state_ff == STATE_L2_ISSUED && cpi_valid_i
		&& cpi_id_i[3:2] == 2 && cpi_op_i == 1;	// I am unit 2
	assign store_complete_set_o = store_set;

	always @*
	begin
		load_state_nxt = load_state_ff;
	
		case (load_state_ff)
			STATE_IDLE:
			begin
				if (write_i)
					load_state_nxt = STATE_WAIT_L2_ACK;
			end
			
			STATE_WAIT_L2_ACK:
			begin
				if (pci_ack_i)
					load_state_nxt = STATE_L2_ISSUED;
			end

			STATE_L2_ISSUED:
			begin
				if (l2_store_complete)
					load_state_nxt = STATE_IDLE;
			end
		endcase
	end

	assign pci_op_o = 1;
	assign pci_id_o = 8;
	assign pci_data_o = store_data;
	assign pci_address_o = { store_tag, store_set };
	assign pci_mask_o = store_mask;
	assign pci_way_o = 0;

	always @(posedge clk)
	begin
		// Note that we don't check if the store buffer is full.  If we do,
		// need to handle the case where a wakeup occurs in the same cycle
		// as a write attempt.
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

			store_tag 		<= #1 tag_i;
			store_set 		<= #1 set_i;
			store_data 		<= #1 data_i;
			store_mask		<= #1 mask_i;
		end

		if (set_i == store_tag && tag_i == store_tag && load_state_ff != STATE_IDLE)
			mask_o 			<= #1 store_mask;
		else
			mask_o 			<= #1 0;
			
		load_state_ff <= #1 load_state_nxt;
	end

	assign store_complete_o = {4{l2_store_complete}};
endmodule
