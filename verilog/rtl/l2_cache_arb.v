//
// Determines whether a request from a core or a restarted request from
// the system memory interface queue should be pushed down the pipeline.
// The latter always has priority.
//

module l2_cache_arb(
	input						clk,
	input						stall_pipeline,
	input						pci_valid,
	output reg					pci_ack,
	input [1:0]					pci_unit,
	input [1:0]					pci_strand,
	input [2:0]					pci_op,
	input [1:0]					pci_way,
	input [25:0]				pci_address,
	input [511:0]				pci_data,
	input [63:0]				pci_mask,
	input [1:0]					smi_pci_unit,				
	input [1:0]					smi_pci_strand,
	input [2:0]					smi_pci_op,
	input [1:0]					smi_pci_way,
	input [25:0]				smi_pci_address,
	input [511:0]				smi_pci_data,
	input [63:0]				smi_pci_mask,
	input [511:0] 				smi_load_buffer_vec,
	input						smi_data_ready,
	input [1:0]					smi_fill_way,
	output reg					arb_pci_valid = 0,
	output reg[1:0]				arb_pci_unit = 0,
	output reg[1:0]				arb_pci_strand = 0,
	output reg[2:0]				arb_pci_op = 0,
	output reg[1:0]				arb_pci_way = 0,
	output reg[25:0]			arb_pci_address = 0,
	output reg[511:0]			arb_pci_data = 0,
	output reg[63:0]			arb_pci_mask = 0,
	output reg					arb_has_sm_data = 0,
	output reg[511:0]			arb_sm_data = 0,
	output reg[1:0]				arb_sm_fill_way = 0);


	always @(posedge clk)
	begin
		if (!stall_pipeline)
		begin
			if (smi_data_ready)	
			begin
				pci_ack <= #1 0;
				arb_pci_valid <= #1 1'b1;
				arb_pci_unit <= #1 smi_pci_unit;
				arb_pci_strand <= #1 smi_pci_strand;
				arb_pci_op <= #1 smi_pci_op;
				arb_pci_way <= #1 smi_pci_way;
				arb_pci_address <= #1 smi_pci_address;
				arb_pci_data <= #1 smi_pci_data;
				arb_pci_mask <= #1 smi_pci_mask;
				arb_has_sm_data <= #1 1'b1;
				arb_sm_data <= #1 smi_load_buffer_vec;
				arb_sm_fill_way <= #1 smi_fill_way;
			end
			else
			begin
				pci_ack <= #1 pci_valid;	
				arb_pci_valid <= #1 pci_valid;
				arb_pci_unit <= #1 pci_unit;
				arb_pci_strand <= #1 pci_strand;
				arb_pci_op <= #1 pci_op;
				arb_pci_way <= #1 pci_way;
				arb_pci_address <= #1 pci_address;
				arb_pci_data <= #1 pci_data;
				arb_pci_mask <= #1 pci_mask;
				arb_has_sm_data <= #1 0;
				arb_sm_data <= #1 0;
			end
		end
		else
			pci_ack <= #1 0;
	end
endmodule
