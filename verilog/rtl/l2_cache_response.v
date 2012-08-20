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
// L2 cache response stage.
//
// Send a response on the CPI interface
// - Cache Read Hit: send an acknowledgement.
// - Cache Write Hit: send an acknowledgement and the new contents
//   of the line.  If there are lines in other cores that match,
//   need to send write updates for those.  
// - Cache miss: don't send anything.
//

module l2_cache_response(
	input                         clk,
	input 		                  wr_l2req_valid,
	input [1:0]                   wr_l2req_unit,
	input [1:0]	                  wr_l2req_strand,
	input [2:0]                   wr_l2req_op,
	input [1:0] 	              wr_l2req_way,
	input [511:0]	              wr_data,
	input                         wr_l1_has_line,
	input [1:0]                   wr_dir_l1_way,
	input                         wr_cache_hit,
	input                         wr_has_sm_data,
	input                         wr_store_sync_success,
	output reg                    l2rsp_valid = 0,
	output reg                    l2rsp_status = 0,
	output reg[1:0]               l2rsp_unit = 0,
	output reg[1:0]               l2rsp_strand = 0,
	output reg[1:0]               l2rsp_op = 0,
	output reg                    l2rsp_update = 0,
	output reg[1:0]               l2rsp_way = 0,
	output reg[511:0]             l2rsp_data = 0);

	reg[1:0] response_op = 0;
	wire is_store = wr_l2req_op == `L2REQ_STORE || wr_l2req_op == `L2REQ_STORE_SYNC;

	always @*
	begin
		case (wr_l2req_op)
			`L2REQ_LOAD: response_op = `L2RSP_LOAD_ACK;
			`L2REQ_STORE: response_op = `L2RSP_STORE_ACK;
			`L2REQ_FLUSH: response_op = 0;	// Need a code for this (currently ignored)
			`L2REQ_INVALIDATE: response_op = 0;	// XXX Not implemented yet
			`L2REQ_LOAD_SYNC: response_op = `L2RSP_LOAD_ACK;
			`L2REQ_STORE_SYNC: response_op = `L2RSP_STORE_ACK;
			default: response_op = 0;
		endcase
	end

	always @(posedge clk)
	begin
		if (wr_l2req_valid && (wr_cache_hit || wr_has_sm_data || wr_l2req_op == `L2REQ_FLUSH
			|| wr_l2req_op == `L2REQ_INVALIDATE))
		begin
			l2rsp_valid <= #1 1;
			l2rsp_status <= #1 wr_l2req_op == `L2REQ_STORE_SYNC ? wr_store_sync_success : 0;
			l2rsp_unit <= #1 wr_l2req_unit;
			l2rsp_strand <= #1 wr_l2req_strand;
			l2rsp_op <= #1 response_op;	
			l2rsp_update <= #1 wr_l1_has_line && is_store;	
			if (wr_l1_has_line)
				l2rsp_way <= #1 wr_dir_l1_way; 
			else
				l2rsp_way <= #1 wr_l2req_way; 

			l2rsp_data <= #1 wr_data;	
		end
		else
			l2rsp_valid <= #1 0;
	end
endmodule
