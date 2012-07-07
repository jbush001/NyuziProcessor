//
// Simulates system memory
//

module sim_memory
	#(parameter MEM_SIZE = 'h40000)	// Number of 32-bit words

	(input					clk,
	input[31:0]				sm_addr,
	input					sm_request,
	output reg				sm_ack = 0,
	input					sm_write,
	output [31:0]			data_from_sm,
	input [31:0]			data_to_sm);

	reg[31:0] memory[0:MEM_SIZE - 1];
	reg[31:0] read_addr = 0;
	integer i;

	initial
	begin
		for (i = 0; i < MEM_SIZE; i = i + 1)
			memory[i] = 0;
	end

	always @(posedge clk)
	begin
		if (sm_request)
		begin
			if (sm_addr[31:2] > MEM_SIZE)
			begin
				// Note that this isn't necessarily indicative of a hardware bug,
				// but could just be a bad memory address produced by software
				$display("L2 cache accessed invalid address %x", sm_addr);
				$finish;
			end

			if (sm_write)
				memory[sm_addr[31:2]] <= #1 data_to_sm;
			else
				read_addr <= #1 sm_addr;
		end

		sm_ack <= #1 sm_request;
	end

	assign data_from_sm = memory[read_addr[31:2]];
endmodule
