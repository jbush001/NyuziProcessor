//
// CPU pipeline instruction fetch stage.
// Issues requests to L1 cache to keep 4 instruction FIFOs (one for each strand) loaded.
//

module instruction_fetch_stage(
	input							clk,
	output reg[31:0]				icache_addr,
	input [31:0]					icache_data,
	input                           icache_hit,
	output							icache_request,
	output [1:0]					icache_req_strand,
	input [3:0]						icache_load_complete_strands,
	input							icache_load_collision,

	output [31:0]					if_instruction0,
	output							if_instruction_valid0,
	output [31:0]					if_pc0,
	input							ss_instruction_req0,
	input							rb_rollback_strand0,
	input [31:0]					rb_rollback_pc0,

	output [31:0]					if_instruction1,
	output							if_instruction_valid1,
	output [31:0]					if_pc1,
	input							ss_instruction_req1,
	input							rb_rollback_strand1,
	input [31:0]					rb_rollback_pc1,

	output [31:0]					if_instruction2,
	output							if_instruction_valid2,
	output [31:0]					if_pc2,
	input							ss_instruction_req2,
	input							rb_rollback_strand2,
	input [31:0]					rb_rollback_pc2,

	output [31:0]					if_instruction3,
	output							if_instruction_valid3,
	output [31:0]					if_pc3,
	input							ss_instruction_req3,
	input							rb_rollback_strand3,
	input [31:0]					rb_rollback_pc3);
	
	reg[31:0]						program_counter0_ff = 0;
	reg[31:0]						program_counter0_nxt = 0;
	reg[31:0]						program_counter1_ff = 0;
	reg[31:0]						program_counter1_nxt = 0;
	reg[31:0]						program_counter2_ff = 0;
	reg[31:0]						program_counter2_nxt = 0;
	reg[31:0]						program_counter3_ff = 0;
	reg[31:0]						program_counter3_nxt = 0;
	wire							request0;
	wire							request1;
	wire							request2;
	wire							request3;
	reg[3:0]						instruction_cache_wait_ff = 0;
	reg[3:0]						instruction_cache_wait_nxt = 0;

	// This stores the last strand that issued a request to the cache (since results
	// have one cycle of latency, we need to remember this).
	reg[3:0]						cache_request_ff = 0;
	wire[3:0]						cache_request_nxt;

	// Issue least recently issued strand.  Don't issue strands that we know are
	// waiting on the cache.
	arbiter4 request_arb(
		.clk(clk),
		.req0(request0 & !instruction_cache_wait_nxt[0]),
		.req1(request1 & !instruction_cache_wait_nxt[1]),
		.req2(request2 & !instruction_cache_wait_nxt[2]),
		.req3(request3 & !instruction_cache_wait_nxt[3]),
		.update_lru(1'b1),
		.grant0(cache_request_nxt[0]),
		.grant1(cache_request_nxt[1]),
		.grant2(cache_request_nxt[2]),
		.grant3(cache_request_nxt[3]));
	
	assign icache_request = |cache_request_nxt;

	always @*
	begin
		case (cache_request_nxt)
			4'b1000: icache_addr = program_counter3_nxt;
			4'b0100: icache_addr = program_counter2_nxt;
			4'b0010: icache_addr = program_counter1_nxt;
			4'b0001: icache_addr = program_counter0_nxt;
			4'b0000: icache_addr = program_counter0_nxt;	// Don't care
			default: icache_addr = {32{1'bx}};	// Shouldn't happen
		endcase
	end

	assign icache_req_strand = { cache_request_nxt[2] | cache_request_nxt[3],
		cache_request_nxt[1] | cache_request_nxt[3] };	// Convert one-hot to index
	
	// Keep track of which strands are waiting on an icache fetch.
	always @*
	begin
		if (!icache_hit && cache_request_ff && !icache_load_collision)
		begin
			instruction_cache_wait_nxt = (instruction_cache_wait_ff & ~icache_load_complete_strands)
				| cache_request_ff;
		end
		else
		begin
			instruction_cache_wait_nxt = instruction_cache_wait_ff
				& ~icache_load_complete_strands;
		end
	end
	
	wire almost_full0;
	wire almost_full1;
	wire almost_full2;
	wire almost_full3;
	wire full0;
	wire full1;
	wire full2;
	wire full3;
	wire empty0;
	wire empty1;
	wire empty2;
	wire empty3;

	wire enqueue0 = icache_hit && cache_request_ff[0];
	wire enqueue1 = icache_hit && cache_request_ff[1];
	wire enqueue2 = icache_hit && cache_request_ff[2];
	wire enqueue3 = icache_hit && cache_request_ff[3];
	assign request0 = !full0 && !(almost_full0 && enqueue0);	// de-assert a cycle early
	assign request1 = !full1 && !(almost_full1 && enqueue1);
	assign request2 = !full2 && !(almost_full2 && enqueue2);
	assign request3 = !full3 && !(almost_full3 && enqueue3);

	assign if_instruction_valid0 = !empty0;
	assign if_instruction_valid1 = !empty1;
	assign if_instruction_valid2 = !empty2;
	assign if_instruction_valid3 = !empty3;

	sync_fifo if0(
		.clk(clk),
		.flush_i(rb_rollback_strand0),
		.almost_full_o(almost_full0),
		.full_o(full0),
		.enqueue_i(enqueue0),
		.value_i({ program_counter0_nxt, icache_data[7:0], icache_data[15:8], 
			icache_data[23:16], icache_data[31:24] }),
		.empty_o(empty0),
		.dequeue_i(ss_instruction_req0 && if_instruction_valid0),	// FIXME instruction_valid_o is redundant
		.value_o({ if_pc0, if_instruction0 }));

	sync_fifo if1(
		.clk(clk),
		.flush_i(rb_rollback_strand1),
		.almost_full_o(almost_full1),
		.full_o(full1),
		.enqueue_i(enqueue1),
		.value_i({ program_counter1_nxt, icache_data[7:0], icache_data[15:8], 
			icache_data[23:16], icache_data[31:24] }),
		.empty_o(empty1),
		.dequeue_i(ss_instruction_req1 && if_instruction_valid1),	// FIXME instruction_valid_o is redundant
		.value_o({ if_pc1, if_instruction1 }));

	sync_fifo if2(
		.clk(clk),
		.flush_i(rb_rollback_strand2),
		.almost_full_o(almost_full2),
		.full_o(full2),
		.enqueue_i(enqueue2),
		.value_i({ program_counter2_nxt, icache_data[7:0], icache_data[15:8], 
			icache_data[23:16], icache_data[31:24] }),
		.empty_o(empty2),
		.dequeue_i(ss_instruction_req2 && if_instruction_valid2),	// FIXME instruction_valid_o is redundant
		.value_o({ if_pc2, if_instruction2 }));

	sync_fifo if3(
		.clk(clk),
		.flush_i(rb_rollback_strand3),
		.almost_full_o(almost_full3),
		.full_o(full3),
		.enqueue_i(enqueue3),
		.value_i({ program_counter3_nxt, icache_data[7:0], icache_data[15:8], 
			icache_data[23:16], icache_data[31:24] }),
		.empty_o(empty3),
		.dequeue_i(ss_instruction_req3 && if_instruction_valid3),	// FIXME instruction_valid_o is redundant
		.value_o({ if_pc3, if_instruction3 }));

	always @*
	begin
		if (rb_rollback_strand0)
			program_counter0_nxt = rb_rollback_pc0;
		else if (!icache_hit || !cache_request_ff[0])	
			program_counter0_nxt = program_counter0_ff;
		else
			program_counter0_nxt = program_counter0_ff + 32'd4;
	end

	always @*
	begin
		if (rb_rollback_strand1)
			program_counter1_nxt = rb_rollback_pc1;
		else if (!icache_hit || !cache_request_ff[1])	
			program_counter1_nxt = program_counter1_ff;
		else
			program_counter1_nxt = program_counter1_ff + 32'd4;
	end

	always @*
	begin
		if (rb_rollback_strand2)
			program_counter2_nxt = rb_rollback_pc2;
		else if (!icache_hit || !cache_request_ff[2])	
			program_counter2_nxt = program_counter2_ff;
		else
			program_counter2_nxt = program_counter2_ff + 32'd4;
	end

	always @*
	begin
		if (rb_rollback_strand3)
			program_counter3_nxt = rb_rollback_pc3;
		else if (!icache_hit || !cache_request_ff[3])	
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
		instruction_cache_wait_ff <= #1 instruction_cache_wait_nxt;
	end

	// This shouldn't happen in our simulations normally.  Since it can be hard
	// to detect, check it explicitly.
	assertion #("thread 0 was rolled back to address 0") a0(.clk(clk),
		.test(rb_rollback_strand0 && rb_rollback_pc0 == 0));
	assertion #("thread 1 was rolled back to address 0") a1(.clk(clk),
		.test(rb_rollback_strand1 && rb_rollback_pc1 == 0));
	assertion #("thread 2 was rolled back to address 0") a2(.clk(clk),
		.test(rb_rollback_strand2 && rb_rollback_pc2 == 0));
	assertion #("thread 3 was rolled back to address 0") a3(.clk(clk),
		.test(rb_rollback_strand3 && rb_rollback_pc3 == 0));
endmodule
