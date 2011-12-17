//
// Keep 4 instruction FIFOs (one for each strand) loaded.
//

module instruction_fetch_stage(
	input							clk,
	output reg[31:0]				iaddress_o,
	input [31:0]					idata_i,
	input                           icache_hit_i,
	output							iaccess_o,

	output [31:0]					instruction0_o,
	output							instruction_ack0_o,
	output [31:0]					pc0_o,
	input							instruction_request0_i,
	input							restart_request0_i,
	input [31:0]					restart_address0_i,

	output [31:0]					instruction1_o,
	output							instruction_ack1_o,
	output [31:0]					pc1_o,
	input							instruction_request1_i,
	input							restart_request1_i,
	input [31:0]					restart_address1_i,

	output [31:0]					instruction2_o,
	output							instruction_ack2_o,
	output [31:0]					pc2_o,
	input							instruction_request2_i,
	input							restart_request2_i,
	input [31:0]					restart_address2_i,

	output [31:0]					instruction3_o,
	output							instruction_ack3_o,
	output [31:0]					pc3_o,
	input							instruction_request3_i,
	input							restart_request3_i,
	input [31:0]					restart_address3_i);
	
	reg[31:0]						program_counter0_ff;
	reg[31:0]						program_counter0_nxt;
	reg[31:0]						program_counter1_ff;
	reg[31:0]						program_counter1_nxt;
	reg[31:0]						program_counter2_ff;
	reg[31:0]						program_counter2_nxt;
	reg[31:0]						program_counter3_ff;
	reg[31:0]						program_counter3_nxt;
	wire							request0;
	wire							request1;
	wire							request2;
	wire							request3;

	// This stores the last strand that issued a request to the cache (since results
	// have one cycle of latency, we need to remember this).
	reg[3:0]						cache_request_ff;
	wire[3:0]						cache_request_nxt;

	initial
	begin
		program_counter0_ff = 0;
		program_counter0_nxt = 0;
		program_counter1_ff = 0;
		program_counter1_nxt = 0;
		program_counter2_ff = 0;
		program_counter2_nxt = 0;
		program_counter3_ff = 0;
		program_counter3_nxt = 0;
		cache_request_ff = 0;
		iaddress_o = 0;
	end

	arbiter4 request_arb(
		.clk(clk),
		.req0_i(request0),
		.req1_i(request1),
		.req2_i(request2),
		.req3_i(request3),
		.grant0_o(cache_request_nxt[0]),
		.grant1_o(cache_request_nxt[1]),
		.grant2_o(cache_request_nxt[2]),
		.grant3_o(cache_request_nxt[3]));
	
	assign iaccess_o = request0 || request1 || request2 || request3;

	always @*
	begin
		case (cache_request_nxt)
			4'b1000: iaddress_o = program_counter3_nxt;
			4'b0100: iaddress_o = program_counter2_nxt;
			4'b0010: iaddress_o = program_counter1_nxt;
			4'b0001: iaddress_o = program_counter0_nxt;
			default: iaddress_o = 0;
		endcase
	end

	instruction_fifo if0(
		.clk(clk),
		.flush_i(restart_request0_i),
		.instruction_request_o(request0),
		.enqueue_i(icache_hit_i && cache_request_ff[0]),
		.value_i({ program_counter0_nxt, idata_i[7:0], idata_i[15:8], 
			idata_i[23:16], idata_i[31:24] }),
		.instruction_ready_o(instruction_ack0_o),
		.dequeue_i(instruction_request0_i && instruction_ack0_o),	// FIXME instruction_ack_o is redundant
		.value_o({ pc0_o, instruction0_o }));

	instruction_fifo if1(
		.clk(clk),
		.flush_i(restart_request1_i),
		.instruction_request_o(request1),
		.enqueue_i(icache_hit_i && cache_request_ff[1]),
		.value_i({ program_counter1_nxt, idata_i[7:0], idata_i[15:8], 
			idata_i[23:16], idata_i[31:24] }),
		.instruction_ready_o(instruction_ack1_o),
		.dequeue_i(instruction_request1_i && instruction_ack1_o),	// FIXME instruction_ack_o is redundant
		.value_o({ pc1_o, instruction1_o }));

	instruction_fifo if2(
		.clk(clk),
		.flush_i(restart_request2_i),
		.instruction_request_o(request2),
		.enqueue_i(icache_hit_i && cache_request_ff[2]),
		.value_i({ program_counter2_nxt, idata_i[7:0], idata_i[15:8], 
			idata_i[23:16], idata_i[31:24] }),
		.instruction_ready_o(instruction_ack2_o),
		.dequeue_i(instruction_request2_i && instruction_ack2_o),	// FIXME instruction_ack_o is redundant
		.value_o({ pc2_o, instruction2_o }));

	instruction_fifo if3(
		.clk(clk),
		.flush_i(restart_request3_i),
		.instruction_request_o(request3),
		.enqueue_i(icache_hit_i && cache_request_ff[3]),
		.value_i({ program_counter3_nxt, idata_i[7:0], idata_i[15:8], 
			idata_i[23:16], idata_i[31:24] }),
		.instruction_ready_o(instruction_ack3_o),
		.dequeue_i(instruction_request3_i && instruction_ack3_o),	// FIXME instruction_ack_o is redundant
		.value_o({ pc3_o, instruction3_o }));
	
	always @*
	begin
		if (restart_request0_i)
			program_counter0_nxt = restart_address0_i;
		else if (!icache_hit_i || !cache_request_ff[0])	
			program_counter0_nxt = program_counter0_ff;
		else
			program_counter0_nxt = program_counter0_ff + 32'd4;
	end

	always @*
	begin
		if (restart_request1_i)
			program_counter1_nxt = restart_address1_i;
		else if (!icache_hit_i || !cache_request_ff[1])	
			program_counter1_nxt = program_counter1_ff;
		else
			program_counter1_nxt = program_counter1_ff + 32'd4;
	end

	always @*
	begin
		if (restart_request2_i)
			program_counter2_nxt = restart_address2_i;
		else if (!icache_hit_i || !cache_request_ff[2])	
			program_counter2_nxt = program_counter2_ff;
		else
			program_counter2_nxt = program_counter2_ff + 32'd4;
	end

	always @*
	begin
		if (restart_request3_i)
			program_counter3_nxt = restart_address3_i;
		else if (!icache_hit_i || !cache_request_ff[3])	
			program_counter3_nxt = program_counter3_ff;
		else
			program_counter3_nxt = program_counter3_ff + 32'd4;
	end

	always @(posedge clk)
	begin
		program_counter0_ff <= #1 program_counter0_nxt;
		program_counter1_ff <= #1 program_counter1_nxt;
		program_counter2_ff <= #1 program_counter2_nxt;
		program_counter3_ff <= #1 program_counter3_nxt;
		cache_request_ff <= #1 cache_request_nxt;
	end
endmodule
