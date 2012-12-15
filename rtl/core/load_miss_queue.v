// 
// Copyright 2011-2012 Jeff Bush
// 
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
// 
//     http://www.apache.org/licenses/LICENSE-2.0
// 
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
// 

`include "l2_cache.h"

//
// Queues up L1 cache read misses and issues requests to the L2 cache.
// Tracks pending requests and matches responses from L2 cache.
// Handles case where multiple strands miss on the same line, making sure only
// one request goes to the cache.
// Sends wakeup signals to restart strands who's loads have been satisfied.
//

module load_miss_queue
	#(parameter						UNIT_ID = 2'd0)

	(input							clk,
	input							reset,
	input							request_i,
	input							synchronized_i,
	input [`L1_TAG_WIDTH - 1:0]			tag_i,
	input [`L1_SET_INDEX_WIDTH - 1:0]	set_i,
	input [1:0]						victim_way_i,
	input [1:0]						strand_i,
	output reg[3:0]					load_complete_strands_o,
	output reg[`L1_SET_INDEX_WIDTH - 1:0] load_complete_set,
	output reg[`L1_TAG_WIDTH - 1:0]		load_complete_tag,
	output reg[1:0]					load_complete_way,
	output 							l2req_valid,
	input							l2req_ready,
	output [1:0]					l2req_unit,
	output [1:0]					l2req_strand,
	output [2:0]					l2req_op,
	output [1:0]					l2req_way,
	output [25:0]					l2req_address,
	output [511:0]					l2req_data,
	output [63:0]					l2req_mask,
	input 							l2rsp_valid,
	input [1:0]						l2rsp_unit,
	input [1:0]						l2rsp_strand);

	reg[3:0]						load_strands[0:3];	// One bit per strand
	reg[`L1_TAG_WIDTH - 1:0] 		load_tag[0:3];
	reg[`L1_SET_INDEX_WIDTH - 1:0]	load_set[0:3];
	reg[1:0]						load_way[0:3];
	reg								load_enqueued[0:3];
	reg								load_acknowledged[0:3];
	reg								load_synchronized[0:3];
	integer							i;
	integer							k;
	reg								load_already_pending;
	reg[1:0]						load_already_pending_entry;
	wire[1:0]						issue_idx;
	wire[3:0]						issue_oh;

	assign l2req_op = load_synchronized[issue_idx] ? `L2REQ_LOAD_SYNC : `L2REQ_LOAD;	
	assign l2req_way = load_way[issue_idx];
	assign l2req_address = { load_tag[issue_idx], load_set[issue_idx] };
	assign l2req_unit = UNIT_ID;
	assign l2req_strand = issue_idx;
	assign l2req_data = 0;
	assign l2req_mask = 0;

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

	arbiter #(4) next_issue(
		.request({ load_enqueued[3] & !load_acknowledged[3],
			load_enqueued[2] & !load_acknowledged[2],
			load_enqueued[1] & !load_acknowledged[1],
			load_enqueued[0] & !load_acknowledged[0]}),
		.update_lru(l2req_ready),
		.grant_oh(issue_oh),
		/*AUTOINST*/
				// Inputs
				.clk		(clk),
				.reset		(reset));

	assign issue_idx = { issue_oh[3] || issue_oh[2], issue_oh[3] || issue_oh[1] };
	assign l2req_valid = |issue_oh;

	assertion #("L2 responded to LMQ entry that wasn't issued") a0
		(.clk(clk), .test(l2rsp_valid && l2rsp_unit == UNIT_ID
		&& !load_enqueued[l2rsp_strand]));
	assertion #("L2 responded to LMQ entry that wasn't acknowledged") a1
		(.clk(clk), .test(l2rsp_valid && l2rsp_unit == UNIT_ID
		&& !load_acknowledged[l2rsp_strand]));

	// XXX are load_complete_set, load_complete_tag and load_complete_way
	// 'don't care' if load_complete_strands_o is zero?  If so, don't
	// create an unecessary mux for them.
	always @*
	begin
		if (l2rsp_valid && l2rsp_unit == UNIT_ID)
		begin
			load_complete_strands_o = load_strands[l2rsp_strand];
			load_complete_set = load_set[l2rsp_strand];
			load_complete_tag = load_tag[l2rsp_strand];
			load_complete_way = load_way[l2rsp_strand];
		end
		else
		begin
			load_complete_strands_o = 0;
			load_complete_set = 0;
			load_complete_tag = 0;
			load_complete_way = 0;
		end
	end
	
	assertion #("queued thread on LMQ twice") a3(.clk(clk),
		.test(request_i && !load_already_pending && load_enqueued[strand_i]));
	assertion #("load collision on non-pending entry") a4(.clk(clk),
		.test(request_i && load_already_pending && !load_enqueued[load_already_pending_entry]));

	always @(posedge clk, posedge reset)
	begin
		if (reset)
		begin
			for (i = 0; i < 4; i = i + 1)
			begin
				load_strands[i] <= 0;
				load_tag[i] <= 0;
				load_set[i] <= 0;
				load_way[i] <= 0;
				load_enqueued[i] <= 0;
				load_acknowledged[i] <= 0;
				load_synchronized[i] <= 0;
			end

			/*AUTORESET*/
		end
		else
		begin
			// Handle enqueueing new requests
			if (request_i)
			begin
				// Note that a synchronized load is a separate command, so we never
				// piggyback it on an existing load.
				if (load_already_pending && !synchronized_i)
				begin
					// Update an existing entry.
					load_strands[load_already_pending_entry] <= load_strands[load_already_pending_entry] 
						| (4'b0001 << strand_i);
				end
				else
				begin
					// Send a new request.
					load_synchronized[strand_i] <= synchronized_i;
					load_tag[strand_i] <= tag_i;	
					load_set[strand_i] <= set_i;
	
					// This is a bit subtle.
					// If a load is already pending (which would only happen if
					// we are doing a synchronized load), we must use the way that is 
					// already queued in that one.  Otherwise use the newly 
					// allocated way.
					if (load_already_pending)
						load_way[strand_i] <= load_way[load_already_pending_entry];
					else
						load_way[strand_i] <= victim_way_i;
	
					load_enqueued[strand_i] <= 1;
					load_strands[strand_i] <= (4'b0001 << strand_i);
				end
			end
	
			if (|issue_oh && l2req_ready)
				load_acknowledged[issue_idx] <= 1;
	
			if (l2rsp_valid && l2rsp_unit == UNIT_ID && load_enqueued[l2rsp_strand])
			begin
				load_enqueued[l2rsp_strand] <= 0;
				load_acknowledged[l2rsp_strand] <= 0;
			end
		end
	end

	assertion #("load_acknowledged conflict") a5(.clk(clk),
		.test(|issue_oh && l2req_ready && l2rsp_valid && l2rsp_unit == UNIT_ID && load_enqueued[l2rsp_strand]
			&& l2rsp_strand == issue_idx));

	/////////////////////////////////////////////////
	// Validation
	/////////////////////////////////////////////////

	// synthesis translate_off
	reg[3:0] _debug_strands;
	integer _debug_index;
	
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
