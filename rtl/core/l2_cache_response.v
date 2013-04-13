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
// L2 cache response stage.
//
// Send a packet on the L2 response interface
// - Cache Read Hit: send an acknowledgement with the data.
// - Cache Write Hit: send an acknowledgement.  If this data is in L1 cache(s),
//   indicate so with a signal (l2rsp_update) and send the new contents of the line. 
// - Cache miss: don't send anything.  The request will be restarted by the L2
//   SMI interface when the data has been loaded, so we just ignore the old request for
//   now.
//

module l2_cache_response(
	input                         clk,
	input						  reset,
	input 		                  wr_l2req_valid,
	input [`CORE_INDEX_WIDTH - 1:0] wr_l2req_core,
	input [1:0]                   wr_l2req_unit,
	input [1:0]	                  wr_l2req_strand,
	input [2:0]                   wr_l2req_op,
	input [1:0] 	              wr_l2req_way,
	input [511:0]	              wr_data,
	input [`NUM_CORES - 1:0]      wr_l1_has_line,
	input [`NUM_CORES * 2 - 1:0]  wr_dir_l1_way,
	input                         wr_cache_hit,
	input [25:0]                  wr_l2req_address,
	input                         wr_is_l2_fill,
	input                         wr_store_sync_success,
	output reg                    l2rsp_valid,
	output reg                    l2rsp_status,
	output reg[`CORE_INDEX_WIDTH - 1:0] l2rsp_core,
	output reg[1:0]               l2rsp_unit,
	output reg[1:0]               l2rsp_strand,
	output reg[1:0]               l2rsp_op,
	output reg[`NUM_CORES - 1:0]  l2rsp_update,
	output reg[`NUM_CORES * 2 - 1:0] l2rsp_way,
	output reg[25:0]              l2rsp_address,
	output reg[511:0]             l2rsp_data);

	reg[1:0] response_op;
	wire is_store = wr_l2req_op == `L2REQ_STORE || wr_l2req_op == `L2REQ_STORE_SYNC;

	always @*
	begin
		case (wr_l2req_op)
			`L2REQ_LOAD: response_op = `L2RSP_LOAD_ACK;
			`L2REQ_STORE: response_op = `L2RSP_STORE_ACK;
			`L2REQ_FLUSH: response_op = 0;	// Need a code for this (currently ignored)
			`L2REQ_DINVALIDATE: response_op = `L2RSP_DINVALIDATE;
			`L2REQ_IINVALIDATE: response_op = `L2RSP_IINVALIDATE;
			`L2REQ_LOAD_SYNC: response_op = `L2RSP_LOAD_ACK;
			`L2REQ_STORE_SYNC: response_op = `L2RSP_STORE_ACK;
			default: response_op = 0;
		endcase
	end

	always @(posedge clk, posedge reset)
	begin
		if (reset)
		begin
			/*AUTORESET*/
			// Beginning of autoreset for uninitialized flops
			l2rsp_address <= 26'h0;
			l2rsp_core <= {(1+(`CORE_INDEX_WIDTH-1)){1'b0}};
			l2rsp_data <= 512'h0;
			l2rsp_op <= 2'h0;
			l2rsp_status <= 1'h0;
			l2rsp_strand <= 2'h0;
			l2rsp_unit <= 2'h0;
			l2rsp_update <= {(1+(`NUM_CORES-1)){1'b0}};
			l2rsp_valid <= 1'h0;
			l2rsp_way <= {(1+(`NUM_CORES*2-1)){1'b0}};
			// End of automatics
		end
		else if (wr_l2req_valid && (wr_cache_hit || wr_is_l2_fill 
			|| wr_l2req_op == `L2REQ_FLUSH
			|| wr_l2req_op == `L2REQ_DINVALIDATE
			|| wr_l2req_op == `L2REQ_IINVALIDATE))
		begin
			l2rsp_valid <= 1;
			l2rsp_core <= wr_l2req_core;
			l2rsp_status <= wr_l2req_op == `L2REQ_STORE_SYNC ? wr_store_sync_success : 1;
			l2rsp_unit <= wr_l2req_unit;
			l2rsp_strand <= wr_l2req_strand;
			l2rsp_op <= response_op;
			l2rsp_address <= wr_l2req_address;

			// l2rsp_update indicates if a L1 tag should be cleared for a dinvalidate
			// response.  For a store, it indicates if L1 data should be updated.
			if (wr_l2req_op == `L2REQ_STORE_SYNC)
				l2rsp_update <= wr_l1_has_line & {`NUM_CORES{wr_store_sync_success}};	
			else if (is_store || wr_l2req_op == `L2REQ_DINVALIDATE)
				l2rsp_update <= wr_l1_has_line;	
			else
				l2rsp_update <= 0;

			// Mux in the new line for the requestor
			l2rsp_way <= {
`ifdef ENABLE_CORE1
				wr_l1_has_line[1] ? wr_dir_l1_way[3:2] : wr_l2req_way,
`endif
				wr_l1_has_line[0] ? wr_dir_l1_way[1:0] : wr_l2req_way
			};

			l2rsp_data <= wr_data;	
		end
		else
			l2rsp_valid <= 0;
	end
endmodule
