//
// Reconcile rollback requests from multiple stages and strands.
//

module rollback_controller(
	input 						clk,
	input						rollback_request1_i, 	// execute
	input [31:0]				rollback_address1_i, 
	input						rollback_request2_i,	// memory access
	input [31:0]				rollback_address2_i,
	input [31:0]				rollback_strided_offset2_i,
	input [3:0]					rollback_reg_lane2_i,
	input						rollback_request3_i, 	// writeback
	input [31:0]				rollback_address3_i,
	output reg					flush_request1_o,		// strand select
	output reg					flush_request2_o,		// decode
	output reg					flush_request3_o,		// execute
	output reg					flush_request4_o,		// memory access
	output 						restart_request_o,
	output reg[31:0]			restart_address_o,
	output reg[31:0]			restart_strided_offset_o,
	output reg[3:0]				restart_reg_lane_o);
	
	initial
	begin
		flush_request1_o = 0;
		flush_request2_o = 0;
		flush_request3_o = 0;
		flush_request4_o = 0;
		restart_address_o = 0;
		restart_strided_offset_o = 0;
		restart_reg_lane_o = 0;
	end
	
	assign restart_request_o = rollback_request3_i || rollback_request2_i 
		|| rollback_request1_i;
	
	// Priority encoder picks the oldest instruction in the case
	// where multiple rollbacks are requested simultaneously.
	always @*
	begin
		if (rollback_request3_i)	// writeback
		begin
			flush_request1_o = 1;
			flush_request2_o = 1;
			flush_request3_o = 1;
			flush_request4_o = 1;
			restart_address_o = rollback_address3_i;
			restart_strided_offset_o = 0;
			restart_reg_lane_o = 0;
		end
		else if (rollback_request2_i)	// memory access
		begin
			flush_request1_o = 1;
			flush_request2_o = 1;
			flush_request3_o = 1;
			flush_request4_o = 0;
			restart_address_o = rollback_address2_i;
			restart_strided_offset_o = rollback_strided_offset2_i;
			restart_reg_lane_o = rollback_reg_lane2_i;
		end
		else if (rollback_request1_i)	// execute
		begin
			flush_request1_o = 1;
			flush_request2_o = 1;
			flush_request3_o = 0;
			flush_request4_o = 0;
			restart_address_o = rollback_address1_i;
			restart_strided_offset_o = 0;
			restart_reg_lane_o = 0;
		end
		else
		begin
			flush_request1_o = 0;
			flush_request2_o = 0;
			flush_request3_o = 0;
			flush_request4_o = 0;
			restart_address_o = 0;	// Don't care
			restart_strided_offset_o = 0;
			restart_reg_lane_o = 0;
		end
	end
endmodule
