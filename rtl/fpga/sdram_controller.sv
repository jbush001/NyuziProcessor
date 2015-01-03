// 
// Copyright (C) 2011-2014 Jeff Bush
// 
// This library is free software; you can redistribute it and/or
// modify it under the terms of the GNU Library General Public
// License as published by the Free Software Foundation; either
// version 2 of the License, or (at your option) any later version.
// 
// This library is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
// Library General Public License for more details.
// 
// You should have received a copy of the GNU Library General Public
// License along with this library; if not, write to the
// Free Software Foundation, Inc., 51 Franklin St, Fifth Floor,
// Boston, MA  02110-1301, USA.
// 

`include "defines.sv"

//
// Drive control signals for single data rate (SDR) SDRAM, including performing
// auto refresh at appropriate intervals.  This is driven by an AXI bus interface.
// For performance, this lazily keeps rows open after accesses, tracking them 
// independently per bank and closing them only when necessary.
//

module sdram_controller
	#(parameter					DATA_WIDTH = 32,
	parameter					ROW_ADDR_WIDTH = 12, // 4096 rows
	parameter					COL_ADDR_WIDTH = 8, // 256 columns
	
	// These are expressed in numbers of clocks. Each one is the number
	// of clocks of delay minus one.  Need to compute this
	// based on the part specifications and incoming clock rate.
	parameter					T_POWERUP = 10000,
	parameter					T_ROW_PRECHARGE = 1,
	parameter					T_AUTO_REFRESH_CYCLE = 3,
	parameter					T_RAS_CAS_DELAY = 1,
	parameter					T_REFRESH = 750,
	parameter					T_CAS_LATENCY = 1)	
	
	(input						clk,
	input						reset,
	
	// Interface to SDRAM	
	output						dram_clk,
	output 						dram_cke, 
	output 						dram_cs_n, 
	output 						dram_ras_n, 
	output 						dram_cas_n, 
	output 						dram_we_n,
	output logic[1:0]			dram_ba,
	output logic[12:0] 			dram_addr,
	inout [DATA_WIDTH - 1:0]	dram_dq,
	
	// Interface to bus	
	axi_interface.slave         axi_bus,
	
	// Performance counter events
	output logic				pc_event_dram_page_miss,
	output logic				pc_event_dram_page_hit);

	localparam SDRAM_BURST_LENGTH = 8;
	
	typedef enum {
		STATE_INIT0,	
		STATE_INIT1,	
		STATE_INIT2,	
		STATE_INIT3,	
		STATE_IDLE,
		STATE_AUTO_REFRESH0,
		STATE_AUTO_REFRESH1,
		STATE_OPEN_ROW,
		STATE_READ_BURST,
		STATE_WRITE_BURST,
		STATE_CAS_WAIT,	
		STATE_POWERUP,
		STATE_CLOSE_ROW
	} burst_state_t;
	
	typedef enum logic[3:0] {
		CMD_MODE_REGISTER_SET = 4'b0000,
		CMD_AUTO_REFRESH      = 4'b0001,
		CMD_PRECHARGE         = 4'b0010,
		CMD_ACTIVATE          = 4'b0011,
		CMD_WRITE             = 4'b0100,
		CMD_READ              = 4'b0101,
		CMD_NOP               = 4'b1000	
	} sdram_cmd_t;
	
	// Note that all latched addresses and lengths are in terms of
	// DATA_WIDTH beats, not bytes.
	logic[11:0] refresh_timer_ff;
	logic[11:0] refresh_timer_nxt;
	logic[14:0] timer_ff;
	logic[14:0] timer_nxt;
	sdram_cmd_t command;
	burst_state_t state_ff;
	burst_state_t state_nxt;
	logic[3:0] burst_offset_ff;
	logic[3:0] burst_offset_nxt;
	logic[ROW_ADDR_WIDTH - 1:0] active_row[0:3];
	logic bank_active[0:3];
	logic output_enable;
	wire[DATA_WIDTH - 1:0] write_data;
	logic[31:0] write_address;
	logic[7:0] write_length;	// Like axi_bus.awlen, is num transfers - 1
	logic write_pending;
	logic[31:0] read_address;
	logic[7:0] read_length;	// Like axi_bus.arlen, is num_transfers - 1
	logic read_pending;
	wire lfifo_empty;
	wire sfifo_full;
	wire[1:0] write_bank;
	wire[COL_ADDR_WIDTH - 1:0] write_column;
	wire[ROW_ADDR_WIDTH - 1:0] write_row;
	wire[1:0] read_bank;
	wire[COL_ADDR_WIDTH - 1:0] read_column;
	wire[ROW_ADDR_WIDTH - 1:0] read_row;
	logic lfifo_enqueue;
	logic access_is_read_ff;
	logic access_is_read_nxt;

	assign axi_bus.arready = !read_pending;
	assign axi_bus.awready = !write_pending;
	assign axi_bus.rvalid = !lfifo_empty;
	assign axi_bus.wready = !sfifo_full;
	assign axi_bus.bvalid = 1;	// Hack: pretend we always have a write result

	// Each fifo can hold an entire SDRAM burst to avoid delays due
	// to the external bus.

	sync_fifo #(.WIDTH(DATA_WIDTH), .SIZE(SDRAM_BURST_LENGTH)) load_fifo(
		.clk(clk),
		.reset(reset),
		.flush_en(1'b0),
		.full(),
		.almost_empty(),
		.almost_full(),
		.empty(lfifo_empty),
		.value_i(dram_dq),
		.enqueue_en(lfifo_enqueue),
		.dequeue_en(axi_bus.rready && axi_bus.rvalid),
		.value_o(axi_bus.rdata));

	sync_fifo #(.WIDTH(DATA_WIDTH), .SIZE(SDRAM_BURST_LENGTH)) store_fifo(
		.clk(clk),
		.reset(reset),
		.flush_en(1'b0),
		.full(sfifo_full),
		.almost_empty(),
		.almost_full(),
		.value_o(write_data),
		.dequeue_en(output_enable),
		.value_i(axi_bus.wdata),
		.enqueue_en(axi_bus.wready && axi_bus.wvalid),
		.empty());
	
	assign { dram_cs_n, dram_ras_n, dram_cas_n, dram_we_n } = command;
	assign dram_cke = 1;
	assign dram_clk = clk;
	assign { write_row, write_bank, write_column } = write_address;
	assign { read_row, read_bank, read_column } = read_address;
		
	assign dram_dq = output_enable ? write_data : {DATA_WIDTH{1'hZ}};
	
	// Next state logic.  There are many cases where we want to delay between
	// states. In this case, timer_ff tracks how many cycles are remaining.
	// It is important to note that state_ff will point to the next state during
	// this interval, but the control signals associated with the state (in the case
	// below) won't be asserted until the timer counts down to zero.
	always_comb
	begin
		// Default values
		output_enable = 0;
		command = CMD_NOP;
		timer_nxt = 0;
		burst_offset_nxt = 0;
		state_nxt = state_ff;
		dram_ba = 0;
		dram_addr = 0;
		pc_event_dram_page_miss = 0;
		pc_event_dram_page_hit = 0;
		access_is_read_nxt = access_is_read_ff;

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
			unique case (state_ff)
				STATE_POWERUP:
				begin
					timer_nxt = T_POWERUP;	// Wait for clock to be stable
					state_nxt = STATE_INIT0;
				end
			
				STATE_INIT0:
				begin
					// Step 1: send precharge all command
					dram_addr = {ROW_ADDR_WIDTH{1'b1}};
					command = CMD_PRECHARGE;
					timer_nxt = T_ROW_PRECHARGE;
					state_nxt = STATE_INIT1;
				end
			
				STATE_INIT1:
				begin
					// Step 2: send two auto refresh commands
					dram_addr = {ROW_ADDR_WIDTH{1'b1}};
					command = CMD_AUTO_REFRESH;
					timer_nxt = T_AUTO_REFRESH_CYCLE; 
					state_nxt = STATE_INIT2;
				end
				
				STATE_INIT2:
				begin
					dram_addr = {ROW_ADDR_WIDTH{1'b1}};
					command = CMD_AUTO_REFRESH;
					timer_nxt = T_AUTO_REFRESH_CYCLE; 
					state_nxt = STATE_INIT3;
				end
			
				STATE_INIT3:
				begin
					// Step 3: set the mode register
					command = CMD_MODE_REGISTER_SET;
					dram_addr = 12'b00_0_00_010_0_011;	// Note: CAS latency is 2
					dram_ba = 2'b00;
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
					else if (lfifo_empty && read_pending 
						&& (!write_pending || write_address != read_address))
					begin
						// Start a read burst. Reads have priority to avoid starving
						// the VGA controller, but we check above to ensure there isn't 
						// a write already pending for this address (otherwise we will 
						// get stale data).
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
					else if (write_pending && sfifo_full 
						&& (!read_pending || write_address == read_address))
					begin
						// Start a write burst.  
						// We don't start the burst if a read is pending and the FIFO is full.
						// This is a hack to avoid starving the VGA controller.  However, do 
						// start the write if the read is for data we are about to write.
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
				end

				STATE_CLOSE_ROW:
				begin
					// Precharge a single bank that has an open row in preparation
					// for a transfer.
					dram_addr = {ROW_ADDR_WIDTH{1'b0}};
					if (access_is_read_ff)
						dram_ba = read_bank;
					else
						dram_ba = write_bank;
					
					command = CMD_PRECHARGE;
					timer_nxt = T_ROW_PRECHARGE;
					state_nxt = STATE_OPEN_ROW;
				end
				
				STATE_OPEN_ROW:
				begin
					// Open a row
					if (access_is_read_ff)
					begin
						dram_ba = read_bank;
						dram_addr = read_row;
						state_nxt = STATE_CAS_WAIT;
					end
					else
					begin
						dram_ba = write_bank;
						dram_addr = write_row;
						state_nxt = STATE_WRITE_BURST;
					end
					command = CMD_ACTIVATE;
					timer_nxt = T_RAS_CAS_DELAY;
				end
				
				STATE_CAS_WAIT:
				begin
					command = CMD_READ;
					dram_addr = read_column;
					dram_ba = read_bank;
					timer_nxt = T_CAS_LATENCY;
					state_nxt = STATE_READ_BURST;
				end
				
				STATE_READ_BURST:
				begin
					lfifo_enqueue = 1;
					burst_offset_nxt = burst_offset_ff + 1;
					if (burst_offset_ff == SDRAM_BURST_LENGTH - 1)
						state_nxt = STATE_IDLE;
				end
				
				STATE_WRITE_BURST:
				begin
					output_enable = 1;
					if (burst_offset_ff == 0)
					begin
						// On first cycle
						dram_ba = write_bank;
						dram_addr = write_column;
						command = CMD_WRITE;	
					end

					burst_offset_nxt = burst_offset_ff + 1;
					if (burst_offset_ff == SDRAM_BURST_LENGTH - 1)
						state_nxt = STATE_IDLE;
				end

				STATE_AUTO_REFRESH0:
				begin
					// Precharge all banks before we perform an auto-refresh
					dram_addr = 12'b010000000000;		// XXX parameterize
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

	always_ff @(posedge clk, posedge reset)
	begin
		if (reset)
		begin : doreset
			for (int i = 0; i < 4; i++)
			begin
				active_row[i] <= 0;
				bank_active[i] <= 0;
			end

			state_ff <= STATE_INIT0;
			refresh_timer_ff <= T_REFRESH;
			
			/*AUTORESET*/
			// Beginning of autoreset for uninitialized flops
			access_is_read_ff <= 1'h0;
			burst_offset_ff <= 4'h0;
			read_address <= 32'h0;
			read_length <= 8'h0;
			read_pending <= 1'h0;
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
				write_length <= write_length - SDRAM_BURST_LENGTH;
				write_address <= write_address + SDRAM_BURST_LENGTH;
				if (write_length == SDRAM_BURST_LENGTH - 1)
					write_pending <= 0;
			end
			else if (axi_bus.awvalid && !write_pending)
			begin
				// Ensure the the burst is aligned on an SDRAM burst boundary.
				assert(((axi_bus.awlen + 1) & (SDRAM_BURST_LENGTH - 1)) == 0);
				assert((axi_bus.awaddr & (SDRAM_BURST_LENGTH - 1)) == 0);

				// axi_bus.awaddr is in terms of bytes.  Convert to beats.
				write_address <= axi_bus.awaddr[31:$clog2(DATA_WIDTH / 8)];
				write_length <= axi_bus.awlen;
				write_pending <= 1'b1;
			end

			if (read_pending && state_ff == STATE_READ_BURST &&
				state_nxt != STATE_READ_BURST)
			begin
				read_length <= read_length - SDRAM_BURST_LENGTH;
				read_address <= read_address + SDRAM_BURST_LENGTH;
				if (read_length == SDRAM_BURST_LENGTH - 1) 
					read_pending <= 0;
			end
			else if (axi_bus.arvalid && !read_pending)
			begin
				// Ensure the the burst is aligned on an SDRAM burst boundary.
				assert(((axi_bus.arlen + 1) & (SDRAM_BURST_LENGTH - 1)) == 0);
				assert((axi_bus.araddr & (SDRAM_BURST_LENGTH - 1)) == 0);

				// axi_bus.araddr is in terms of bytes.  Convert to beats.
				read_address <= axi_bus.araddr[31:$clog2(DATA_WIDTH / 8)];
				read_length <= axi_bus.arlen;
				read_pending <= 1'b1;
			end
		end
	end
endmodule
