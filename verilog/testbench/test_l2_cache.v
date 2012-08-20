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

module l2_cache_test;
	reg 					clk = 0;
	reg						l2req_valid = 0;
	wire					l2req_ack;
	reg [1:0]				l2req_unit = 0;
	reg [1:0]				l2req_strand = 0;
	reg [2:0]				l2req_op = 0;
	reg [1:0]				l2req_way = 0;
	reg [25:0]				l2req_address = 0;
	reg [511:0]				l2req_data = 0;
	reg [63:0]				l2req_mask = 0;
	wire					l2rsp_valid;
	wire					l2rsp_status;
	wire[1:0]				l2rsp_unit;
	wire[1:0]				l2rsp_strand;
	wire[1:0]				l2rsp_op;
	wire					l2rsp_update;
	wire[1:0]				l2rsp_way;
	wire[511:0]				l2rsp_data;

	wire[31:0]				sm_addr;
	wire					sm_request;
	reg						sm_ack = 0;
	wire					sm_write;
	reg[31:0]				data_from_sm = 0;
	wire[31:0]				data_to_sm;
	integer					i;
	integer					j;

	l2_cache l2c(
		.clk(clk),
		.l2req_valid(l2req_valid),
		.l2req_ack(l2req_ack),
		.l2req_unit(l2req_unit),
		.l2req_strand(l2req_strand),
		.l2req_op(l2req_op),
		.l2req_way(l2req_way),
		.l2req_address(l2req_address),
		.l2req_data(l2req_data),
		.l2req_mask(l2req_mask),
		.l2rsp_valid(l2rsp_valid),
		.l2rsp_status(l2rsp_status),
		.l2rsp_unit(l2rsp_unit),
		.l2rsp_strand(l2rsp_strand),
		.l2rsp_op(l2rsp_op),
		.l2rsp_update(l2rsp_update),
		.l2rsp_way(l2rsp_way),
		.l2rsp_data(l2rsp_data),
		.addr_o(sm_addr),
		.request_o(sm_request),
		.ack_i(sm_ack),
		.write_o(sm_write),
		.data_i(data_from_sm),
		.data_o(data_to_sm));

	localparam CACHE_MISS = 0;
	localparam CACHE_HIT = 1;
	localparam CACHE_NOT_DIRTY = 0;
	localparam CACHE_DIRTY = 1;

	reg[31:0] expected_lane_data = 0;	// Used in do_miss_transfer

	// The system memory transfer, common to load and store misses
	task do_miss_transfer;
		input [25:0] address;
		input [511:0] expected;
		input dirty;
		input [31:0] writeback_address;
		input [511:0] writeback_data;
	begin
		// Wait for request
		while (!sm_request)
		begin
			#5 clk = 0;
			#5 clk = 1;
		end
		
		if (dirty)
		begin
			// Write phase...
			if (!sm_write)
			begin
				$display("write not asserted");
				$finish;
			end

			if (sm_addr != writeback_address * 64)
			begin
				$display("bad write address want %08x got %08x", writeback_address,
					sm_addr);
				$finish;
			end

			sm_ack = 1;
			for (j = 0; j < 16; j = j + 1)
			begin
				expected_lane_data = (writeback_data >> (32 * (15 - j)));
				if (expected_lane_data != data_to_sm)
				begin
					$display("writeback mismatch, offset %d want %x got %x", j,
						expected_lane_data, data_to_sm);
				end

				#5 clk = 0;
				#5 clk = 1;
			end
		end

		// Read phase
		for (j = 0; j < 16; j = j + 1)
		begin
			if (sm_write)
			begin
				$display("write asserted for read phase");
				$finish;
			end

			if (sm_addr != address * 64 + j * 4)
			begin
				$display("bad read address want %x got %x", address * 64 + j * 4, sm_addr);
				$finish;
			end

			#5 clk = 0;

			data_from_sm = (expected >> (32 * (15 - j)));
			sm_ack = 1;

			#5 clk = 1;
		end

		#5 clk = 0;
		sm_ack = 0;
		#5 clk = 1;
	end
	endtask
	
	task l2_load;
		input [25:0] address;
		input [511:0] expected;
		input cache_hit;
		input dirty;
		input [31:0] writeback_addr;
		input [511:0] writeback_data;
	begin
		$display("test load %s %s %x", cache_hit ? "hit" : "miss", dirty ? "dirty" : "",
			address);

		l2req_valid = 1;
		l2req_unit = 1;
		l2req_strand = 0;
		l2req_op = `L2REQ_LOAD;
		l2req_way = 0;
		l2req_address = address;
		
		while (l2req_ack !== 1)
		begin
			#5 clk = 0;
			#5 clk = 1;
		end

		l2req_valid = 0;

		if (cache_hit == CACHE_MISS)
			do_miss_transfer(address, expected, dirty, writeback_addr, writeback_data);

		while (!l2rsp_valid)		
		begin
			#5 clk = 0;
			#5 clk = 1;
			if (sm_request && cache_hit)
			begin
				$display("unexpected sm request");
				$finish;
			end
		end

		// Check result
		if (l2rsp_data !== expected)
		begin
			$display("load mismatch want \n\t%x\n got \n\t%x",
				expected, l2rsp_data);
			$finish;
		end
	end
	endtask

	task l2_store;
		input [25:0] address;
		input [63:0] mask;
		input [511:0] write_data;
		input [511:0] expected;
		input cache_hit;
		input dirty;
		input [31:0] writeback_addr;
		input [511:0] writeback_data;
	begin
		$display("test store %s %s %08x", cache_hit ? "hit" : "miss", dirty ? "dirty" : "",
			address);

		l2req_valid = 1;
		l2req_unit = 2;
		l2req_strand = 0;
		l2req_op = `L2REQ_STORE;
		l2req_way = 0;
		l2req_address = address;
		l2req_mask = mask;
		l2req_data = write_data;

		while (l2req_ack !== 1)
		begin
			#5 clk = 0;
			#5 clk = 1;
		end

		l2req_valid = 0;

		if (cache_hit == CACHE_MISS)
			do_miss_transfer(address, expected, dirty, writeback_addr, writeback_data);

		while (!l2rsp_valid)		
		begin
			#5 clk = 0;
			#5 clk = 1;
			if (sm_request && cache_hit)
			begin
				$display("unexpected sm request");
				$finish;
			end
		end

		if (l2rsp_update !== 1)
		begin
			$display("no update");
			$finish;
		end

		// Make sure new data is reflected
		if (l2rsp_data !== expected)
		begin
			$display("data update mismatch want \n\t%x\n got \n\t%x",
				expected, l2rsp_data);
			$finish;
		end

		#5 clk = 0;
		#5 clk = 1;
	end
	endtask

	localparam PAT1 = 512'he557b78b_d40df4cd_e9ffa5eb_f868c1cf_7068c30a_7587ddb3_7ad4cd9e_db1d8751_e885f505_a44997b8_86a76f8a_7caba015_171b4022_bc9b761e_e23a11e0_0f19f338;
	localparam PAT2 = 512'he6c17f8f_e83fce2b_441752d7_754ab59e_073efaac_c228c3c2_690616fb_798c2dec_b02c0a26_0867862c_d0053170_75dd9bae_fef44d27_2475f817_30883ef9_7843afb7;
	localparam PAT3 = 512'h3b163cf2_2c8bb48e_758bd67a_2b43553e_0ca7b1e0_50e3ee5d_85c91d0e_4b9b5700_c54108ec_b6a76fb3_b9a097d1_0e96a9e8_868b9ca0_fd8cbf95_7d5738db_d1e481a2;
	localparam PAT4 = 512'h95ffd554_d65f92f7_b44c0c68_70b298b7_2b852287_8b2a3311_b55ee570_c4603787_0cb78e49_c3bfb6de_b65f42e7_2a80ae2c_df8fb98d_71a2ecc1_e495ec5d_941d9c6f;
	localparam PAT5 = 512'h2610d695_8316f1e8_12c733e5_636488fd_d31db139_4410e9c9_8d57003d_61bcf849_fc26c1e1_303516bd_532828a1_546b0c87_1228c78b_c404f1f8_5d505827_e4923f13;
	localparam PAT1PAT5 = 512'he557b78b_8316f1e8_e9ffa5eb_636488fd_7068c30a_4410e9c9_7ad4cd9e_61bcf849_e885f505_303516bd_86a76f8a_546b0c87_171b4022_c404f1f8_e23a11e0_e4923f13;
	localparam MASK1 = 64'h0f0f0f0f0f0f0f0f;
	localparam MASK2 = 64'hffffffffffffffff;

	initial
	begin
		#5 clk = 0;
		#5 clk = 1;

		$dumpfile("trace.vcd");
		$dumpvars;

		// Load data into 2 sets and 2 ways within each set.  The initial
		// return value from the cache will be bypassed.
		l2_load(32'ha000, PAT1, CACHE_MISS, CACHE_NOT_DIRTY, 0, 0);
		l2_load(32'hb000, PAT2, CACHE_MISS, CACHE_NOT_DIRTY, 0, 0);
		l2_load(32'ha001, PAT3, CACHE_MISS, CACHE_NOT_DIRTY, 0, 0);
		l2_load(32'hb001, PAT4, CACHE_MISS, CACHE_NOT_DIRTY, 0, 0);

		// read the same data again, ensuring we get a cache hit and that the
		// data was written properly to cache memory in the last step
		l2_load(32'ha000, PAT1, CACHE_HIT, 0, 0, 0);
		l2_load(32'hb000, PAT2, CACHE_HIT, 0, 0, 0);
		l2_load(32'ha001, PAT3, CACHE_HIT, 0, 0, 0);
		l2_load(32'hb001, PAT4, CACHE_HIT, 0, 0, 0);

		// Write a masked value to one of the lines.  Read it back again
		// to ensure it was properly stored
		l2_store(32'ha000, MASK1, PAT5, PAT1PAT5, CACHE_HIT, 0, 0, 0);
		l2_load(32'ha000, PAT1PAT5, CACHE_HIT, 0, 0, 0);

		// Read back the other data to ensure it is still intact.
		l2_load(32'hb000, PAT2, CACHE_HIT, 0, 0, 0);
		l2_load(32'ha001, PAT3, CACHE_HIT, 0, 0, 0);
		l2_load(32'hb001, PAT4, CACHE_HIT, 0, 0, 0);

		// Store miss (new set)
		l2_store(32'ha002, MASK2, PAT1, PAT1, CACHE_MISS, CACHE_NOT_DIRTY, 0, 0);
		l2_load(32'hb002, 512'd0, CACHE_MISS, CACHE_NOT_DIRTY, 0, 0);
		l2_load(32'hc002, 512'd0, CACHE_MISS, CACHE_NOT_DIRTY, 0, 0);
		l2_load(32'hd002, 512'd0, CACHE_MISS, CACHE_NOT_DIRTY, 0, 0);
	
		// This one will evict a dirty line (the first one that missed)
		l2_load(32'he002, PAT4, CACHE_MISS, CACHE_DIRTY, 32'ha002, PAT1);

		// Make sure these do not evict a line.  Also, we're moving the line
		// containing e002 to the LRU position
		l2_load(32'hf002, PAT2, CACHE_MISS, CACHE_NOT_DIRTY, 0, 0);
		l2_load(32'h10002, PAT3, CACHE_MISS, CACHE_NOT_DIRTY, 0, 0);
		l2_load(32'h11002, PAT4, CACHE_MISS, CACHE_NOT_DIRTY, 0, 0);

		// Now, this one will replace e002.  Make sure the dirty bit has been
		// cleared properly and we don't get a spurious writeback
		l2_load(32'h12002, PAT1, CACHE_MISS, CACHE_NOT_DIRTY, 0, 0);

		$display("test complete");
	end
endmodule


