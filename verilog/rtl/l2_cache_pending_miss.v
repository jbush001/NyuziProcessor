//
// Tracks pending cache misses in the L2 cache.
//

module l2_cache_pending_miss
	#(parameter 			QUEUE_SIZE = 8)
	(input					clk,
	input					rd_pci_valid,
	input [25:0]			rd_pci_address,
	input					rd_cache_hit,
	output 					duplicate_request);

	localparam				QUEUE_ADDR_WIDTH = $clog2(QUEUE_SIZE);

	reg[25:0]				miss_address[0:QUEUE_SIZE - 1];
	reg						entry_valid[0:QUEUE_SIZE - 1];
	integer					i;
	integer					search_entry;
	reg[QUEUE_ADDR_WIDTH:0]	cam_hit_entry = 0;
	reg						cam_hit = 0;
	integer					empty_search;
	integer					empty_entry = 0;

	initial
	begin
		for (i = 0; i < QUEUE_SIZE; i = i + 1)
		begin
			miss_address[i] = 0;
			entry_valid[i] = 0;
		end
	end

	assign duplicate_request = cam_hit;

	// Lookup CAM
	always @*
	begin
		cam_hit = 0;
		cam_hit_entry = 0;

		for (search_entry = 0; search_entry < QUEUE_SIZE; search_entry 
			= search_entry + 1)
		begin
			if (entry_valid[search_entry] && miss_address[search_entry] 
				== rd_pci_address)		
			begin
				cam_hit = 1;
				cam_hit_entry = search_entry;
			end
		end
	end

	// Find next empty entry
	always @*
	begin
		empty_entry = 0;
		for (empty_search = 0; empty_search < QUEUE_SIZE; empty_search
			= empty_search + 1)
		begin
			if (!entry_valid[empty_search])
				empty_entry = empty_search;
		end
	end

	// Update CAM
	always @(posedge clk)
	begin
		if (rd_pci_valid)
		begin
			if (cam_hit && rd_cache_hit)
				entry_valid[cam_hit] <= 0;	// Clear pending bit
			else if (!cam_hit && !rd_cache_hit)
			begin
				// Set pending bit
				entry_valid[empty_entry] <= 1;
				miss_address[empty_entry] <= rd_pci_address;
			end
		end
	end
endmodule

