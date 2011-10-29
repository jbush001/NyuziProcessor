//
// A stub for now, but will eventually reconcile rollback requests from
// multiple stages and threads.
//

module rollback_controller(
	input 						clk,
	input						rollback_request_i,
	input [31:0]				rollback_address_i,
	output						flush_request_o,
	output						restart_request_o,
	output [31:0]				restart_address_o);
	
	assign flush_request_o = rollback_request_i;
	assign restart_request_o = rollback_request_i;
	assign restart_address_o = rollback_address_i;
	
endmodule
