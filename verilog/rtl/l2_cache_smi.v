//
// L2 Cache System Memory Interface 
// Queue L2 cache misses and interacts with system memory to move data to
// and from the L2 cache. Operations are enqueued here after the read stage 
// in the L2 pipeline.  When misses are fulfilled, they are reissued into the
// pipeline via the arbiter.
//
// If the request for this line is already being handled, we set a bit
// in the FIFO that will cause the request to be reissued, but won't actually
// perform the memory transaction.
//

`include "l2_cache.h"

module l2_cache_smi
	(input clk,
	output stall_pipeline,
	input						rd_pci_valid,
	input[1:0]					rd_pci_unit,
	input[1:0]					rd_pci_strand,
	input[2:0]					rd_pci_op,
	input[1:0]					rd_pci_way,
	input[25:0]					rd_pci_address,
	input[511:0]				rd_pci_data,
	input[63:0]					rd_pci_mask,
	input  						rd_has_sm_data,
	input [511:0] 				rd_sm_data,
	input [1:0] 				rd_replace_l2_way,
	input  						rd_cache_hit,
	input[511:0] 				rd_cache_mem_result,
	input[`L2_TAG_WIDTH - 1:0] 	rd_replace_l2_tag,
	input 						rd_replace_is_dirty,
	input						duplicate_request,	// If this is already being handled (somewhere in the pipeline)
	output						smi_duplicate_request,
	output[1:0]					smi_pci_unit,				
	output[1:0]					smi_pci_strand,
	output[2:0]					smi_pci_op,
	output[1:0]					smi_pci_way,
	output[25:0]				smi_pci_address,
	output[511:0]				smi_pci_data,
	output[63:0]				smi_pci_mask,
	output [511:0] 				smi_load_buffer_vec,
	output reg					smi_data_ready = 0,
	output[1:0]					smi_fill_l2_way,
	output [31:0]				addr_o,
	output reg 					request_o = 0,
	input 						ack_i,
	output 						write_o,
	input [31:0]				data_i,
	output [31:0]				data_o);

	wire[`L2_SET_INDEX_WIDTH - 1:0] set_index = rd_pci_address[`L2_SET_INDEX_WIDTH - 1:0];
	wire			enqueue_writeback_request = rd_replace_is_dirty && rd_pci_valid && rd_has_sm_data;
	wire[25:0]		writeback_address = { rd_replace_l2_tag, set_index };

	wire[511:0]		smi_writeback_data;	
	wire 			smi_enqueue_writeback_request;
	wire[25:0]		smi_writeback_address;

	wire smi_can_enqueue;
	wire enqueue_load_request = rd_pci_valid && !rd_cache_hit && !rd_has_sm_data;
	assign stall_pipeline = enqueue_load_request && !smi_can_enqueue;
	wire load_request_pending;
	wire writeback_pending;
	reg writeback_complete = 0;

	localparam REQUEST_QUEUE_LENGTH = 8;
	localparam REQUEST_QUEUE_ADDR_WIDTH = $clog2(REQUEST_QUEUE_LENGTH);

	sync_fifo #(538, REQUEST_QUEUE_LENGTH, REQUEST_QUEUE_ADDR_WIDTH) writeback_queue(
		.clk(clk),
		.flush_i(1'b0),
		.can_enqueue_o(),
		.enqueue_i(enqueue_writeback_request),
		.value_i({
			writeback_address,	// Old address
			rd_cache_mem_result	// Old line to writeback
		}),
		.can_dequeue_o(writeback_pending),
		.dequeue_i(writeback_complete),
		.value_o({
			smi_writeback_address,
			smi_writeback_data
		}));

	sync_fifo #(614, REQUEST_QUEUE_LENGTH, REQUEST_QUEUE_ADDR_WIDTH) load_queue(
		.clk(clk),
		.flush_i(1'b0),
		.can_enqueue_o(smi_can_enqueue),
		.enqueue_i(enqueue_load_request),
		.value_i(
			{ 
				duplicate_request,
				rd_replace_l2_way,			// which way to fill
				rd_pci_unit,
				rd_pci_strand,
				rd_pci_op,
				rd_pci_way,
				rd_pci_address,
				rd_pci_data,
				rd_pci_mask
			}),
		.can_dequeue_o(load_request_pending),
		.dequeue_i(smi_data_ready),
		.value_o(
			{ 
				smi_duplicate_request,
				smi_fill_l2_way,
				smi_pci_unit,
				smi_pci_strand,
				smi_pci_op,
				smi_pci_way,
				smi_pci_address,
				smi_pci_data,
				smi_pci_mask
			}));

	localparam STATE_IDLE = 0;
	localparam STATE_WRITE0 = 1;
	localparam STATE_WRITE1 = 2;
	localparam STATE_READ0 = 3;
	localparam STATE_READ1 = 4;
	localparam STATE_READ2 = 5;
	localparam STATE_WAIT_ISSUE = 6;

	localparam BURST_LENGTH = 16;	// 4 bytes per transfer, cache line is 64 bytes

	reg[2:0] state_ff = 0;
	reg[2:0] state_nxt = 0;
	reg[3:0] burst_offset_ff = 0;
	reg[3:0] burst_offset_nxt = 0;
	reg[31:0] smi_load_buffer[0:15];
	assign smi_load_buffer_vec = {
		smi_load_buffer[0],
		smi_load_buffer[1],
		smi_load_buffer[2],
		smi_load_buffer[3],
		smi_load_buffer[4],
		smi_load_buffer[5],
		smi_load_buffer[6],
		smi_load_buffer[7],
		smi_load_buffer[8],
		smi_load_buffer[9],
		smi_load_buffer[10],
		smi_load_buffer[11],
		smi_load_buffer[12],
		smi_load_buffer[13],
		smi_load_buffer[14],
		smi_load_buffer[15]
	};

	always @*
	begin
		state_nxt = state_ff;
		smi_data_ready = 0;
		burst_offset_nxt = burst_offset_ff;
		request_o = 0;
		writeback_complete = 0;

		case (state_ff)
			STATE_IDLE:
			begin	
				// Writebacks take precendence over loads, because we need to avoid
				// a race condition where we load stale data.  Since writebacks
				// can only be initiated as the side effect of a load, they can't starve
				// them.
				if (writeback_pending)
					state_nxt = STATE_WRITE0;
				else if (load_request_pending)
				begin
					if (smi_duplicate_request)
						state_nxt = STATE_WAIT_ISSUE;	// Just re-issue request
					else
						state_nxt = STATE_READ0;
				end
			end

			STATE_WRITE0:
			begin
				request_o = 1;
				burst_offset_nxt = 0;
				state_nxt = STATE_WRITE1;
			end

			STATE_WRITE1:
			begin
				request_o = 1;
				if (ack_i)
				begin
					if (burst_offset_ff == BURST_LENGTH - 2)
					begin
						writeback_complete = 1;
						state_nxt = STATE_IDLE;
					end

					burst_offset_nxt = burst_offset_ff + 1;
				end
			end

			STATE_READ0:
			begin
				request_o = 1;
				burst_offset_nxt = 0;
				state_nxt = STATE_READ1;
			end

			STATE_READ1:
			begin
				request_o = 1;
				if (ack_i)
				begin
					if (burst_offset_ff == BURST_LENGTH - 2)
						state_nxt = STATE_READ2;

					burst_offset_nxt = burst_offset_ff + 1;
				end
			end

			STATE_READ2:
			begin
				// XXX assumes we get an ack.  request_o needs to be async
				// to handle the case where there is not an ack here.
				state_nxt = STATE_WAIT_ISSUE;
			end

			STATE_WAIT_ISSUE:
			begin
				// Make sure the response is in the pipeline
				state_nxt = STATE_IDLE;
				smi_data_ready = 1;
			end
		endcase
	end

	always @(posedge clk)
	begin
		if ((state_ff == STATE_READ1 || state_ff == STATE_READ2) && ack_i)
			smi_load_buffer[burst_offset_ff] <= #1 data_i;
	end

	assign data_o = smi_writeback_data >> ((15 - burst_offset_nxt) * 32); 
	assign addr_o = write_o
		? { smi_writeback_address, 6'd0 } + { burst_offset_nxt, 2'd0 }
		: { smi_pci_address, 6'd0 } + { burst_offset_nxt, 2'd0 };
	assign write_o = state_ff == STATE_WRITE0 || state_ff == STATE_WRITE1;

	always @(posedge clk)
	begin
		state_ff <= #1 state_nxt;
		burst_offset_ff <= #1 burst_offset_nxt;
	end
endmodule
