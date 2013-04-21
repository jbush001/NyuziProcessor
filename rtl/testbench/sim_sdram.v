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

//
// Simulates SDR SDRAM
//

module sim_sdram
	#(parameter				DATA_WIDTH = 32,
	parameter				ROW_ADDR_WIDTH = 12, // 4096 rows
	parameter				COL_ADDR_WIDTH = 8) // 256 columns

	(input					clk, 
	input					cke, 
	input					cs_n, 
	input					ras_n, 
	input					cas_n, 
	input					we_n,		// Write enable
	input[1:0]				ba, 		// Bank select
	input					dqmh,
	input					dqml,
	input[11:0]				addr,
	inout[DATA_WIDTH - 1:0]	dq);
	
	parameter 				MEM_SIZE = 'h40000;	// Number of DATA_WIDTH words

	reg[9:0]				mode_register_ff = 0;
	reg[3:0]				bank_active = 0;
	reg[3:0]				bank_cas_delay[0:3];
	reg[ROW_ADDR_WIDTH - 1:0] bank_active_row[0:3];
	reg[DATA_WIDTH - 1:0]   memory[0:MEM_SIZE - 1];
	integer					i;
	integer					bank;
	reg[15:0]				refresh_delay = 0;

	// Current burst info
	reg						burst_w = 0; // If true, is a write burst.  Otherwise, read burst
	reg						burst_active = 0;
	reg[3:0]				burst_count_ff = 0;	// How many transfers have occurred
	reg[1:0]				burst_bank = 0;
	reg						burst_auto_precharge = 0;	
	reg[10:0]				burst_column_address = 0;
	reg[3:0]				burst_read_delay_count = 0;
	reg						cke_ff = 0;
	reg						initialized = 0;

	initial
	begin
		for (i = 0; i < 4; i = i + 1)
			bank_active_row[i] = 0;

		for (i = 0; i < MEM_SIZE; i = i + 1)
			memory[i] = 0;
	end

	wire[3:0] cas_delay = mode_register_ff[6:4];

	always @(posedge clk)
		cke_ff <= #1 cke;

	// Decode command
	wire command_enable = cke_ff & ~cs_n;
	wire req_load_mode = command_enable & ~ras_n & ~cas_n & ~we_n;
	wire req_auto_refresh = command_enable & ~ras_n & ~cas_n & we_n;
	wire req_precharge = command_enable & ~ras_n & cas_n & ~we_n;
	wire req_activate = command_enable & ~ras_n & cas_n & we_n;
	wire req_write_burst = command_enable & ras_n & ~cas_n & ~we_n;
	wire req_read_burst = command_enable & ras_n & ~cas_n & we_n;

	// Burst count
	always @(posedge clk)
	begin
		if (req_write_burst)
			burst_count_ff <= #1 1;	// Count the first transfer, which has already occurred
		else if (req_read_burst)
			burst_count_ff <= #1 0;
		else if (burst_active && cke_ff && (burst_w || burst_read_delay_count === 0))
			burst_count_ff <= #1 burst_count_ff + 1;
	end

	// Bank active
	always @(posedge clk)
	begin
		if (req_precharge)
		begin
			if (addr[10])
			begin
//				$display("precharge all");
				bank_active <= #1 4'b0;		// precharge all rows
			end
			else
			begin
//				$display("precharge bank %d", ba);
				bank_active[ba] <= #1 1'b0;	// precharge
			end
			
			initialized <= 1;
		end
		else if (req_activate)
		begin
			if (bank_active[ba])
			begin
				$display("attempt to activate a bank that is already active %d", ba);
				$finish;
			end

//			$display("bank %d activated row %d", ba, addr[ROW_ADDR_WIDTH - 1:0]);
			bank_active[ba] <= #1 1'b1;
			bank_active_row[ba] <= #1 addr[ROW_ADDR_WIDTH - 1:0];
		end
		else if (burst_count_ff == burst_length - 1 && burst_active && cke_ff
			&& burst_auto_precharge)
			bank_active[burst_bank] <= #1 1'b0;	// Auto-precharge				
	end	

	// Mode register
	always @(posedge clk)
	begin
		if (req_load_mode)
		begin
//			$display("latching mode %x", addr[9:0]);
			mode_register_ff <= #1 addr[9:0];
		end
	end

	// Burst read delay count
	always @(posedge clk)
	begin
		if (req_read_burst)
			burst_read_delay_count <= #1 cas_delay - 1; // Note: there is one extra cycle of latency in read
		else if (burst_active && cke_ff && ~burst_w)
		begin
			if (burst_read_delay_count > 0)
				burst_read_delay_count <= #1 burst_read_delay_count - 1;
		end
	end

	// Burst active
	always @(posedge clk)
	begin
		if (req_write_burst || req_read_burst)
			burst_active <= #1 1'b1;
		else if (burst_count_ff >= burst_length - 1 && burst_active)
			burst_active <= #1 1'b0; // Burst is complete
	end

	always @(posedge clk)
	begin
		if (req_write_burst || req_read_burst)
		begin
			if (~bank_active[ba])
			begin
				$display("burst requested for bank %d that is not active\n", ba);
				$finish;
			end

			if (bank_cas_delay[ba] > 0)
			begin
				$display("CAS latency violation: burst requested on bank %d before active\n",
					ba);
				$finish;
			end

//			$display("start %s transfer bank %d row %d column %d", 
//				req_write_burst ? "write" : "read", ba,
//				bank_active_row[ba], addr[COL_ADDR_WIDTH - 1:0]);
			burst_w <= #1 req_write_burst;
			burst_bank <= #1 ba;
			burst_auto_precharge <= #1 addr[10];
			burst_column_address <= #1 addr[COL_ADDR_WIDTH - 1:0];
		end
		else if (req_auto_refresh)
		begin
			if (bank_active != 0)
			begin
				$display("attempt to auto-refresh with opened rows");
				$finish;
			end

			// XXX perhaps record time of this refresh, which we can check
			// later
//			$display("auto refresh");
		end
	end
	
	// Check that we're being refreshed enough
	always @(posedge clk)
	begin
		if (req_auto_refresh)
			refresh_delay <= #1 0;
		else if (refresh_delay > 775)
		begin
			$display("Did not refresh!");
			$finish;
		end
		else if (initialized)
			refresh_delay <= #1 refresh_delay + 1;
	end
	

	// RAM write
	always @(posedge clk)
	begin
		if (burst_active && cke_ff && burst_w)
			memory[burst_address] <= #1 dq;	// Write
		else if (req_write_burst)
			memory[{ bank_active_row[ba], ba, addr[7:0] }] <= #1 dq;	// Latch first word
	end

	// RAM read
	wire[DATA_WIDTH - 1:0] output_reg = memory[burst_address];

	assign dq = (burst_w || req_write_burst) ? 16'dZ : output_reg;

	// Make sure client is respecting CAS latency.
	always @(posedge clk)
	begin
		if (req_activate)
			bank_cas_delay[ba] <= #1 cas_delay - 2;

		for (bank = 0; bank < 4; bank = bank + 1)
		begin
			if (bank_cas_delay[bank] > 0 && (ba != bank || ~req_activate))
				bank_cas_delay[bank] <= #1 bank_cas_delay[bank] - 1;
		end
	end

	//
	// Burst transfer logic
	//
	wire[3:0] burst_length = 1 << mode_register_ff[2:0];
	wire burst_interleaved = mode_register_ff[3];	
	wire[7:0] burst_address_offset = burst_interleaved
		? burst_column_address ^ burst_count_ff
		: burst_column_address + burst_count_ff;
	wire[25:0] burst_address = { bank_active_row[burst_bank], burst_bank, burst_address_offset };
endmodule
