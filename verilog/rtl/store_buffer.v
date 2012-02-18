//
// Queue pending stores.
//

module store_buffer
	#(parameter						TAG_WIDTH = 21,
	parameter						SET_INDEX_WIDTH = 5,
	parameter						WAY_INDEX_WIDTH = 2)

	(input 							clk,
	output reg[3:0]					resume_strands_o = 0,
	output							store_update_o,
	output reg[SET_INDEX_WIDTH - 1:0] store_update_set_o = 0,
	input [TAG_WIDTH - 1:0]			tag_i,
	input [SET_INDEX_WIDTH - 1:0]	set_i,
	input [511:0]					data_i,
	input							write_i,
	input [63:0]					mask_i,
	input [1:0]						strand_id_i,
	output reg[511:0]				data_o = 0,
	output reg[63:0]				mask_o = 0,
	output reg						full_o = 0,
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
	
	parameter						STBUF_ID = 2;
	
	reg								store_enqueued[0:3];
	reg								store_acknowledged[0:3];
	reg[511:0]						store_data[0:3];
	reg[63:0]						store_mask[0:3];
	reg [TAG_WIDTH - 1:0] 			store_tag[0:3];
	reg [SET_INDEX_WIDTH - 1:0]		store_set[0:3];
	reg[1:0]						issue_entry = 0;
	reg								wait_for_l2_ack = 0;
	wire							issue0;
	wire							issue1;
	wire							issue2;
	wire							issue3;
	reg[3:0]						store_wait_strands = 0;
	integer							i;
	reg[3:0]						store_finish_strands = 0;
	integer							j;
	reg[63:0]						raw_mask_nxt = 0;
	reg[511:0]						raw_data_nxt = 0;

	initial
	begin
		// synthesis translate_off
		for (i = 0; i < 4; i = i + 1)
		begin
			store_enqueued[i] = 0;
			store_acknowledged[i] = 0;
			store_data[i] = 0;
			store_mask[i] = 0;
			store_tag[i] = 0;
			store_set[i] = 0;
		end
		// synthesis translate_on
	end
		
	// Store RAW handling. We only bypass results from the same strand.
	always @*
	begin
		raw_mask_nxt = 0;		
		raw_data_nxt = 0;

		for (j = 0; j < 4; j = j + 1)
		begin
			if (store_enqueued[j] && set_i == store_set[j] && tag_i == store_tag[j]
				&& strand_id_i == j)
			begin
				raw_mask_nxt = store_mask[j];
				raw_data_nxt = store_data[j];
			end
		end
	end

	always @(posedge clk)
	begin
		mask_o <= #1 raw_mask_nxt;
		data_o <= #1 raw_data_nxt;
	end

	assign store_update_o = |store_finish_strands && cpi_allocate_i;
	
	// We always delay this a cycle so it will occur after a suspend.
	always @(posedge clk)
		resume_strands_o <= #1 store_finish_strands & store_wait_strands;
		
	// Check if we need to roll back a strand because the store buffer is 
	// full.  Track which strands are waiting and provide an output
	// signal.
	always @(posedge clk)
	begin
		if (write_i && store_enqueued[strand_id_i] && !store_collision)
		begin
			// Buffer is full, strand needs to wait
			store_wait_strands <= #1 (store_wait_strands & ~store_finish_strands)
				| (1 << strand_id_i);
			full_o <= #1 1;
		end
		else
		begin
			store_wait_strands <= store_wait_strands & ~store_finish_strands;
			full_o <= #1 0;
		end
	end

	arbiter4 next_issue(
		.clk(clk),
		.req0_i(store_enqueued[0] & !store_acknowledged[0]),
		.req1_i(store_enqueued[1] & !store_acknowledged[1]),
		.req2_i(store_enqueued[2] & !store_acknowledged[2]),
		.req3_i(store_enqueued[3] & !store_acknowledged[3]),
		.update_lru_i(!wait_for_l2_ack),
		.grant0_o(issue0),
		.grant1_o(issue1),
		.grant2_o(issue2),
		.grant3_o(issue3));

	assign pci_op_o = 1;	// We only ever store
	assign pci_id_o = 8 | issue_entry;
	assign pci_data_o = store_data[issue_entry];
	assign pci_address_o = { store_tag[issue_entry], store_set[issue_entry] };
	assign pci_mask_o = store_mask[issue_entry];
	assign pci_way_o = 0;	// Ignored by L2 cache (It knows the way from its directory)
	assign pci_valid_o = wait_for_l2_ack;

	wire[1:0] cpi_entry = cpi_id_i[1:0];

	wire l2_store_complete = cpi_valid_i && cpi_id_i[3:2] == STBUF_ID && store_enqueued[cpi_entry];
	wire store_collision = l2_store_complete && write_i && strand_id_i == cpi_entry;

	always @*
	begin
		if (cpi_valid_i && cpi_id_i[3:2] == STBUF_ID && store_enqueued[cpi_entry])
		begin
			// assert store_acknowledged[cpi_entry]
			store_finish_strands = 1 << cpi_entry;
			store_update_set_o = store_set[cpi_entry];
		end
		else
		begin
			store_finish_strands = 0;
			store_update_set_o = 0;
		end
	end

	always @(posedge clk)
	begin
		// Handle enqueueing new requests.
		if (write_i && (!store_enqueued[strand_id_i] || store_collision))
		begin
			store_tag[strand_id_i] <= #1 tag_i;	
			store_set[strand_id_i] <= #1 set_i;
			store_mask[strand_id_i] <= #1 mask_i;
			store_enqueued[strand_id_i] <= #1 1;
			store_data[strand_id_i] <= #1 data_i;
		end

		// Handle L2 responses/issue new requests
		if (wait_for_l2_ack)
		begin
			// L2 send is waiting for an ack
		
			if (pci_ack_i)
			begin
				store_acknowledged[issue_entry] <= #1 1;
				wait_for_l2_ack <= #1 0;	// Can now pick a new entry to issue
			end
		end
		else 
		begin
			// Nothing is currently pending
			if (issue0 || issue1 || issue2 || issue3)	
			begin
				// Note: technically we could issue another request in the same
				// cycle we get an ack, but this will wait until the next cycle.
	
				if (issue0)
					issue_entry <= #1 0;
				else if (issue1)
					issue_entry <= #1 1;
				else if (issue2)
					issue_entry <= #1 2;
				else if (issue3)
					issue_entry <= #1 3;
			
				wait_for_l2_ack <= #1 1;
			end
		end

		if (l2_store_complete)
		begin
			if (!store_collision)
				store_enqueued[cpi_entry] <= #1 0;

			store_acknowledged[cpi_entry] <= #1 0;
		end
	end

endmodule
