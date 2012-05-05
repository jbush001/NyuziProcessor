//
// Queues up L1 cache read misses, serializes them, and issues requests to the L2 cache.
// Keeps track of pending requests and matches responses from L2 cache.
// Handles case where multiple strands miss on the same line, making sure only
// one request goes to the cache.
// Sends wakeup signals to restart strands who's loads have been satisfied.
//
`include "l2_cache.h"

module load_miss_queue
	#(parameter						UNIT_ID = 2'd0)

	(input							clk,
	input							request_i,
	input							synchronized_i,
	input [`L1_TAG_WIDTH - 1:0]			tag_i,
	input [`L1_SET_INDEX_WIDTH - 1:0]	set_i,
	input [1:0]						victim_way_i,
	input [1:0]						strand_i,
	output reg[3:0]					load_complete_strands_o = 0,
	output reg[`L1_SET_INDEX_WIDTH - 1:0] load_complete_set_o = 0,
	output reg[`L1_TAG_WIDTH - 1:0]		load_complete_tag_o,
	output reg[1:0]					load_complete_way_o,
	output 							pci_valid,
	input							pci_ack,
	output [1:0]					pci_unit,
	output [1:0]					pci_strand,
	output [2:0]					pci_op,
	output [1:0]					pci_way,
	output [25:0]					pci_address,
	output [511:0]					pci_data,
	output [63:0]					pci_mask,
	input 							cpi_valid,
	input [1:0]						cpi_unit,
	input [1:0]						cpi_strand,
	input [1:0]						cpi_op,
	input 							cpi_update,
	input [1:0]						cpi_way,
	input [511:0]					cpi_data);

	reg[3:0]						load_strands[0:3];	// One bit per strand
	reg[`L1_TAG_WIDTH - 1:0] 			load_tag[0:3];
	reg[`L1_SET_INDEX_WIDTH - 1:0]		load_set[0:3];
	reg[1:0]						load_way[0:3];
	reg								load_enqueued[0:3];
	reg								load_acknowledged[0:3];
	reg								load_synchronized[0:3];
	integer							i;
	integer							k;
	reg								load_already_pending = 0;
	reg[1:0]						load_already_pending_entry = 0;
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
			load_synchronized[i] = 0;
		end
		// synthesis translate_on
	end

	assign pci_op = load_synchronized[issue_entry] ? `PCI_LOAD_SYNC : `PCI_LOAD;	
	assign pci_way = load_way[issue_entry];
	assign pci_address = { load_tag[issue_entry], load_set[issue_entry] };
	assign pci_unit = UNIT_ID;
	assign pci_strand = issue_entry;
	assign pci_data = 0;
	assign pci_mask = 0;

	// Load collision CAM
	always @*
	begin
		load_already_pending_entry = 0;
		load_already_pending = 0;
	
		for (k = 0; k < 4; k = k + 1)
		begin
			if (load_enqueued[k] && load_tag[k] == tag_i 
				&& load_set[k] == set_i)
			begin
				load_already_pending_entry = k;
				load_already_pending = 1;
			end
		end
	end

	arbiter4 next_issue(
		.clk(clk),
		.req0_i(load_enqueued[0] & !load_acknowledged[0]),
		.req1_i(load_enqueued[1] & !load_acknowledged[1]),
		.req2_i(load_enqueued[2] & !load_acknowledged[2]),
		.req3_i(load_enqueued[3] & !load_acknowledged[3]),
		.update_lru_i(!wait_for_l2_ack),
		.grant0_o(issue0),
		.grant1_o(issue1),
		.grant2_o(issue2),
		.grant3_o(issue3));
	
	// Low two bits of ID are queue entry
	assign pci_valid = wait_for_l2_ack;

	assertion #("L2 responded to LMQ entry that wasn't issued") a0
		(.clk(clk), .test(cpi_valid && cpi_unit == UNIT_ID
		&& !load_enqueued[cpi_strand]));
	assertion #("L2 responded to LMQ entry that wasn't acknowledged") a1
		(.clk(clk), .test(cpi_valid && cpi_unit == UNIT_ID
		&& !load_acknowledged[cpi_strand]));

	// XXX are load_complete_set_o, load_complete_tag_o and load_complete_way_o
	// 'don't care' if load_complete_strands_o is zero?  If so, don't
	// create an unecessary mux for them.
	always @*
	begin
		if (cpi_valid && cpi_unit == UNIT_ID)
		begin
			load_complete_strands_o = load_strands[cpi_strand];
			load_complete_set_o = load_set[cpi_strand];
			load_complete_tag_o = load_tag[cpi_strand];
			load_complete_way_o = load_way[cpi_strand];
		end
		else
		begin
			load_complete_strands_o = 0;
			load_complete_set_o = 0;
			load_complete_tag_o = 0;
			load_complete_way_o = 0;
		end
	end
	
	assertion #("queued thread on LMQ twice") a3(.clk(clk),
		.test(request_i && !load_already_pending && load_enqueued[strand_i]));
	assertion #("load collision on non-pending entry") a4(.clk(clk),
		.test(request_i && load_already_pending && !load_enqueued[load_already_pending_entry]));

	always @(posedge clk)
	begin
		// Handle enqueueing new requests
		if (request_i)
		begin
			// Note that a synchronized load is a separate command, so we never
			// piggyback it on an existing load.
			if (load_already_pending && !synchronized_i)
			begin
				// Update an existing entry.
				load_strands[load_already_pending_entry] <= #1 load_strands[load_already_pending_entry] 
					| (4'b0001 << strand_i);
			end
			else
			begin
				// Send a new request.
				load_synchronized[strand_i] <= #1 synchronized_i;
				load_tag[strand_i] <= #1 tag_i;	
				load_set[strand_i] <= #1 set_i;

				// This is a but subtle.
				// If a load is already pending (which would only happen if
				// we are doing a synchronized load), we must use the way that is 
				// already queued in that one.  Otherwise use the newly 
				// allocated way.
				if (load_already_pending)
					load_way[strand_i] <= #1 load_way[load_already_pending_entry];
				else
					load_way[strand_i] <= #1 victim_way_i;

				load_enqueued[strand_i] <= #1 1;
				load_strands[strand_i] <= #1 (4'b0001 << strand_i);
			end
		end

		if (wait_for_l2_ack)
		begin
			// L2 send is waiting for an ack
		
			if (pci_ack)
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

		if (cpi_valid && cpi_unit == UNIT_ID && load_enqueued[cpi_strand])
		begin
			load_enqueued[cpi_strand] <= #1 0;
			load_acknowledged[cpi_strand] <= #1 0;
		end
	end

	/////////////////////////////////////////////////
	// Validation
	/////////////////////////////////////////////////

	reg[3:0] _debug_strands;
	integer _debug_index;
	integer m;
	integer entry_available;
	
	// synthesis translate_off
	always @(posedge clk)
	begin
		// Ensure a strand is not marked waiting on multiple entries	
		_debug_strands = 0;
		for (_debug_index = 0; _debug_index < 4; _debug_index = _debug_index + 1)
		begin
			if (load_enqueued[_debug_index])
			begin
				if (_debug_strands & load_strands[_debug_index])
				begin
					$display("Error: a strand is marked waiting on multiple load queue entries %b", 
						_debug_strands & load_strands[_debug_index]);
					$finish;
				end

				_debug_strands = _debug_strands | load_strands[_debug_index];
			end
		end	
	end

	// synthesis translate_on


endmodule
