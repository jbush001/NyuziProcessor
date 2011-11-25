//
// Queue pending stores.
// If a read is attempted of a non-committed write in the store buffer,
// we'll need to determine that and return the value from here.  Also,
// if a write is queued where a write is already pending, update
// the existing entry. 
//

module store_buffer
	#(parameter DEPTH = 4,
	parameter INDEX_WIDTH = 2, 
	parameter ADDR_SIZE = 26)
	(input 						clk,
	input [ADDR_SIZE - 1:0]		addr_i,
	input [511:0]				data_i,
	input						write_i,
	input [63:0]				mask_i,
	output [511:0]				data_o,
	output reg[63:0]			mask_o
	
	// FIXME: need interface to store into L2 cache
	
	);

	reg 						fifo_valid[0:DEPTH - 1];	
	reg[ADDR_SIZE - 1:0]		fifo_addr[0:DEPTH - 1];
	reg[15:0]					fifo_mask[0:DEPTH - 1];
	reg							addr_in_fifo;
	reg[INDEX_WIDTH - 1:0]		hit_entry;
	reg[INDEX_WIDTH - 1:0]		head_ptr;
	reg[INDEX_WIDTH - 1:0]		tail_ptr;
	reg[INDEX_WIDTH - 1:0]		port0_addr;
	integer						i;
	
	/// FIXME: check for full condition and avoid messing up state

	//
	// CAM lookup.  Determine if the requested address is already in the
	// store buffer.
	//
	always @*
	begin
		addr_in_fifo = 0;
		hit_entry = 0;

		for (i = 0; i < DEPTH; i = i + 1)
		begin
			if (fifo_valid[i] && fifo_addr[i] === addr_i)
			begin
				addr_in_fifo = 1;
				hit_entry = i;
			end
		end
	end

	// Determine whether we are updating/reading an existing entry or
	// adding to the tail.
	always @*
	begin
		if (addr_in_fifo)
			port0_addr = hit_entry;	
		else
			port0_addr = tail_ptr;	
	end

	// FIFO data storage
	mem512 #(DEPTH, INDEX_WIDTH) fifo_data(
		.clk(clk),

		// FIFO head update/readback
		.port0_addr_i(port0_addr),
		.port0_data_i(data_i),
		.port0_data_o(data_o),
		.port0_write_i(write_i),
		.port0_byte_enable_i(mask_i),

		// This port is read only.  The synthesis tools should 
		// optimize the write port away...
		.port1_addr_i(head_ptr),
		.port1_data_i(512'd0),
		.port1_data_o(),
		.port1_write_i(0));

	always @(posedge clk)
	begin
		if (write_i)
		begin
			if (addr_in_fifo) 
			begin
				// Update existing FIFO item
				fifo_mask[port0_addr] 	<= #1 fifo_mask[port0_addr] | mask_i;
			end
			else
			begin
				// Put a new item into the FIFO
				fifo_valid[port0_addr] 	<= #1 1;
				fifo_mask[port0_addr] 	<= #1 mask_i;
				tail_ptr 				<= #1 tail_ptr + 1;
			end
		end
	end

	always @(posedge clk)
	begin
		if (addr_in_fifo)
			mask_o <= #1 fifo_mask[port0_addr];
		else
			mask_o <= #1 0;
	end

endmodule
