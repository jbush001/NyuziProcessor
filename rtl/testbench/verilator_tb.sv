//
// Copyright (C) 2014 Jeff Bush
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

`include "../core/defines.sv"

`define USE_SDRAM_CONTROLLER 1

//
// Testbench for CPU
//

module verilator_tb(
	input       clk, 
	input       reset);

	localparam MEM_SIZE = 'h400000;
	localparam TRACE_REORDER_QUEUE_LEN = 7;

	typedef enum logic [1:0] {
		TE_INVALID = 0,
		TE_SWRITEBACK,
		TE_VWRITEBACK,
		TE_STORE
	} trace_event_type_t;

	typedef struct packed {
		trace_event_type_t event_type;
		scalar_t pc;
		thread_idx_t thread_idx;
		register_idx_t writeback_reg;
		scalar_t addr;
		logic[`CACHE_LINE_BYTES - 1:0] mask;
		vector_t data;

		// Interrupts are piggybacked on other events
		logic interrupt_active;
		thread_idx_t interrupt_thread_idx;
		scalar_t interrupt_pc;
	} trace_event_t;
	
	int total_cycles = 0;
	logic[1000:0] filename;
	int do_register_trace;
	int do_state_trace;
	int state_trace_fd;
	int finish_cycles;
	int do_autoflush_l2;
	int do_profile;
	int profile_fd;
	logic processor_halt;
	l2rsp_packet_t l2_response;
	axi_interface axi_bus();
	scalar_t io_read_data;
	logic interrupt_req;
	int interrupt_counter;
	logic pc_event_dram_page_miss;	
	logic pc_event_dram_page_hit;
	trace_event_t trace_reorder_queue[TRACE_REORDER_QUEUE_LEN];
	logic[31:0] block_device_data['h200000];
	int block_device_read_offset;

	/*AUTOWIRE*/
	// Beginning of automatic wires (for undeclared instantiated-module outputs)
	logic [12:0]	dram_addr;		// From sdram_controller of sdram_controller.v
	logic [1:0]	dram_ba;		// From sdram_controller of sdram_controller.v
	wire		dram_cas_n;		// From sdram_controller of sdram_controller.v
	wire		dram_cke;		// From sdram_controller of sdram_controller.v
	wire		dram_clk;		// From sdram_controller of sdram_controller.v
	wire		dram_cs_n;		// From sdram_controller of sdram_controller.v
	wire [31:0]	dram_dq;		// To/From memory of sim_sdram.v, ...
	wire		dram_ras_n;		// From sdram_controller of sdram_controller.v
	wire		dram_we_n;		// From sdram_controller of sdram_controller.v
	scalar_t	io_address;		// From nyuzi of nyuzi.v
	wire		io_read_en;		// From nyuzi of nyuzi.v
	scalar_t	io_write_data;		// From nyuzi of nyuzi.v
	wire		io_write_en;		// From nyuzi of nyuzi.v
	// End of automatics

	`define CORE0 nyuzi.core_gen[0].core

	nyuzi nyuzi(
		.axi_bus(axi_bus),
		.*);

`ifdef USE_SDRAM_CONTROLLER
	sim_sdram #(
		.DATA_WIDTH(32),
		.ROW_ADDR_WIDTH(12),
		.COL_ADDR_WIDTH(8),
		.MEM_SIZE(MEM_SIZE)) memory(.*);
		
	sdram_controller #(
		.DATA_WIDTH(32),
		.ROW_ADDR_WIDTH(12),
		.COL_ADDR_WIDTH(8),
		.T_POWERUP(5)) sdram_controller(
			.axi_bus(axi_bus),
			.*);

	`define MEMORY memory.memory
`else
	// Otherwise, uses simpler SRAM model
	axi_internal_ram #(.MEM_SIZE(MEM_SIZE)) memory(
		.axi_bus(axi_bus),
		.loader_we(0),
		.loader_addr(0),
		.loader_data(0),
		.*);

	`define MEMORY memory.memory.data
`endif

	task flush_l2_line;
		input l2_tag_t tag;
		input l2_set_idx_t set;
		input l2_way_idx_t way;
	begin
		for (int line_offset = 0; line_offset < `CACHE_LINE_WORDS; line_offset++)
		begin
			`MEMORY[(tag * `L2_SETS + set) * `CACHE_LINE_WORDS + line_offset] = 
				nyuzi.l2_cache.l2_cache_read.sram_l2_data.data[{ way, set }]
				 >> ((`CACHE_LINE_WORDS - 1 - line_offset) * 32);
		end
	end
	endtask

	// Manually copy lines from the L2 cache back to memory so we can
	// validate it there.
	`define L2_TAG_WAY nyuzi.l2_cache.l2_cache_tag.way_tags_gen

	task flush_l2_cache;
	begin
		for (int set = 0; set < `L2_SETS; set++)
		begin
			// XXX these need to be manually commented out when changing 
			// the number of L2 ways, since it is not possible to 
			// access generated array instances when a dynamic variable.
			if (`L2_TAG_WAY[0].line_valid[set])
				flush_l2_line(`L2_TAG_WAY[0].sram_tags.data[set], set, 0);

			if (`L2_TAG_WAY[1].line_valid[set])
				flush_l2_line(`L2_TAG_WAY[1].sram_tags.data[set], set, 1);

			if (`L2_TAG_WAY[2].line_valid[set])
				flush_l2_line(`L2_TAG_WAY[2].sram_tags.data[set], set, 2);

			if (`L2_TAG_WAY[3].line_valid[set])
				flush_l2_line(`L2_TAG_WAY[3].sram_tags.data[set], set, 3);
		
			if (`L2_TAG_WAY[4].line_valid[set])
				flush_l2_line(`L2_TAG_WAY[4].sram_tags.data[set], set, 4);

			if (`L2_TAG_WAY[5].line_valid[set])
				flush_l2_line(`L2_TAG_WAY[5].sram_tags.data[set], set, 5);

			if (`L2_TAG_WAY[6].line_valid[set])
				flush_l2_line(`L2_TAG_WAY[6].sram_tags.data[set], set, 6);

			if (`L2_TAG_WAY[7].line_valid[set])
				flush_l2_line(`L2_TAG_WAY[7].sram_tags.data[set], set, 7);
		end
	end
	endtask

	// For fputw function, needed to write memory dumps
	`systemc_header
	#include "../testbench/verilator_include.h"	
	`verilog

	initial
	begin
		for (int i = 0; i < TRACE_REORDER_QUEUE_LEN; i++)
			trace_reorder_queue[i] = 0;

		if (!$value$plusargs("regtrace=%d", do_register_trace))
			do_register_trace = 0;
			
		if ($value$plusargs("statetrace=%d", do_state_trace))
			state_trace_fd = $fopen("statetrace.txt", "w");
		else
			do_state_trace = 0;
			
		if ($value$plusargs("profile=%s", filename))
		begin
			do_profile = 1;
			profile_fd = $fopen(filename, "w");
		end
		else
			do_profile = 0;

		for (int i = 0; i < MEM_SIZE; i++)
			`MEMORY[i] = 0;

		if ($value$plusargs("bin=%s", filename))
			$readmemh(filename, `MEMORY);
		else
		begin
			$display("error opening file");
			$finish;
		end
		
		// Virtual block device
		if ($value$plusargs("block=%s", filename))
		begin
			integer fd;
			int offset;

			fd = $fopen(filename, "rb");
			offset = 0;
			while (!$feof(fd))
			begin
				block_device_data[offset][7:0] = $fgetc(fd);
				block_device_data[offset][15:8] = $fgetc(fd);
				block_device_data[offset][23:16] = $fgetc(fd);
				block_device_data[offset][31:24] = $fgetc(fd);
				offset++;
			end

			$fclose(fd);
			$display("read %d into block device", offset * 4);
			block_device_read_offset = 0;
		end
	end

	final
	begin
		int mem_dump_start;
		int mem_dump_length;
		logic[31:0] mem_dat;
		int dump_fp;

		$display("ran for %d cycles", total_cycles);
		if ($value$plusargs("memdumpbase=%x", mem_dump_start)
			&& $value$plusargs("memdumplen=%x", mem_dump_length)
			&& $value$plusargs("memdumpfile=%s", filename))
		begin
			if ($value$plusargs("autoflushl2=%d", do_autoflush_l2))
				flush_l2_cache;

			dump_fp = $fopen(filename, "wb");
			for (int i = 0; i < mem_dump_length; i += 4)
			begin
				mem_dat = `MEMORY[(mem_dump_start + i) / 4];
				
				// fputw is defined in verilator_main.cpp and writes the
				// entire word out to the file.
				$c("fputw(", dump_fp, ",", mem_dat, ");");
			end

			$fclose(dump_fp);
		end	
		
		if (do_state_trace)
			$fclose(state_trace_fd);
			
		if (do_profile)
			$fclose(profile_fd);

		$display("performance counters:");
		$display(" l2_writeback          %d", nyuzi.performance_counters.event_counter[0]);
		$display(" l2_miss               %d", nyuzi.performance_counters.event_counter[1]);
		$display(" l2_hit                %d", nyuzi.performance_counters.event_counter[2]);
		
		if (`NUM_CORES == 1)
		begin
			// XXX currently does not work correctly with more than one core
			$display(" store rollback count  %d", nyuzi.performance_counters.event_counter[3]);
			$display(" store count           %d", nyuzi.performance_counters.event_counter[4]);
			$display(" instruction_retire    %d", nyuzi.performance_counters.event_counter[5]);
			$display(" instruction_issue     %d", nyuzi.performance_counters.event_counter[6]);
			$display(" l1i_miss              %d", nyuzi.performance_counters.event_counter[7]);
			$display(" l1i_hit               %d", nyuzi.performance_counters.event_counter[8]);
			$display(" l1d_miss              %d", nyuzi.performance_counters.event_counter[9]);
			$display(" l1d_hit               %d", nyuzi.performance_counters.event_counter[10]);
		end
	end

	always_ff @(posedge clk, posedge reset)
	begin
		if (reset)
		begin
			interrupt_counter <= 0;
			interrupt_req <= 0;
		end
		else if (interrupt_counter == 200)
		begin
			interrupt_counter <= 0;
			interrupt_req <= 1;
		end
		else 
		begin
			interrupt_counter <= interrupt_counter + 1;
			interrupt_req <= 0;
		end
	end

	always_ff @(posedge clk)
	begin : update
		total_cycles <= total_cycles + 1;
		if (processor_halt)
		begin
			// Run some number of cycles after halt is triggered to flush pending
			// instructions, L2 cache transactions, and the trace reorder queue.
			if (finish_cycles == 0)
				finish_cycles = 2000;
			else if (finish_cycles == 1)
			begin
				$display("***HALTED***");
				$finish;
			end
			else
				finish_cycles--;
		end


		//
		// Device registers
		//
		
		if (io_write_en)
		begin
			if (io_address == 32'h20)
				$write("%c", io_write_data[7:0]);	// Serial output
			else if (io_address == 32'h30)
				block_device_read_offset <= io_write_data / 4;	
		end

		if (io_read_en)
		begin
			case (io_address)
				// These dummy values match ones hard coded in the emulator.
				// Used for validating I/O transactions in cosimulation.
				'h4: io_read_data <= 32'h12345678;
				'h8: io_read_data <= 32'habcdef9b;

				'h16: io_read_data <= 1;	// Serial status 
				'h34:
				begin
					// Virtual block device
					io_read_data <= block_device_data[block_device_read_offset];
					block_device_read_offset <= block_device_read_offset + 1;
				end
				'h38: io_read_data <= 0;	// Keyboard
				default: io_read_data <= 32'hffffffff;
			endcase
		end

		if (do_state_trace && !reset)
		begin
			for (int i = 0; i < `THREADS_PER_CORE; i++)
			begin
				if (i != 0)
					$fwrite(state_trace_fd, ",");
			
				$fwrite(state_trace_fd, "%d", `CORE0.thread_select_stage.thread_state[i]);
			end

			$fwrite(state_trace_fd, "\n");
		end
		
		// Randomly sample a program counter for a thread and output to profile file
		if (do_profile && !reset && ($random() & 63) == 0)
			$fwrite(profile_fd, "%x\n", `CORE0.ifetch_tag_stage.next_program_counter[$random() % `THREADS_PER_CORE]);
		
		//
		// Output cosimulation event dump. Instructions don't retire in the order they are issued.
		// This makes it hard to correlate with the emulator. To remedy this, we reorder
		// completed instructions so the events are logged in issue order.
		//
		if (do_register_trace && !reset)
		begin
			case (trace_reorder_queue[0].event_type)
				TE_VWRITEBACK:
				begin
					$display("vwriteback %x %x %x %x %x",
						trace_reorder_queue[0].pc,
						trace_reorder_queue[0].thread_idx,
						trace_reorder_queue[0].writeback_reg,
						trace_reorder_queue[0].mask,
						trace_reorder_queue[0].data);
				end
				
				TE_SWRITEBACK:
				begin
					$display("swriteback %x %x %x %x",
						trace_reorder_queue[0].pc,
						trace_reorder_queue[0].thread_idx,
						trace_reorder_queue[0].writeback_reg,
						trace_reorder_queue[0].data[0]);
				end
				
				TE_STORE:
				begin
					$display("store %x %x %x %x %x",
						trace_reorder_queue[0].pc,
						trace_reorder_queue[0].thread_idx,
						trace_reorder_queue[0].addr,
						trace_reorder_queue[0].mask,
						trace_reorder_queue[0].data);
				end

				default:
					; // Do nothing
			endcase

			if (trace_reorder_queue[0].interrupt_active)
			begin
				$display("interrupt %d %x", trace_reorder_queue[0].interrupt_thread_idx,
					trace_reorder_queue[0].interrupt_pc);
			end

			for (int i = 0; i < TRACE_REORDER_QUEUE_LEN - 1; i++)
				trace_reorder_queue[i] = trace_reorder_queue[i + 1];
				
			trace_reorder_queue[TRACE_REORDER_QUEUE_LEN - 1] = 0;

			// Note that we only record the memory event for a synchronized store, not the register
			// success value.
			if (`CORE0.wb_writeback_en && !`CORE0.writeback_stage.__debug_is_sync_store)
			begin : dump_trace_event
				int tindex;
		
				if (`CORE0.writeback_stage.__debug_wb_pipeline == PIPE_SCYCLE_ARITH)
					tindex = 4;
				else if (`CORE0.writeback_stage.__debug_wb_pipeline == PIPE_MEM)
					tindex = 3;
				else // Multicycle arithmetic
					tindex = 0;

				assert(trace_reorder_queue[tindex].event_type == TE_INVALID);
				if (`CORE0.wb_writeback_is_vector)
					trace_reorder_queue[tindex].event_type = TE_VWRITEBACK;
				else
					trace_reorder_queue[tindex].event_type = TE_SWRITEBACK;

				trace_reorder_queue[tindex].pc = `CORE0.writeback_stage.__debug_wb_pc;
				trace_reorder_queue[tindex].thread_idx = `CORE0.wb_writeback_thread_idx;
				trace_reorder_queue[tindex].writeback_reg = `CORE0.wb_writeback_reg;
				trace_reorder_queue[tindex].mask = `CORE0.wb_writeback_mask;
				trace_reorder_queue[tindex].data = `CORE0.wb_writeback_value;
			end

			// Handle PC destination.
			if (`CORE0.ix_instruction_valid 
				&& `CORE0.ix_instruction.has_dest 
				&& `CORE0.ix_instruction.dest_reg == `REG_PC
				&& !`CORE0.ix_instruction.dest_is_vector)
			begin
				assert(trace_reorder_queue[5].event_type == TE_INVALID);
				trace_reorder_queue[5].event_type = TE_SWRITEBACK;
				trace_reorder_queue[5].pc = `CORE0.ix_instruction.pc;
				trace_reorder_queue[5].thread_idx = `CORE0.wb_rollback_thread_idx;
				trace_reorder_queue[5].writeback_reg = 31;
				trace_reorder_queue[5].data[0] = `CORE0.wb_rollback_pc;
			end
			else if (`CORE0.dd_instruction_valid 
				&& `CORE0.dd_instruction.has_dest 
				&& `CORE0.dd_instruction.dest_reg == `REG_PC
				&& !`CORE0.dd_instruction.dest_is_vector
				&& !`CORE0.dd_rollback_en)
			begin
				assert(trace_reorder_queue[4].event_type == TE_INVALID);
				trace_reorder_queue[4].event_type = TE_SWRITEBACK;
				trace_reorder_queue[4].pc = `CORE0.dd_instruction.pc;
				trace_reorder_queue[4].thread_idx = `CORE0.wb_rollback_thread_idx;
				trace_reorder_queue[4].writeback_reg = 31;
				trace_reorder_queue[4].data[0] = `CORE0.wb_rollback_pc;
			end

			if (`CORE0.dd_store_en)
			begin
				assert(trace_reorder_queue[5].event_type == TE_INVALID);
				trace_reorder_queue[5].event_type = TE_STORE;
				trace_reorder_queue[5].pc = `CORE0.dt_instruction.pc;
				trace_reorder_queue[5].thread_idx = `CORE0.dt_thread_idx;
				trace_reorder_queue[5].addr = {
					`CORE0.dt_request_addr[31:`CACHE_LINE_OFFSET_WIDTH],
					{`CACHE_LINE_OFFSET_WIDTH{1'b0}}
				};
				trace_reorder_queue[5].mask = `CORE0.dd_store_mask;
				trace_reorder_queue[5].data = `CORE0.dd_store_data;
			end

			// Invalidate the store instruction if it was rolled back.
			if (`CORE0.sq_rollback_en && `CORE0.dd_instruction_valid)
				trace_reorder_queue[4].event_type = TE_INVALID;
				
			// Invalidate the store instruction if a synchronized store failed
			if (`CORE0.dd_instruction_valid 
				&& `CORE0.dd_instruction.memory_access_type == MEM_SYNC
				&& !`CORE0.dd_instruction.is_load
				&& !`CORE0.sq_store_sync_success)
				trace_reorder_queue[4].event_type = TE_INVALID;

			// Signal interrupt to emulator.  Put this at the end of the queue so all
			// instructions that have already been retired will appear before the interrupt
			// in the trace.
			// Note that there would be a problem in instructions fetched after the interrupt
			// handler jumped in front of the interrupt in the queue.  However, that can't
			// happen because the thread is restarted and by the time they reach the
			// writeback stage, this interrupt will already have been processed.
			if (`CORE0.wb_interrupt_ack)
			begin
				trace_reorder_queue[5].interrupt_active = 1;
				trace_reorder_queue[5].interrupt_thread_idx = `CORE0.wb_rollback_thread_idx;
				trace_reorder_queue[5].interrupt_pc = `CORE0.wb_fault_pc;
			end
		end
	end
endmodule

// Local Variables:
// verilog-library-flags:("-y ../core" "-y ../fpga")
// verilog-auto-inst-param-value: t
// verilog-typedef-regexp:"_t$"
// End:
