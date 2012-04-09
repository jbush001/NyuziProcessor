//
// Queues pending memory stores.  Serializes them and issues to L2 cache.
// Whenever there is a cache load, this checks to see if a store is pending
// for the same request and bypasses the data.
//
// This also tracks synchronized stores.  These get rolled back on the first
// request, since we must wait for a response from the L2 cache to make sure
// the L1 cache line has proper data in it.  When the strand is restarted, we 
// need to keep track of the fact that we already got an L2 ack and let the 
// strand continue lest we get into an infinite rollback loop.
//

`include "l2_cache.h"

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
	input							synchronized_i,
	input [63:0]					mask_i,
	input [1:0]						strand_i,
	output reg[511:0]				data_o = 0,
	output reg[63:0]				mask_o = 0,
	output 							rollback_o,
	output							pci_valid_o,
	input							pci_ack_i,
	output [1:0]					pci_unit_o,
	output [1:0]					pci_strand_o,
	output [2:0]					pci_op_o,
	output [1:0]					pci_way_o,
	output [25:0]					pci_address_o,
	output [511:0]					pci_data_o,
	output [63:0]					pci_mask_o,
	input 							cpi_valid_i,
	input							cpi_status_i,
	input [1:0]						cpi_unit_i,
	input [1:0]						cpi_strand_i,
	input [1:0]						cpi_op_i,
	input 							cpi_update_i,
	input [1:0]						cpi_way_i,
	input [511:0]					cpi_data_i);
	
	localparam						STBUF_UNIT = 2;
	
	reg								store_enqueued[0:3];
	reg								store_acknowledged[0:3];
	reg[511:0]						store_data[0:3];
	reg[63:0]						store_mask[0:3];
	reg [TAG_WIDTH - 1:0] 			store_tag[0:3];
	reg [SET_INDEX_WIDTH - 1:0]		store_set[0:3];
	reg								store_synchronized[0:3];
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
	reg[3:0]						sync_store_wait = 0;
	reg[3:0]						sync_store_complete = 0;
	reg								stbuf_full = 0;
	reg[3:0]						sync_store_result = 0;

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
			store_synchronized[i] = 0;
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
				&& strand_i == j)
			begin
				raw_mask_nxt = store_mask[j];
				raw_data_nxt = store_data[j];
			end
		end
	end

	always @(posedge clk)
	begin
		if (synchronized_i && write_i)
		begin
			// Synchronized store
			mask_o <= #1 {64{1'b1}};
			data_o <= #1 {16{31'd0, sync_store_result[strand_i]}};
		end
		else
		begin
			mask_o <= #1 raw_mask_nxt;
			data_o <= #1 raw_data_nxt;
		end
	end

	assign store_update_o = |store_finish_strands && cpi_update_i;
	
	// We always delay this a cycle so it will occur after a suspend.
	always @(posedge clk)
	begin
		resume_strands_o <= #1 (store_finish_strands & store_wait_strands)
			| (l2_ack_mask & sync_store_wait);
	end
	
	// Check if we need to roll back a strand because the store buffer is 
	// full.  Track which strands are waiting and provide an output
	// signal.
	always @(posedge clk)
	begin
		if (write_i && store_enqueued[strand_i] && !store_collision)
		begin
			// Buffer is full, strand needs to wait
			store_wait_strands <= #1 (store_wait_strands & ~store_finish_strands)
				| (1 << strand_i);
			stbuf_full <= #1 1;
		end
		else
		begin
			store_wait_strands <= store_wait_strands & ~store_finish_strands;
			stbuf_full <= #1 0;
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

	assign pci_op_o = store_synchronized[issue_entry] ? `PCI_STORE_SYNC : `PCI_STORE;	
	assign pci_unit_o = STBUF_UNIT;
	assign pci_strand_o = issue_entry;
	assign pci_data_o = store_data[issue_entry];
	assign pci_address_o = { store_tag[issue_entry], store_set[issue_entry] };
	assign pci_mask_o = store_mask[issue_entry];
	assign pci_way_o = 0;	// Ignored by L2 cache (It knows the way from its directory)
	assign pci_valid_o = wait_for_l2_ack;

	wire l2_store_complete = cpi_valid_i && cpi_unit_i == STBUF_UNIT && store_enqueued[cpi_strand_i];
	wire store_collision = l2_store_complete && write_i && strand_i == cpi_strand_i;

	assertion #("L2 responded to store buffer entry that wasn't issued") a0
		(.clk(clk), .test(cpi_valid_i && cpi_unit_i == STBUF_UNIT
			&& !store_enqueued[cpi_strand_i]));
	assertion #("L2 responded to store buffer entry that wasn't acknowledged") a1
		(.clk(clk), .test(cpi_valid_i && cpi_unit_i == STBUF_UNIT
			&& !store_acknowledged[cpi_strand_i]));

	// XXX is store_update_set_o don't care if store_finish_strands is 0?
	// if so, avoid instantiating a mux for it.
	always @*
	begin
		if (cpi_valid_i && cpi_unit_i == STBUF_UNIT)
		begin
			store_finish_strands = 1 << cpi_strand_i;
			store_update_set_o = store_set[cpi_strand_i];
		end
		else
		begin
			store_finish_strands = 0;
			store_update_set_o = 0;
		end
	end


	wire[3:0] sync_req_mask = (synchronized_i & write_i & !store_enqueued[strand_i]) ? (1 << strand_i) : 0;
	wire[3:0] l2_ack_mask = (cpi_valid_i && cpi_unit_i == STBUF_UNIT) ? (1 << cpi_strand_i) : 0;
	wire need_sync_rollback = (sync_req_mask & ~sync_store_complete) != 0;
	reg need_sync_rollback_latched = 0;

	assertion #("blocked strand issued sync store") a2(
		.clk(clk), .test((sync_store_wait & sync_req_mask) != 0));
	assertion #("store complete and store wait set simultaneously") a3(
		.clk(clk), .test((sync_store_wait & sync_store_complete) != 0));
	
	assign rollback_o = stbuf_full || need_sync_rollback_latched;

	always @(posedge clk)
	begin
		// Handle enqueueing new requests.  If a synchronized write has not
		// been acknowledged, queue it, but if we've already received an
		// acknowledgement, just return the proper value.
		if (write_i && (!store_enqueued[strand_i] || store_collision)
			&& (!synchronized_i || need_sync_rollback))
		begin
			store_tag[strand_i] <= #1 tag_i;	
			store_set[strand_i] <= #1 set_i;
			store_mask[strand_i] <= #1 mask_i;
			store_enqueued[strand_i] <= #1 1;
			store_data[strand_i] <= #1 data_i;
			store_synchronized[strand_i] <= #1 synchronized_i;
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
				store_enqueued[cpi_strand_i] <= #1 0;

			store_acknowledged[cpi_strand_i] <= #1 0;
		end

		// Keep track of synchronized stores
		sync_store_wait <= #1 (sync_store_wait | (sync_req_mask & ~sync_store_complete)) & ~l2_ack_mask;
		sync_store_complete <= #1 (sync_store_complete | (sync_store_wait & l2_ack_mask)) & ~sync_req_mask;
		if (l2_ack_mask & sync_store_wait)
			sync_store_result[cpi_strand_i] <= cpi_status_i;

		need_sync_rollback_latched <= #1 need_sync_rollback;
	end

	//////// Performance Statistics ////////////
	reg[63:0] store_count = 0;
	always @(posedge clk)
	begin
		if (l2_store_complete)
			store_count <= store_count + 1;
	end

	////////////////////////////////////////////

endmodule
