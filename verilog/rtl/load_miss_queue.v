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
	output reg[3:0]					load_complete_strands_o = 0,
	output reg[SET_INDEX_WIDTH - 1:0] load_complete_set_o = 0,
	output reg[TAG_WIDTH - 1:0]		load_complete_tag_o,
	output reg[1:0]					load_complete_way_o,
	output 							pci_valid_o,
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

	reg[3:0]						load_strands[0:3];	// One bit per strand
	reg[TAG_WIDTH - 1:0] 			load_tag[0:3];
	reg[SET_INDEX_WIDTH - 1:0]		load_set[0:3];
	reg[1:0]						load_way[0:3];
	reg								load_enqueued[0:3];
	reg								load_acknowledged[0:3];
	integer							i;
	integer							j;
	integer							k;
	reg[1:0]						first_free_entry = 0;
	reg								load_collision = 0;
	reg[1:0]						load_collision_entry = 0;
	reg[1:0]						issue_entry = 0;		// Which entry was issued
	reg								wait_for_l2_ack = 0;	// We've issued and are waiting for pci ack
	wire							issue0;
	wire							issue1;
	wire							issue2;
	wire							issue3;
	
	initial
	begin
		// synthesis translate_off
		for (i = 0; i < 4; i = i + 1)
		begin
			load_strands[i] = 0;
			load_tag[i] = 0;
			load_set[i] = 0;
			load_way[i] = 0;
			load_enqueued[i] = 0;
			load_acknowledged[i] = 0;
		end
		// synthesis translate_on
	end

	assign pci_op_o = 0;	// We only ever load
	assign pci_way_o = load_way[issue_entry];
	assign pci_address_o = { load_tag[issue_entry], load_set[issue_entry] };
	assign pci_id_o = 4 | issue_entry;
	assign pci_data_o = 0;
	assign pci_mask_o = 0;

	// Find first free entry (priority encoder)
	always @*
	begin
		first_free_entry = 0;
		
		for (j = 3; j >= 0; j = j - 1)
		begin
			if (!load_enqueued[j])
				first_free_entry = j;
		end
	end

	// Load collision CAM
	always @*
	begin
		load_collision_entry = 0;
		load_collision = 0;
	
		for (k = 0; k < 4; k = k + 1)
		begin
			if (load_enqueued[k] && load_tag[k] == tag_i 
				&& load_set[k] == set_i)
			begin
				load_collision_entry = k;
				load_collision = 1;
			end
		end
	end

	arbiter4 next_issue(
		.clk(clk),
		.req0_i(load_enqueued[0] & !load_acknowledged[0]),
		.req1_i(load_enqueued[1] & !load_acknowledged[1]),
		.req2_i(load_enqueued[2] & !load_acknowledged[2]),
		.req3_i(load_enqueued[3] & !load_acknowledged[3]),
		.grant0_o(issue0),
		.grant1_o(issue1),
		.grant2_o(issue2),
		.grant3_o(issue3));
	
	// Low two bits of ID are queue entry
	wire[1:0] cpi_entry = cpi_id_i[1:0];
	assign pci_valid_o = wait_for_l2_ack;


	always @*
	begin
		if (cpi_valid_i && cpi_id_i[3:2] == 1 && load_enqueued[cpi_entry])
		begin
			// assert load_acknowledged[cpi_entry]
			load_complete_strands_o = load_strands[cpi_entry];
			load_complete_set_o = load_set[cpi_entry];
			load_complete_tag_o = load_tag[cpi_entry];
			load_complete_way_o = load_way[cpi_entry];
		end
		else
		begin
			load_complete_strands_o = 0;
			load_complete_set_o = 0;
			load_complete_tag_o = 0;
			load_complete_way_o = 0;
		end
	end

	always @(posedge clk)
	begin
		// Handle enqueueing new requests
		if (request_i)
		begin
			if (load_collision)
			begin
				// Update an existing entry
				load_strands[load_collision_entry] <= #1 load_strands[load_collision_entry] 
					| (1 << strand_i);
			end
			else
			begin
				// Allocate a new entry
				load_tag[first_free_entry] <= #1 tag_i;	
				load_set[first_free_entry] <= #1 set_i;
				load_way[first_free_entry] <= #1 victim_way_i;
				load_enqueued[first_free_entry] <= #1 1;
				load_strands[first_free_entry] <= #1 (1 << strand_i);
			end
		end

		if (wait_for_l2_ack)
		begin
			// L2 send is waiting for an ack
		
			if (pci_ack_i)
			begin
				load_acknowledged[issue_entry] <= #1 1;
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


		if (cpi_valid_i && cpi_id_i[3:2] == 1 && load_enqueued[cpi_entry])
		begin
			load_enqueued[cpi_entry] <= #1 0;
			load_acknowledged[cpi_entry] <= #1 0;
		end
	end

endmodule
