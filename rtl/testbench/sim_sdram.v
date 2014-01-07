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

//`define SDRAM_DEBUG 

module sim_sdram
	#(parameter				DATA_WIDTH = 32,
	parameter				ROW_ADDR_WIDTH = 12, // 4096 rows
	parameter				COL_ADDR_WIDTH = 8, // 256 columns
	parameter				MEM_SIZE='h40000) 

	(input					clk, 
	input					dram_cke, 
	input					dram_cs_n, 
	input					dram_ras_n, 
	input					dram_cas_n, 
	input					dram_we_n,		// Write enable
	input[1:0]				dram_ba, 		// Bank select
	input[12:0]				dram_addr,
	inout[DATA_WIDTH - 1:0]	dram_dq);

	reg[9:0]				mode_register_ff = 0;
	reg[3:0]				bank_active = 0;
	reg[3:0]				bank_cas_delay[0:3];
	reg[ROW_ADDR_WIDTH - 1:0] bank_active_row[0:3];
	reg[DATA_WIDTH - 1:0]   memory[0:MEM_SIZE - 1] /*verilator public*/;
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
	wire[3:0] burst_length;
	wire burst_interleaved;
	wire[COL_ADDR_WIDTH - 1:0] burst_address_offset;
	wire[25:0] burst_address;

	initial
	begin
		for (i = 0; i < 4; i = i + 1)
			bank_active_row[i] = 0;

		for (i = 0; i < MEM_SIZE; i = i + 1)
			memory[i] = 0;
	end

	wire[3:0] cas_delay = mode_register_ff[6:4];

	always @(posedge clk)
		cke_ff <= dram_cke;

	// Decode command
	wire command_enable = cke_ff & ~dram_cs_n;
	wire req_load_mode = command_enable & ~dram_ras_n & ~dram_cas_n & ~dram_we_n;
	wire req_auto_refresh = command_enable & ~dram_ras_n & ~dram_cas_n & dram_we_n;
	wire req_precharge = command_enable & ~dram_ras_n & dram_cas_n & ~dram_we_n;
	wire req_activate = command_enable & ~dram_ras_n & dram_cas_n & dram_we_n;
	wire req_write_burst = command_enable & dram_ras_n & ~dram_cas_n & ~dram_we_n;
	wire req_read_burst = command_enable & dram_ras_n & ~dram_cas_n & dram_we_n;

	// Burst count
	always @(posedge clk)
	begin
		if (req_write_burst)
			burst_count_ff <= 1;	// Count the first transfer, which has already occurred
		else if (req_read_burst)
			burst_count_ff <= 0;
		else if (burst_active && cke_ff && (burst_w || burst_read_delay_count === 0))
			burst_count_ff <= burst_count_ff + 1;
	end

	// Bank active
	always @(posedge clk)
	begin
		if (req_precharge)
		begin
			if (dram_addr[10])
			begin
`ifdef SDRAM_DEBUG
				$display("precharge all");
`endif
				bank_active <= 4'b0;		// precharge all rows
			end
			else
			begin
`ifdef SDRAM_DEBUG
				$display("precharge bank %d", dram_ba);
`endif
				bank_active[dram_ba] <= 1'b0;	// precharge
			end
			
			initialized <= 1;
		end
		else if (req_activate)
		begin
			if (bank_active[dram_ba])
			begin
				$display("attempt to activate a bank that is already active %d", dram_ba);
				$finish;
			end

`ifdef SDRAM_DEBUG
			$display("bank %d activated row %d", dram_ba, dram_addr[ROW_ADDR_WIDTH - 1:0]);
`endif
			bank_active[dram_ba] <= 1'b1;
			bank_active_row[dram_ba] <= dram_addr[ROW_ADDR_WIDTH - 1:0];
		end
		else if (burst_count_ff == burst_length - 1 && burst_active && cke_ff
			&& burst_auto_precharge)
			bank_active[burst_bank] <= 1'b0;	// Auto-precharge				
	end	

	// Mode register
	always @(posedge clk)
	begin
		if (req_load_mode)
		begin
`ifdef SDRAM_DEBUG
			$display("latching mode %x", dram_addr[9:0]);
`endif
			mode_register_ff <= dram_addr[9:0];
		end
	end

	// Burst read delay count
	always @(posedge clk)
	begin
		if (req_read_burst)
			burst_read_delay_count <= cas_delay - 1; // Note: there is one extra cycle of latency in read
		else if (burst_active && cke_ff && ~burst_w)
		begin
			if (burst_read_delay_count > 0)
				burst_read_delay_count <= burst_read_delay_count - 1;
		end
	end

	// Burst active
	always @(posedge clk)
	begin
		if (req_write_burst || req_read_burst)
			burst_active <= 1'b1;
		else if (burst_count_ff >= burst_length - 1 && burst_active)
			burst_active <= 1'b0; // Burst is complete
	end

	always @(posedge clk)
	begin
		if (req_write_burst || req_read_burst)
		begin
			if (~bank_active[dram_ba])
			begin
				$display("burst requested for bank %d that is not active\n", dram_ba);
				$finish;
			end

			if (bank_cas_delay[dram_ba] > 0)
			begin
				$display("CAS latency violation: burst requested on bank %d before active\n",
					dram_ba);
				$finish;
			end

`ifdef SDRAM_DEBUG
			$display("start %s transfer bank %d row %d column %d", 
				req_write_burst ? "write" : "read", dram_ba,
				bank_active_row[dram_ba], dram_addr[COL_ADDR_WIDTH - 1:0]);
`endif
			burst_w <= req_write_burst;
			burst_bank <= dram_ba;
			burst_auto_precharge <= dram_addr[10];
			burst_column_address <= dram_addr[COL_ADDR_WIDTH - 1:0];
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
`ifdef SDRAM_DEBUG
			$display("auto refresh");
`endif
		end
	end
	
	// Check that we're being refreshed enough
	always @(posedge clk)
	begin
		if (req_auto_refresh)
			refresh_delay <= 0;
		else if (refresh_delay > 775)
		begin
			$display("Did not refresh!");
			$finish;
		end
		else if (initialized)
			refresh_delay <= refresh_delay + 1;
	end
	

	// RAM write
	always @(posedge clk)
	begin
		if (burst_active && cke_ff && burst_w)
			memory[burst_address] <= dram_dq;	// Write
		else if (req_write_burst)
			memory[{ bank_active_row[dram_ba], dram_ba, dram_addr[COL_ADDR_WIDTH - 1:0] }] <= dram_dq;	// Latch first word

		if ((burst_active && cke_ff && burst_w) || req_write_burst)
		begin
			if ((dram_dq ^ dram_dq) !== 0)
			begin
				// Z or X value.
				$display("%m: write value is %d", dram_dq);
				$finish;
			end
		end

`ifdef SDRAM_DEBUG
	if ((burst_active && cke_ff && burst_w) || req_write_burst)
		$display(" write %08x", dram_dq);
	else if (burst_active && !burst_w && !req_write_burst)
		$display(" read %08x", dram_dq);
`endif
	end

	// RAM read
	wire[DATA_WIDTH - 1:0] output_reg = memory[burst_address];

	assign dram_dq = (burst_w || req_write_burst) ? {DATA_WIDTH{1'hZ}} : output_reg;

	// Make sure client is respecting CAS latency.
	always @(posedge clk)
	begin
		if (req_activate)
			bank_cas_delay[dram_ba] <= cas_delay - 2;

		for (bank = 0; bank < 4; bank = bank + 1)
		begin
			if (bank_cas_delay[bank] > 0 && (dram_ba != bank || ~req_activate))
				bank_cas_delay[bank] <= bank_cas_delay[bank] - 1;
		end
	end

	//
	// Burst count logic
	//
	assign burst_length = 1 << mode_register_ff[2:0];
	assign burst_interleaved = mode_register_ff[3];	
	assign burst_address_offset = burst_interleaved
		? burst_column_address ^ burst_count_ff
		: burst_column_address + burst_count_ff;
	assign burst_address = { bank_active_row[burst_bank], burst_bank, burst_address_offset };
endmodule
