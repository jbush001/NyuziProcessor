// 
// Copyright 2012 Jeff Bush
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


module sdram_controller
	#(parameter					DATA_WIDTH = 32,
	parameter					ROW_ADDR_WIDTH = 12, // 4096 rows
	parameter					COL_ADDR_WIDTH = 8, // 256 columns
	
	// These are expressed in numbers of clocks. Each one is the number
	// of clocks of delay minus one.  Need to compute this
	// based on the part specifications and incoming clock rate.
	// 50 Mhz = 20ns clock.
	parameter					T_POWERUP = 10000,		// 200 us
	parameter					T_ROW_PRECHARGE = 1,		// (~21 ns)
	parameter					T_AUTO_REFRESH_CYCLE = 3,	// (~75 ns) 
	parameter					T_RAS_CAS_DELAY = 1,		// (~21 ns) 
	parameter					T_REFRESH = 750,			// 64 ms / 4096 cycles (15 uS)
	parameter					T_CAS_LATENCY = 1)			// 21 ns. (2 cycles)
	
	(input						clk,
	input						reset,
	
	// Interface to SDRAM	
	output						dram_clk,
	output 						cke, 
	output 						cs_n, 
	output 						ras_n, 
	output 						cas_n, 
	output 						we_n,
	output reg[1:0]				ba,
	output reg[11:0] 			addr,
	output						dqmh,
	output						dqml,
	inout [DATA_WIDTH - 1:0]	dq,
	
	// Interface to bus	
	input [31:0]				axi_awaddr,   // Write address channel
	input [7:0]					axi_awlen,
	input						axi_awvalid,
	output						axi_awready,
	input [31:0]				axi_wdata,    // Write data channel
	input 						axi_wlast,
	input 						axi_wvalid,
	output						axi_wready,
	output						axi_bvalid,   // Write response channel
	input						axi_bready,
	input [31:0]    			axi_araddr,   // Read address channel
	input [7:0]					axi_arlen,
	input 						axi_arvalid,
	output						axi_arready,
	input 						axi_rready,   // Read data channel
	output						axi_rvalid,         
	output [31:0]				axi_rdata,
	
	// Performance counter events
	output reg					pc_event_dram_page_miss,
	output reg					pc_event_dram_page_hit);

	localparam 					BURST_LENGTH = 8;
	
	localparam					STATE_INIT0 = 0;	
	localparam					STATE_INIT1 = 1;	
	localparam					STATE_INIT2 = 2;	
	localparam					STATE_INIT3 = 3;	
	localparam					STATE_IDLE = 4;
	localparam					STATE_AUTO_REFRESH0 = 5;
	localparam					STATE_AUTO_REFRESH1 = 6;
	localparam					STATE_OPEN_ROW = 7;
	localparam					STATE_READ_BURST = 8;
	localparam					STATE_WRITE_BURST = 9;
	localparam 					STATE_CAS_WAIT = 10;	
	localparam					STATE_POWERUP = 11;
	localparam					STATE_CLOSE_ROW = 12;
	
	localparam					CMD_MODE_REGISTER_SET = 4'b0000;
	localparam					CMD_AUTO_REFRESH = 4'b0001;
	localparam					CMD_PRECHARGE = 4'b0010;
	localparam					CMD_ACTIVATE = 4'b0011;
	localparam					CMD_WRITE = 4'b0100;
	localparam					CMD_READ = 4'b0101;
	localparam					CMD_NOP = 4'b1000;
	
	reg[11:0]					refresh_timer_ff = T_REFRESH;
	reg[11:0]					refresh_timer_nxt;
	reg[14:0]					timer_ff;
	reg[14:0]					timer_nxt;
	reg[3:0] 					command = CMD_NOP;
	reg[3:0]					state_ff = STATE_POWERUP;
	reg[3:0]					state_nxt = STATE_POWERUP;
	reg[3:0]					burst_offset_ff;
	reg[3:0]					burst_offset_nxt;
	reg[ROW_ADDR_WIDTH - 1:0] 	active_row[0:3];
	reg							bank_active[0:3];
	reg							output_enable;
	wire[DATA_WIDTH - 1:0]		write_data;
	integer						i;
	reg[31:0]					write_address;
	reg[7:0]					write_length;
	reg							write_pending;
	reg[31:0]					read_address;
	reg[7:0]					read_length;
	reg							read_pending;
	wire						lfifo_empty;
	wire						sfifo_full;
	wire[1:0] 					write_bank;
	wire[COL_ADDR_WIDTH - 1:0] 	write_column;
	wire[ROW_ADDR_WIDTH - 1:0] 	write_row;
	wire[1:0] 					read_bank;
	wire[COL_ADDR_WIDTH - 1:0] 	read_column;
	wire[ROW_ADDR_WIDTH - 1:0] 	read_row;
	reg 						lfifo_enqueue;
	reg							access_is_read_ff;
	reg							access_is_read_nxt;

	assign axi_arready = !read_pending;
	assign axi_awready = !write_pending;
	assign axi_rvalid = !lfifo_empty;
	assign axi_wready = !sfifo_full;

	sync_fifo #(DATA_WIDTH, BURST_LENGTH) load_fifo(
		.clk(clk),
		.reset(reset),
		.flush_i(1'b0),
		.full_o(),
		.empty_o(lfifo_empty),
		.value_i(dq),
		.enqueue_i(lfifo_enqueue),
		.dequeue_i(axi_rready && axi_rvalid),
		.value_o(axi_rdata));

	sync_fifo #(DATA_WIDTH, BURST_LENGTH) store_fifo(
		.clk(clk),
		.reset(reset),
		.flush_i(1'b0),
		.full_o(sfifo_full),
		.value_o(write_data),
		.dequeue_i(output_enable),
		.value_i(axi_wdata),
		.enqueue_i(axi_wready && !sfifo_full),
		.empty_o());
	
	assign { cs_n, ras_n, cas_n, we_n } = command;
	assign cke = 1;
	assign dram_clk = clk;
	assign { write_row, write_bank, write_column } = 
		write_address[31:$clog2(DATA_WIDTH / 8)];
	assign { read_row, read_bank, read_column } = 
		read_address[31:$clog2(DATA_WIDTH / 8)];
		
	assign dq = output_enable ? write_data : {DATA_WIDTH{1'hZ}};
	
	// Next state logic
	always @*
	begin
		// Default values
		output_enable = 0;
		command = CMD_NOP;
		timer_nxt = 0;
		burst_offset_nxt = 0;
		state_nxt = state_ff;
		ba = 0;
		addr = 0;
		pc_event_dram_page_miss = 0;
		pc_event_dram_page_hit = 0;

		lfifo_enqueue = 0;
		if (refresh_timer_ff != 0)
			refresh_timer_nxt = refresh_timer_ff - 1;
		else
			refresh_timer_nxt = 0;

		if (timer_ff != 0)
			timer_nxt = timer_ff - 1; // Wait for timer to expire...
		else
		begin
			// Progress to next state.
			case (state_ff)
				STATE_POWERUP:
				begin
					timer_nxt = T_POWERUP;	// Wait for clock to be stable
					state_nxt = STATE_INIT0;
				end
			
				STATE_INIT0:
				begin
					// Step 1: send precharge all command
					addr = {ROW_ADDR_WIDTH{1'b1}};
					command = CMD_PRECHARGE;
					timer_nxt = T_ROW_PRECHARGE;
					state_nxt = STATE_INIT1;
				end
			
				STATE_INIT1:
				begin
					// Step 2: send two auto refresh commands
					addr = {ROW_ADDR_WIDTH{1'b1}};
					command = CMD_AUTO_REFRESH;
					timer_nxt = T_AUTO_REFRESH_CYCLE; 
					state_nxt = STATE_INIT2;
				end
				
				STATE_INIT2:
				begin
					addr = {ROW_ADDR_WIDTH{1'b1}};
					command = CMD_AUTO_REFRESH;
					timer_nxt = T_AUTO_REFRESH_CYCLE; 
					state_nxt = STATE_INIT3;
				end
			
				STATE_INIT3:
				begin
					// Step 3: set the mode register
					command = CMD_MODE_REGISTER_SET;
					addr = 12'b00_0_00_010_0_011;	// Note: CAS latency is 2
					ba = 2'b00;
					state_nxt = STATE_IDLE;
				end
				
				STATE_IDLE:
				begin
					if (refresh_timer_ff == 0)
					begin
						// Need to perform an auto-refresh cycle.  If any rows are open,
						// precharge all of them now.  Otherwise proceed directly to
						// refresh.
						if (bank_active[0] | bank_active[1] | bank_active[2] | bank_active[3])
							state_nxt = STATE_AUTO_REFRESH0;
						else
							state_nxt = STATE_AUTO_REFRESH1;
					end
					else if (lfifo_empty && write_pending)	// XXX lfifo_empty may not be necessary
					begin
						// Start a write burst
						access_is_read_nxt = 0;
						if (!bank_active[write_bank])
						begin
							pc_event_dram_page_miss = 1;
							state_nxt = STATE_OPEN_ROW;	// Row is not open, do that
						end
						else if (write_row != active_row[write_bank])	
						begin
							pc_event_dram_page_miss = 1;
							state_nxt = STATE_CLOSE_ROW; // Different row open in this bank, close
						end
						else
						begin
							pc_event_dram_page_hit = 1;
							state_nxt = STATE_WRITE_BURST;
						end
					end
					else if (lfifo_empty && read_pending)
					begin
						// Start a read burst
						access_is_read_nxt = 1;
						if (!bank_active[read_bank])
						begin
							pc_event_dram_page_miss = 1;
							state_nxt = STATE_OPEN_ROW;	// Row is not open, do that
						end
						else if (read_row != active_row[read_bank])	
						begin
							pc_event_dram_page_miss = 1;
							state_nxt = STATE_CLOSE_ROW; // Different row open in this bank, close
						end
						else
						begin
							pc_event_dram_page_hit = 1;
							state_nxt = STATE_CAS_WAIT;			
						end
					end
				end

				STATE_CLOSE_ROW:
				begin
					// Precharge a single bank that has an open row in preparation
					// for a transfer.
					addr = {ROW_ADDR_WIDTH{1'b0}};
					if (access_is_read_ff)
						ba = read_bank;
					else
						ba = write_bank;
					
					command = CMD_PRECHARGE;
					timer_nxt = T_ROW_PRECHARGE;
					state_nxt = STATE_OPEN_ROW;
				end
				
				STATE_OPEN_ROW:
				begin
					// Open a row
					if (access_is_read_ff)
					begin
						ba = read_bank;
						addr = read_row;
						state_nxt = STATE_CAS_WAIT;
					end
					else
					begin
						ba = write_bank;
						addr = write_row;
						state_nxt = STATE_WRITE_BURST;
					end
					command = CMD_ACTIVATE;
					timer_nxt = T_RAS_CAS_DELAY;
				end
				
				STATE_CAS_WAIT:
				begin
					command = CMD_READ;
					addr = { 4'd0, read_column };
					ba = read_bank;
					timer_nxt = T_CAS_LATENCY;
					state_nxt = STATE_READ_BURST;
				end
				
				STATE_READ_BURST:
				begin
					lfifo_enqueue = 1;
					burst_offset_nxt = burst_offset_ff + 1;
					if (burst_offset_ff == BURST_LENGTH - 1)
						state_nxt = STATE_IDLE;
				end
				
				STATE_WRITE_BURST:
				begin
					output_enable = 1;
					if (burst_offset_ff == 0)
					begin
						// On first cycle
						ba = write_bank;
						addr = { 4'd0, write_column };
						command = CMD_WRITE;	
					end

					burst_offset_nxt = burst_offset_ff + 1;
					if (burst_offset_ff == BURST_LENGTH - 1)
						state_nxt = STATE_IDLE;
				end

				STATE_AUTO_REFRESH0:
				begin
					// Precharge all rows before we perform an auto-refresh
					addr = 12'b010000000000;		// XXX parameterize
					command = CMD_PRECHARGE;
					timer_nxt = T_ROW_PRECHARGE;
					state_nxt = STATE_AUTO_REFRESH1;
				end

				STATE_AUTO_REFRESH1:
				begin
					command = CMD_AUTO_REFRESH;
					timer_nxt = T_AUTO_REFRESH_CYCLE;
					refresh_timer_nxt = T_REFRESH;
					state_nxt = STATE_IDLE;
				end
			endcase
		end
	end

	assign dqmh = 0;
	assign dqml = 0;

	assert_false #("invalid write burst length") a0(
		.clk(clk),
		.test(axi_awvalid && (axi_awlen & (BURST_LENGTH - 1)) != 0));

	assert_false #("invalid write burst address") a1(
		.clk(clk),
		.test(axi_awvalid && (axi_awaddr & (BURST_LENGTH - 1)) != 0));

	assert_false #("invalid read burst length") a2(
		.clk(clk),
		.test(axi_arvalid && (axi_arlen & (BURST_LENGTH - 1)) != 0));

	assert_false #("invalid read burst address") a3(
		.clk(clk),
		.test(axi_arvalid && (axi_araddr & (BURST_LENGTH - 1)) != 0));

	always @(posedge clk, posedge reset)
	begin
		if (reset)
		begin
			for (i = 0; i < 4; i = i + 1)
			begin
				active_row[i] <= 0;
				bank_active[i] <= 0;
			end
			
			/*AUTORESET*/
			// Beginning of autoreset for uninitialized flops
			access_is_read_ff <= 1'h0;
			burst_offset_ff <= 4'h0;
			read_address <= 32'h0;
			read_length <= 8'h0;
			read_pending <= 1'h0;
			refresh_timer_ff <= 12'h0;
			state_ff <= 4'h0;
			timer_ff <= 15'h0;
			write_address <= 32'h0;
			write_length <= 8'h0;
			write_pending <= 1'h0;
			// End of automatics
		end
		else
		begin
			// SDRAM control
			state_ff <= state_nxt;
			timer_ff <= timer_nxt;
			burst_offset_ff <= burst_offset_nxt;
			refresh_timer_ff <= refresh_timer_nxt;
			access_is_read_ff <= access_is_read_nxt;
			if (state_ff == STATE_OPEN_ROW)
			begin
				if (access_is_read_ff)
				begin
					active_row[read_bank] <= read_row;
					bank_active[read_bank] <= 1;
				end
				else
				begin
					active_row[write_bank] <= write_row;
					bank_active[write_bank] <= 1;
				end
			end
			else if (state_ff == STATE_AUTO_REFRESH0)
			begin
				// The precharge all command will close all active banks
				bank_active[0] <= 0;
				bank_active[1] <= 0;
				bank_active[2] <= 0;
				bank_active[3] <= 0;
			end
			
			// Bus Interface
			if (write_pending && state_ff == STATE_WRITE_BURST &&
				state_nxt != STATE_WRITE_BURST)
			begin
				// The bus transfer may be longer than the SDRAM burst.  
				// Determine if we are done yet.
				write_length <= write_length - BURST_LENGTH;
				write_address <= write_address + (BURST_LENGTH * 4);
				if (write_length == BURST_LENGTH)
					write_pending <= 0;
			end
			else if (axi_awvalid && !write_pending)
			begin
				write_address <= axi_awaddr;
				write_length <= axi_awlen;
				write_pending <= 1'b1;
			end

			if (read_pending && state_ff == STATE_READ_BURST &&
				state_nxt != STATE_READ_BURST)
			begin
				read_length <= read_length - BURST_LENGTH;
				read_address <= read_address + (BURST_LENGTH * 4);
				if (read_length == BURST_LENGTH)
					read_pending <= 0;
			end
			else if (axi_arvalid && !read_pending)
			begin
				read_address <= axi_araddr;
				read_length <= axi_arlen;
				read_pending <= 1'b1;
			end
		end
	end
endmodule
