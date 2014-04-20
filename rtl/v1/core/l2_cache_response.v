// 
// Copyright (C) 2011-2014 Jeff Bush
// 
// This library is free software; you can redistribute it and/or
// modify it under the terms of the GNU Library General Public
// License as published by the Free Software Foundation; either
// version 2 of the License, or (at your option) any later version.
// 
// This library is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
// Library General Public License for more details.
// 
// You should have received a copy of the GNU Library General Public
// License along with this library; if not, write to the
// Free Software Foundation, Inc., 51 Franklin St, Fifth Floor,
// Boston, MA  02110-1301, USA.
// 


`include "defines.v"

//
// L2 cache response stage.
//
// Send a packet on the L2 response interface
// - Cache Read Hit: send an acknowledgement with the data.
// - Cache Write Hit: send an acknowledgement.  If this data is in L1 cache(s),
//   indicate so with a signal (l2rsp_packet.update) and send the new contents of the line. 
// - Cache miss: don't send anything.  The request will be restarted by the L2
//   SMI interface when the data has been loaded, so we just ignore the old request for
//   now.
//

module l2_cache_response(
	input                                   clk,
	input                                   reset,
	input l2req_packet_t                    wr_l2req_packet,
	input [`CACHE_LINE_BITS - 1:0]          wr_data,
	input [`NUM_CORES - 1:0]                wr_l1_has_line,
	input [`NUM_CORES * 2 - 1:0]            wr_dir_l1_way,
	input                                   wr_cache_hit,
	input                                   wr_is_l2_fill,
	input                                   wr_store_sync_success,
	output l2rsp_packet_t                   l2rsp_packet);

	l2rsp_packet_type_t response_op;
	wire is_store = wr_l2req_packet.op == L2REQ_STORE || wr_l2req_packet.op == L2REQ_STORE_SYNC;

	always_comb
	begin
		unique case (wr_l2req_packet.op)
			L2REQ_LOAD: response_op = L2RSP_LOAD_ACK;
			L2REQ_STORE: response_op = L2RSP_STORE_ACK;
			L2REQ_FLUSH: response_op = L2RSP_LOAD_ACK;	// Need a code for this (currently ignored)
			L2REQ_DINVALIDATE: response_op = L2RSP_DINVALIDATE;
			L2REQ_IINVALIDATE: response_op = L2RSP_IINVALIDATE;
			L2REQ_LOAD_SYNC: response_op = L2RSP_LOAD_ACK;
			L2REQ_STORE_SYNC: response_op = L2RSP_STORE_ACK;
			default: response_op = L2RSP_LOAD_ACK;
		endcase
	end

	// Generate a signal for each core that indicates which way the update
	// is for (for write updates and coherence broadcasts).	
	logic[`NUM_CORES * `L1_WAY_INDEX_WIDTH - 1:0] l2rsp_packet_way_nxt;
	genvar core_index;
	generate
		for (core_index = 0; core_index < `NUM_CORES; core_index++)
		begin : gen_way_id
			assign l2rsp_packet_way_nxt[core_index * `L1_WAY_INDEX_WIDTH+:`L1_WAY_INDEX_WIDTH]
				= wr_l1_has_line[core_index] 
				? wr_dir_l1_way[core_index * `L1_WAY_INDEX_WIDTH+:`L1_WAY_INDEX_WIDTH] 
				: wr_l2req_packet.way;
		end	
	endgenerate

	always_ff @(posedge clk, posedge reset)
	begin
		if (reset)
			l2rsp_packet <= 0;
		else if (wr_l2req_packet.valid && (wr_cache_hit || wr_is_l2_fill 
			|| wr_l2req_packet.op == L2REQ_FLUSH
			|| wr_l2req_packet.op == L2REQ_DINVALIDATE
			|| wr_l2req_packet.op == L2REQ_IINVALIDATE))
		begin
			l2rsp_packet.valid <= 1;
			l2rsp_packet.core <= wr_l2req_packet.core;
			l2rsp_packet.status <= wr_l2req_packet.op == L2REQ_STORE_SYNC ? wr_store_sync_success : 1;
			l2rsp_packet.unit <= wr_l2req_packet.unit;
			l2rsp_packet.strand <= wr_l2req_packet.strand;
			l2rsp_packet.op <= response_op;
			l2rsp_packet.address <= wr_l2req_packet.address;

			// l2rsp_packet.update indicates if a L1 tag should be cleared for a dinvalidate
			// response.  For a store, it indicates if L1 data should be updated.
			if (wr_l2req_packet.op == L2REQ_STORE_SYNC)
				l2rsp_packet.update <= wr_l1_has_line & {`NUM_CORES{wr_store_sync_success}};	
			else if (is_store || wr_l2req_packet.op == L2REQ_DINVALIDATE)
				l2rsp_packet.update <= wr_l1_has_line;	
			else
				l2rsp_packet.update <= 0;

			l2rsp_packet.way <= l2rsp_packet_way_nxt;
			l2rsp_packet.data <= wr_data;	
		end
		else
			l2rsp_packet <= 0;
	end
endmodule

// Local Variables:
// verilog-typedef-regexp:"_t$"
// End:
