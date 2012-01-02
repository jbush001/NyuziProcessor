module load_miss_queue
	#(parameter						TAG_WIDTH = 21,
	parameter						SET_INDEX_WIDTH = 5,
	parameter						WAY_INDEX_WIDTH = 2)

	(input							clk,
	input							request_i,
	input [TAG_WIDTH - 1:0]			tag_i,
	input [SET_INDEX_WIDTH - 1:0]	set_i,
	input [1:0]						victim_way_i,
	input [1:0]						strand_i,
	output [3:0]					load_complete_o,
	output [SET_INDEX_WIDTH - 1:0]	load_complete_set_o,
	output [TAG_WIDTH - 1:0]		load_complete_tag_o,
	output [1:0]					load_complete_way_o,
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

	reg [TAG_WIDTH - 1:0] 			load_tag = 0;
	reg [SET_INDEX_WIDTH - 1:0]		load_set = 0;
	reg [1:0]						load_way = 0;
	reg[1:0]						load_state_ff = STATE_IDLE;
	reg[1:0]						load_state_nxt = STATE_IDLE;
	
	assign pci_op_o = 0;
	assign pci_way_o = load_way;
	assign pci_address_o = { load_tag, load_set };
	assign pci_valid_o = load_state_ff == STATE_WAIT_L2_ACK;
	assign pci_id_o = 4;
	assign pci_data_o = 0;
	assign pci_mask_o = 0;

	assign load_complete_set_o = load_set;
	assign load_complete_tag_o = load_tag;
	assign load_complete_way_o = load_way;

	always @(posedge clk)
	begin
		if (request_i && load_state_ff == STATE_IDLE)
		begin
			load_tag <= #1 tag_i;	
			load_set <= #1 set_i;
			load_way <= #1 victim_way_i;
		end
		
		load_state_ff <= #1 load_state_nxt;
	end

	wire l2_load_complete = load_state_ff == STATE_L2_ISSUED && cpi_valid_i
		&& cpi_id_i[3:2] == 1 && cpi_op_i == 0;	// I am unit 1

	always @*
	begin
		load_state_nxt = load_state_ff;
	
		case (load_state_ff)
			STATE_IDLE:
			begin
				if (request_i)
					load_state_nxt = STATE_WAIT_L2_ACK;
			end

			STATE_WAIT_L2_ACK:
			begin
				if (pci_ack_i)
					load_state_nxt = STATE_L2_ISSUED;
			end

			STATE_L2_ISSUED:
			begin
				if (l2_load_complete)
					load_state_nxt = STATE_IDLE;
			end
		endcase
	end

	assign load_complete_o = {4{l2_load_complete}};
endmodule
