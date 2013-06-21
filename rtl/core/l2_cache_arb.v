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
// L2 cache pipeline arbitration stage
// Determines whether a request from a core or a restarted request from
// the system memory interface queue should be pushed down the pipeline.
// The latter always has priority.
//

module l2_cache_arb(
	input						clk,
	input						reset,
	input						l2req_valid,
	input [`CORE_INDEX_WIDTH - 1:0] l2req_core,
	output 						l2req_ready,
	input [1:0]					l2req_unit,
	input [`STRAND_INDEX_WIDTH - 1:0] l2req_strand,
	input [2:0]					l2req_op,
	input [1:0]					l2req_way,
	input [25:0]				l2req_address,
	input [511:0]				l2req_data,
	input [63:0]				l2req_mask,
	input						bif_input_wait,
	input [`CORE_INDEX_WIDTH - 1:0] bif_l2req_core,
	input [1:0]					bif_l2req_unit,				
	input [`STRAND_INDEX_WIDTH - 1:0] bif_l2req_strand,
	input [2:0]					bif_l2req_op,
	input [1:0]					bif_l2req_way,
	input [25:0]				bif_l2req_address,
	input [511:0]				bif_l2req_data,
	input [63:0]				bif_l2req_mask,
	input [511:0] 				bif_load_buffer_vec,
	input						bif_data_ready,
	input						bif_duplicate_request,
	output reg					arb_l2req_valid,
	output reg[`CORE_INDEX_WIDTH - 1:0]	arb_l2req_core,
	output reg[1:0]				arb_l2req_unit,
	output reg[`STRAND_INDEX_WIDTH - 1:0] arb_l2req_strand,
	output reg[2:0]				arb_l2req_op,
	output reg[1:0]				arb_l2req_way,
	output reg[25:0]			arb_l2req_address,
	output reg[511:0]			arb_l2req_data,
	output reg[63:0]			arb_l2req_mask,
	output reg					arb_is_restarted_request,
	output reg[511:0]			arb_data_from_memory);

	assign l2req_ready = !bif_data_ready && !bif_input_wait;

	always @(posedge clk, posedge reset)
	begin
		if (reset)
		begin
			/*AUTORESET*/
			// Beginning of autoreset for uninitialized flops
			arb_data_from_memory <= 512'h0;
			arb_is_restarted_request <= 1'h0;
			arb_l2req_address <= 26'h0;
			arb_l2req_core <= {(1+(`CORE_INDEX_WIDTH-1)){1'b0}};
			arb_l2req_data <= 512'h0;
			arb_l2req_mask <= 64'h0;
			arb_l2req_op <= 3'h0;
			arb_l2req_strand <= {(1+(`STRAND_INDEX_WIDTH-1)){1'b0}};
			arb_l2req_unit <= 2'h0;
			arb_l2req_valid <= 1'h0;
			arb_l2req_way <= 2'h0;
			// End of automatics
		end
		else
		begin
			if (bif_data_ready)	
			begin
				// Restarted request
				arb_l2req_valid <= 1'b1;
				arb_l2req_core <= bif_l2req_core;
				arb_l2req_unit <= bif_l2req_unit;
				arb_l2req_strand <= bif_l2req_strand;
				arb_l2req_op <= bif_l2req_op;
				arb_l2req_way <= bif_l2req_way;
				arb_l2req_address <= bif_l2req_address;
				arb_l2req_data <= bif_l2req_data;
				arb_l2req_mask <= bif_l2req_mask;
				arb_is_restarted_request <= !bif_duplicate_request;
				arb_data_from_memory <= bif_load_buffer_vec;
			end
			else if (!bif_input_wait)	// Don't accept requests if SMI queue is full
			begin
				arb_l2req_valid <= l2req_valid;
				arb_l2req_core <= l2req_core;
				arb_l2req_unit <= l2req_unit;
				arb_l2req_strand <= l2req_strand;
				arb_l2req_op <= l2req_op;
				arb_l2req_way <= l2req_way;
				arb_l2req_address <= l2req_address;
				arb_l2req_data <= l2req_data;
				arb_l2req_mask <= l2req_mask;
				arb_is_restarted_request <= 0;
				arb_data_from_memory <= 0;
			end
			else
				arb_l2req_valid <= 0;
		end
	end
endmodule
