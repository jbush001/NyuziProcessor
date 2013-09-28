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

`include "defines.v"

//
// - Queues up L1 cache read misses and issues requests to the L2 cache.
// - Tracks pending requests and matches responses from L2 cache.
// - Handles case where multiple strands miss on the same line, making sure only
//   one request goes to the cache.
// - Sends wakeup signals to restart strands who's loads have been satisfied.
//

module load_miss_queue
	#(parameter						UNIT_ID = 2'd0)

	(input							clk,
	input							reset,

	// To/From L1 cache
	input							request_i,
	input							synchronized_i,
	input [25:0]					request_addr,
	input [1:0]						victim_way_i,
	input [`STRAND_INDEX_WIDTH - 1:0] strand_i,
	output reg[`STRANDS_PER_CORE - 1:0] load_complete_strands_o,
	
	// To L2 cache
	output 							l2req_valid,
	input							l2req_ready,
	output [1:0]					l2req_unit,
	output [`STRAND_INDEX_WIDTH - 1:0] l2req_strand,
	output [2:0]					l2req_op,
	output [`L1_WAY_INDEX_WIDTH - 1:0] l2req_way,
	output [25:0]					l2req_address,
	output [511:0]					l2req_data,
	output [63:0]					l2req_mask,
	input 							l2rsp_valid,
	input [1:0]						l2rsp_unit,
	input [`STRAND_INDEX_WIDTH - 1:0] l2rsp_strand);

	// One bit per strand
	reg[`STRANDS_PER_CORE - 1:0] load_strands[0:`STRANDS_PER_CORE - 1];
	reg[25:0] load_address[0:`STRANDS_PER_CORE - 1];
	reg[1:0] load_way[0:`STRANDS_PER_CORE - 1];
	reg load_enqueued[0:`STRANDS_PER_CORE - 1];
	reg load_acknowledged[0:`STRANDS_PER_CORE - 1];
	reg load_synchronized[0:`STRANDS_PER_CORE - 1];
	wire load_already_pending;
	wire[`STRAND_INDEX_WIDTH - 1:0] load_already_pending_entry;
	wire[`STRAND_INDEX_WIDTH - 1:0] issue_idx;
	wire[`STRANDS_PER_CORE - 1:0] issue_oh;

	assign l2req_op = load_synchronized[issue_idx] ? `L2REQ_LOAD_SYNC : `L2REQ_LOAD;	
	assign l2req_way = load_way[issue_idx];
	assign l2req_address = load_address[issue_idx];
	assign l2req_unit = UNIT_ID;
	assign l2req_strand = issue_idx;
	assign l2req_data = 0;
	assign l2req_mask = 0;

	//
	// This is a bit subtle.
	// There can be multiple hits in the load CAM for the same cache line,
	// because synchronized loads always allocate a new entry (although they use
	// the same way as the existing entry to ensure data is not duplicated in the
	// L1 cache). 
	// When there are multiple synchronized loads for the same line (common 
	// when there is contention for a spinlock), we ignore the load_already_pending
	// signal. However, in the case where a non-synchronized load misses on the 
	// same cache line that a synchronized load is pending on, we want to piggyback 
	// on one of the pending requests. Use a basic priority encoder to find the 
	// lowest one (I don't think it really matters which; they all have the same way
	// encoded).
	//
	wire[`STRANDS_PER_CORE - 1:0] load_cam_hit;
	genvar cam_entry;
	generate
		for (cam_entry = 0; cam_entry < `STRANDS_PER_CORE; cam_entry = cam_entry + 1)
		begin : lookup
			assign load_cam_hit[cam_entry] = load_enqueued[cam_entry]	
				&& load_address[cam_entry] == request_addr;
		end
	endgenerate

	// Find lowest set bit in hit array
	wire[`STRANDS_PER_CORE - 1:0] load_already_pending_oh = load_cam_hit 
		& ~(load_cam_hit - 1);

	assign load_already_pending = |load_already_pending_oh;
	one_hot_to_index #(.NUM_SIGNALS(`STRANDS_PER_CORE)) cvt_cam_lookup(
		.one_hot(load_already_pending_oh),
		.index(load_already_pending_entry));

	wire[`STRANDS_PER_CORE - 1:0] issue_request;

	genvar queue_idx;
	generate
		for (queue_idx = 0; queue_idx < `STRANDS_PER_CORE; queue_idx = queue_idx + 1)
		begin : update_request
			assign issue_request[queue_idx] = load_enqueued[queue_idx] 
				& !load_acknowledged[queue_idx];
		end
	endgenerate
	
	arbiter #(.NUM_ENTRIES(`STRANDS_PER_CORE)) next_issue(
		.request(issue_request),
		.update_lru(l2req_ready),
		.grant_oh(issue_oh),
		/*AUTOINST*/
							      // Inputs
							      .clk		(clk),
							      .reset		(reset));

	one_hot_to_index #(.NUM_SIGNALS(`STRANDS_PER_CORE)) cvt_issue_idx(
		.one_hot(issue_oh),
		.index(issue_idx));

	assign l2req_valid = |issue_oh;

	assert_false #("L2 responded to entry that wasn't issued") a0
		(.clk(clk), .test(l2rsp_valid && l2rsp_unit == UNIT_ID
		&& !load_enqueued[l2rsp_strand]));
	assert_false #("L2 responded to entry that wasn't acknowledged") a1
		(.clk(clk), .test(l2rsp_valid && l2rsp_unit == UNIT_ID
		&& !load_acknowledged[l2rsp_strand]));

	always @*
	begin
		if (l2rsp_valid && l2rsp_unit == UNIT_ID)
			load_complete_strands_o = load_strands[l2rsp_strand];
		else
			load_complete_strands_o = 0;
	end
	
	assert_false #("queued thread on LMQ twice") a3(.clk(clk),
		.test(request_i && !load_already_pending && load_enqueued[strand_i]));
	assert_false #("load collision on non-pending entry") a4(.clk(clk),
		.test(request_i && !synchronized_i && load_already_pending 
			&& !load_enqueued[load_already_pending_entry]));

	always @(posedge clk, posedge reset)
	begin : update
		integer i;

		if (reset)
		begin
			for (i = 0; i < `STRANDS_PER_CORE; i = i + 1)
			begin
				load_strands[i] <= 0;
				load_address[i] <= 0;
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
						| (1 << strand_i);
				end
				else
				begin
					// Send a new request.
					load_synchronized[strand_i] <= synchronized_i;
					load_address[strand_i] <= request_addr;
	
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
	
			if (issue_oh != 0 && l2req_ready)
				load_acknowledged[issue_idx] <= 1;
	
			if (l2rsp_valid && l2rsp_unit == UNIT_ID && load_enqueued[l2rsp_strand])
			begin
				load_enqueued[l2rsp_strand] <= 0;
				load_acknowledged[l2rsp_strand] <= 0;
			end
		end
	end

	assert_false #("load_acknowledged conflict") a5(.clk(clk),
		.test(issue_oh != 0 && l2req_ready && l2rsp_valid && l2rsp_unit == UNIT_ID && load_enqueued[l2rsp_strand]
			&& l2rsp_strand == issue_idx));

	/////////////////////////////////////////////////
	// Validation
	/////////////////////////////////////////////////

`ifdef SIMULATION
	reg[`STRANDS_PER_CORE - 1:0] _debug_strands;
	
	always @(posedge clk)
	begin : check
		integer _debug_index;
	
		// Ensure a strand is not marked waiting on multiple entries	
		_debug_strands = 0;
		for (_debug_index = 0; _debug_index < `STRANDS_PER_CORE; _debug_index = _debug_index + 1)
		begin
			if (load_enqueued[_debug_index])
			begin
				if (_debug_strands & load_strands[_debug_index])
				begin
					$display("%m: a strand is marked waiting on multiple load queue entries %b", 
						_debug_strands & load_strands[_debug_index]);
					$finish;
				end

				_debug_strands = _debug_strands | load_strands[_debug_index];
			end
		end	
	end
`endif

endmodule
