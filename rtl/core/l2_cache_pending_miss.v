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

//
// Tracks pending cache misses in the L2 cache.
// The sole purpose of this module is to avoid having duplicate system memory
// loads/stores.  In the best case, they would be less efficient, but in the worst
// case, a load after store will clobber data.
// Each time a cache miss goes past this unit, it records the cache line 
// that is pending.  When a restarted request goes past this unit, it clears
// the pending line.  For each transaction, the 'duplicate_reqest'
// signal is set to indicate if another transaction for that line is pending.
//
// Bear in mind that the pending miss for the line may be anywhere in the pipeline,
// not just the SMI queue.
//
// Note that QUEUE_SIZE must be >= the number of entries in the system memory
// request queue + the number of pipeline stages.
//

module l2_cache_pending_miss
	#(parameter 			QUEUE_SIZE = 16,
	parameter 				QUEUE_ADDR_WIDTH = 4)
	(input					clk,
	input					reset_n,
	input					rd_l2req_valid,
	input [25:0]			rd_l2req_address,
	input					enqueue_load_request,
	input					rd_has_sm_data,
	output 					duplicate_request);

	reg[25:0]				miss_address[0:QUEUE_SIZE - 1];
	reg						entry_valid[0:QUEUE_SIZE - 1];
	integer					i;
	integer					search_entry;
	reg[QUEUE_ADDR_WIDTH - 1:0]	cam_hit_entry;
	reg						cam_hit;
	integer					empty_search;
	reg[QUEUE_ADDR_WIDTH - 1:0] empty_entry;
	integer					_validate_found_empty;

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
				== rd_l2req_address)		
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
		_validate_found_empty = 0;
		for (empty_search = 0; empty_search < QUEUE_SIZE; empty_search
			= empty_search + 1)
		begin
			if (!entry_valid[empty_search])
			begin
				_validate_found_empty = 1;
				empty_entry = empty_search;
			end
		end
	end

	// Update CAM
	always @(posedge clk, negedge reset_n)
	begin
		if (!reset_n)
		begin
			for (i = 0; i < QUEUE_SIZE; i = i + 1)
			begin
				miss_address[i] = 0;
				entry_valid[i] = 0;
			end

			/*AUTORESET*/
		end
		else if (rd_l2req_valid)
		begin
			if (cam_hit && rd_has_sm_data)
				entry_valid[cam_hit_entry] <= 0;	// Clear pending bit
			else if (!cam_hit && enqueue_load_request)
			begin
				// Set pending bit
				entry_valid[empty_entry] <= 1;
				miss_address[empty_entry] <= rd_l2req_address;
			end
		end
	end

	assertion #("l2_cache_pending_miss: overflow") a(.clk(clk), 
		.test(!_validate_found_empty));
endmodule

