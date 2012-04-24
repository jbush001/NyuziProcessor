//
// Send a response on the CPI interface
// - Cache Read Hit: send an acknowledgement.
// - Cache Write Hit: send an acknowledgement and the new contents
//   of the line.  If there are lines in other cores that match,
//   need to send write updates for those.  
// - Cache miss: don't send anything.
//

module l2_cache_response(
	input						clk,

	input 			wr_pci_valid,
	input [1:0]	wr_pci_unit,
	input [1:0]	wr_pci_strand,
	input [2:0]	wr_pci_op,
	input [1:0]	wr_pci_way,
	input [511:0]	wr_data,
	input wr_dir_valid,
	input [1:0] wr_dir_way,
	input wr_cache_hit,
	input wr_has_sm_data,
	output reg					cpi_valid = 0,
	output reg					cpi_status = 0,
	output reg[1:0]				cpi_unit = 0,
	output reg[1:0]				cpi_strand = 0,
	output reg[1:0]				cpi_op = 0,
	output reg					cpi_update = 0,
	output reg[1:0]				cpi_way = 0,
	output reg[511:0]			cpi_data = 0);

	reg[1:0] response_op = 0;

	always @*
	begin
		case (wr_pci_op)
			`PCI_LOAD: response_op = `CPI_LOAD_ACK;
			`PCI_STORE: response_op = `CPI_STORE_ACK;
			`PCI_FLUSH: response_op = 0;
			`PCI_INVALIDATE: response_op = 0;
			`PCI_LOAD_SYNC: response_op = `CPI_LOAD_ACK;
			`PCI_STORE_SYNC: response_op = `CPI_STORE_ACK;
			default: response_op = 0;
		endcase
	end

	always @(posedge clk)
	begin
		if (wr_pci_valid)
			$display("stg4: op = %d", wr_pci_op);

		if (wr_pci_valid && (wr_cache_hit || wr_has_sm_data))
		begin
			cpi_valid <= #1 wr_pci_valid;
			cpi_status <= #1 1;
			cpi_unit <= #1 wr_pci_unit;
			cpi_strand <= #1 wr_pci_strand;
			cpi_op <= #1 response_op;	
			cpi_update <= #1 wr_dir_valid;	
			cpi_way <= #1 wr_dir_way;
			cpi_data <= #1 wr_data;	
		end
		else
			cpi_valid <= #1 0;
	end
endmodule
