//
// This is currently stubbed out for one thread.  When multiple threads
// are added, it will need to choose one thread each cycle and dispatch it.
//

module strand_select_stage(
	input					clk,

	input [31:0]			instruction0_i,
	input					instruction_valid0_i,
	input [31:0]			pc0_i,
	input					flush0_i,
	input					suspend_strand0_i,
	input					resume_strand0_i,
	output					next_instruction0_o,
	input [31:0]			restart_strided_offset0_i,
	input [3:0]				restart_reg_lane0_i,

	input [31:0]			instruction1_i,
	input					instruction_valid1_i,
	input [31:0]			pc1_i,
	input					flush1_i,
	input					suspend_strand1_i,
	input					resume_strand1_i,
	output					next_instruction1_o,
	input [31:0]			restart_strided_offset1_i,
	input [3:0]				restart_reg_lane1_i,

	input [31:0]			instruction2_i,
	input					instruction_valid2_i,
	input [31:0]			pc2_i,
	input					flush2_i,
	input					suspend_strand2_i,
	input					resume_strand2_i,
	output					next_instruction2_o,
	input [31:0]			restart_strided_offset2_i,
	input [3:0]				restart_reg_lane2_i,

	input [31:0]			instruction3_i,
	input					instruction_valid3_i,
	input [31:0]			pc3_i,
	input					flush3_i,
	input					suspend_strand3_i,
	input					resume_strand3_i,
	output					next_instruction3_o,
	input [31:0]			restart_strided_offset3_i,
	input [3:0]				restart_reg_lane3_i,

	output [31:0]			pc_o,
	output [31:0]			instruction_o,
	output [3:0]			reg_lane_select_o,
	output [31:0]			strided_offset_o);

	wire[31:0]				pc0;
	wire[31:0]				instruction0;
	wire[3:0]				reg_lane_select0;
	wire[31:0]				strided_offset0;
	wire[31:0]				pc1;
	wire[31:0]				instruction1;
	wire[3:0]				reg_lane_select1;
	wire[31:0]				strided_offset1;
	wire[31:0]				pc2;
	wire[31:0]				instruction2;
	wire[3:0]				reg_lane_select2;
	wire[31:0]				strided_offset2;
	wire[31:0]				pc3;
	wire[31:0]				instruction3;
	wire[3:0]				reg_lane_select3;
	wire[31:0]				strided_offset3;

	strand_fsm s0(
		.clk(clk),
		.instruction_i(instruction0_i),
		.instruction_valid_i(instruction_valid0_i),
		.grant_i(1'b1),		// XXX hardcoded
		.issue_request_o(),
		.pc_i(pc0_i),
		.flush_i(flush0_i),
		.next_instruction_o(next_instruction0_o),
		.suspend_strand_i(suspend_strand0_i),
		.resume_strand_i(resume_strand0_i),
		.restart_strided_offset_i(restart_strided_offset0_i),
		.restart_reg_lane_i(restart_reg_lane0_i),
		.pc_o(pc0),
		.instruction_o(instruction0),
		.reg_lane_select_o(reg_lane_select0),
		.strided_offset_o(strided_offset0));

	strand_fsm s1(
		.clk(clk),
		.instruction_i(instruction1_i),
		.instruction_valid_i(instruction_valid1_i),
		.grant_i(1'b1),	// XXX hardcoded
		.issue_request_o(),
		.pc_i(pc1_i),
		.flush_i(flush1_i),
		.next_instruction_o(next_instruction1_o),
		.suspend_strand_i(suspend_strand1_i),
		.resume_strand_i(resume_strand1_i),
		.restart_strided_offset_i(restart_strided_offset1_i),
		.restart_reg_lane_i(restart_reg_lane1_i),
		.pc_o(pc1),
		.instruction_o(instruction1),
		.reg_lane_select_o(reg_lane_select1),
		.strided_offset_o(strided_offset1));

	strand_fsm s2(
		.clk(clk),
		.instruction_i(instruction2_i),
		.instruction_valid_i(instruction_valid2_i),
		.grant_i(1'b1),		// XXX hardcoded
		.issue_request_o(),
		.pc_i(pc2_i),
		.flush_i(flush2_i),
		.next_instruction_o(next_instruction2_o),
		.suspend_strand_i(suspend_strand2_i),
		.resume_strand_i(resume_strand2_i),
		.restart_strided_offset_i(restart_strided_offset2_i),
		.restart_reg_lane_i(restart_reg_lane2_i),
		.pc_o(pc2),
		.instruction_o(instruction2),
		.reg_lane_select_o(reg_lane_select2),
		.strided_offset_o(strided_offset2));

	strand_fsm s3(
		.clk(clk),
		.instruction_i(instruction3_i),
		.instruction_valid_i(instruction_valid3_i),
		.grant_i(1'b1),	// XXX hardcoded
		.issue_request_o(),
		.pc_i(pc3_i),
		.flush_i(flush3_i),
		.next_instruction_o(next_instruction3_o),
		.suspend_strand_i(suspend_strand3_i),
		.resume_strand_i(resume_strand3_i),
		.restart_strided_offset_i(restart_strided_offset3_i),
		.restart_reg_lane_i(restart_reg_lane3_i),
		.pc_o(pc3),
		.instruction_o(instruction3),
		.reg_lane_select_o(reg_lane_select3),
		.strided_offset_o(strided_offset3));
		
	// Output mux (XXX hard coded to first strand for now)
	assign pc_o = pc0;
	assign instruction_o = instruction0;
	assign reg_lane_select_o = reg_lane_select0;
	assign strided_offset_o = strided_offset0;

endmodule
