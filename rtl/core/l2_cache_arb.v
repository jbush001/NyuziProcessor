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
	input						stall_pipeline,
	input						l2req_valid,
	output 						l2req_ready,
	input [1:0]					l2req_unit,
	input [1:0]					l2req_strand,
	input [2:0]					l2req_op,
	input [1:0]					l2req_way,
	input [25:0]				l2req_address,
	input [511:0]				l2req_data,
	input [63:0]				l2req_mask,
	input						smi_input_wait,
	input [1:0]					smi_l2req_unit,				
	input [1:0]					smi_l2req_strand,
	input [2:0]					smi_l2req_op,
	input [1:0]					smi_l2req_way,
	input [25:0]				smi_l2req_address,
	input [511:0]				smi_l2req_data,
	input [63:0]				smi_l2req_mask,
	input [511:0] 				smi_load_buffer_vec,
	input						smi_data_ready,
	input [1:0]					smi_fill_l2_way,
	input						smi_duplicate_request,
	output reg					arb_l2req_valid,
	output reg[1:0]				arb_l2req_unit,
	output reg[1:0]				arb_l2req_strand,
	output reg[2:0]				arb_l2req_op,
	output reg[1:0]				arb_l2req_way,
	output reg[25:0]			arb_l2req_address,
	output reg[511:0]			arb_l2req_data,
	output reg[63:0]			arb_l2req_mask,
	output reg					arb_has_sm_data,
	output reg[511:0]			arb_sm_data,
	output reg[1:0]				arb_sm_fill_l2_way);

	assign l2req_ready = !stall_pipeline && !smi_data_ready && !smi_input_wait;

	always @(posedge clk, posedge reset)
	begin
		if (reset)
		begin
			/*AUTORESET*/
			// Beginning of autoreset for uninitialized flops
			arb_has_sm_data <= 1'h0;
			arb_l2req_address <= 26'h0;
			arb_l2req_data <= 512'h0;
			arb_l2req_mask <= 64'h0;
			arb_l2req_op <= 3'h0;
			arb_l2req_strand <= 2'h0;
			arb_l2req_unit <= 2'h0;
			arb_l2req_valid <= 1'h0;
			arb_l2req_way <= 2'h0;
			arb_sm_data <= 512'h0;
			arb_sm_fill_l2_way <= 2'h0;
			// End of automatics
		end
		else if (!stall_pipeline)
		begin
			if (smi_data_ready)	
			begin
				arb_l2req_valid <= #1 1'b1;
				arb_l2req_unit <= #1 smi_l2req_unit;
				arb_l2req_strand <= #1 smi_l2req_strand;
				arb_l2req_op <= #1 smi_l2req_op;
				arb_l2req_way <= #1 smi_l2req_way;
				arb_l2req_address <= #1 smi_l2req_address;
				arb_l2req_data <= #1 smi_l2req_data;
				arb_l2req_mask <= #1 smi_l2req_mask;
				arb_has_sm_data <= #1 !smi_duplicate_request;
				arb_sm_data <= #1 smi_load_buffer_vec;
				arb_sm_fill_l2_way <= #1 smi_fill_l2_way;
			end
			else if (!smi_input_wait)	// Don't accept requests if SMI queue is full
			begin
				arb_l2req_valid <= #1 l2req_valid;
				arb_l2req_unit <= #1 l2req_unit;
				arb_l2req_strand <= #1 l2req_strand;
				arb_l2req_op <= #1 l2req_op;
				arb_l2req_way <= #1 l2req_way;
				arb_l2req_address <= #1 l2req_address;
				arb_l2req_data <= #1 l2req_data;
				arb_l2req_mask <= #1 l2req_mask;
				arb_has_sm_data <= #1 0;
				arb_sm_data <= #1 0;
			end
			else
				arb_l2req_valid <= #1 0;
		end
		else
			arb_l2req_valid <= #1 0;
	end
endmodule
