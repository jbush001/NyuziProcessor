// 
// Copyright 2011-2015 Jeff Bush
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


`include "../core/defines.sv"

//`define SIMULATE_BOOT_ROM

//
// Testbench for CPU
//

module verilator_tb(
	input       clk, 
	input       reset);

	localparam MEM_SIZE = 'h1000000;
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
	int do_profile;
	int profile_fd;
	logic processor_halt;
	l2rsp_packet_t l2_response;
	scalar_t io_read_data;
	logic interrupt_req;
	int interrupt_counter;
	logic pc_event_dram_page_miss;	
	logic pc_event_dram_page_hit;
	trace_event_t trace_reorder_queue[TRACE_REORDER_QUEUE_LEN];
	logic[31:0] spi_read_data;
	logic[31:0] ps2_read_data;
	axi4_interface axi_bus_m0();
	axi4_interface axi_bus_m1();
	axi4_interface axi_bus_s0();
	axi4_interface axi_bus_s1();
	logic [SDRAM_DATA_WIDTH-1:0] dram_dq;	
	logic [12:0]	dram_addr;
	logic [1:0]	dram_ba;	
	logic dram_cas_n;	
	logic dram_cke;	
	logic dram_clk;	
	logic dram_cs_n;	
	logic dram_ras_n;	
	logic dram_we_n;	
	logic sd_cs_n;
	logic sd_di;
	logic sd_do;
	logic sd_sclk;
	logic ps2_clk;
	logic ps2_data;

	/*AUTOWIRE*/
	// Beginning of automatic wires (for undeclared instantiated-module outputs)
	scalar_t	io_address;		// From nyuzi of nyuzi.v
	wire		io_read_en;		// From nyuzi of nyuzi.v
	scalar_t	io_write_data;		// From nyuzi of nyuzi.v
	wire		io_write_en;		// From nyuzi of nyuzi.v
	// End of automatics

	`define CORE0 nyuzi.core_gen[0].core

`ifdef SIMULATE_BOOT_ROM 
	localparam RESET_PC = 32'hfffee000;

	axi_rom #(.FILENAME("../software/bootrom/boot.hex")) boot_rom(
		.axi_bus(axi_bus_m1.slave),
		.clk(clk),
		.reset(reset));
`else
	localparam RESET_PC = 32'h00000000;

	assign axi_bus_m1.s_wready = 0;
	assign axi_bus_m1.s_arready = 0;
	assign axi_bus_m1.s_rvalid = 0;
`endif

	nyuzi #(.RESET_PC(RESET_PC)) nyuzi(
		.axi_bus(axi_bus_s0.master),
		.*);

	axi_interconnect axi_interconnect(
		.axi_bus_m0(axi_bus_m0.master),
		.axi_bus_m1(axi_bus_m1.master),
		.axi_bus_s0(axi_bus_s0.slave),
		.axi_bus_s1(axi_bus_s1.slave),
		.clk(clk),
		.reset(reset));

	localparam SDRAM_NUM_BANKS = 4;
	localparam SDRAM_DATA_WIDTH = 32;
	localparam SDRAM_ROW_ADDR_WIDTH = 12;
	localparam SDRAM_COL_ADDR_WIDTH = $clog2(MEM_SIZE / ((1 << SDRAM_ROW_ADDR_WIDTH) 
		* SDRAM_NUM_BANKS * (SDRAM_DATA_WIDTH / 8)));

	`define MEMORY memory.memory

	sdram_controller #(
		.DATA_WIDTH(SDRAM_DATA_WIDTH),
		.ROW_ADDR_WIDTH(SDRAM_ROW_ADDR_WIDTH),
		.COL_ADDR_WIDTH(SDRAM_COL_ADDR_WIDTH),
		.T_REFRESH(750),
		.T_POWERUP(5)) sdram_controller(
			.axi_bus(axi_bus_m0.slave),
			.*);
		
	sim_sdram #(
		.DATA_WIDTH(SDRAM_DATA_WIDTH),
		.ROW_ADDR_WIDTH(SDRAM_ROW_ADDR_WIDTH),
		.COL_ADDR_WIDTH(SDRAM_COL_ADDR_WIDTH),
		.MAX_REFRESH_INTERVAL(800)) memory(.*);
		
	// The s1 interface is not connected to anything in this configuration.
	assign axi_bus_s1.m_awvalid = 0;
	assign axi_bus_s1.m_wvalid = 0;
	assign axi_bus_s1.m_arvalid = 0;
	assign axi_bus_s1.m_rready = 0;
	assign axi_bus_s1.m_bready = 0;

	sim_sdmmc sim_sdmmc(.*);

	spi_controller #(.BASE_ADDRESS('h44)) spi_controller(
		.io_read_data(spi_read_data),
		.spi_clk(sd_sclk),
		.spi_cs_n(sd_cs_n),
		.spi_miso(sd_do),
		.spi_mosi(sd_di),
		.*);

	sim_ps2 sim_ps2(.*);

	ps2_controller #(.BASE_ADDRESS('h38)) ps2_controller(
		.io_read_data(ps2_read_data),
		.*);

	task flush_l2_line;
		input l2_tag_t tag;
		input l2_set_idx_t set;
		input l2_way_idx_t way;
	begin
		for (int line_offset = 0; line_offset < `CACHE_LINE_WORDS; line_offset++)
		begin
			`MEMORY[(int'(tag) * `L2_SETS + int'(set)) * `CACHE_LINE_WORDS + line_offset] = 
				int'(nyuzi.l2_cache.l2_cache_read.sram_l2_data.data[{ way, set }]
				 >> ((`CACHE_LINE_WORDS - 1 - line_offset) * 32));
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
			// index into generated array instances with a dynamic variable.
			if (`L2_TAG_WAY[0].line_valid[set])
				flush_l2_line(`L2_TAG_WAY[0].sram_tags.data[set], l2_set_idx_t'(set), l2_way_idx_t'(0));

			if (`L2_TAG_WAY[1].line_valid[set])
				flush_l2_line(`L2_TAG_WAY[1].sram_tags.data[set], l2_set_idx_t'(set), l2_way_idx_t'(1));

			if (`L2_TAG_WAY[2].line_valid[set])
				flush_l2_line(`L2_TAG_WAY[2].sram_tags.data[set], l2_set_idx_t'(set), l2_way_idx_t'(2));

			if (`L2_TAG_WAY[3].line_valid[set])
				flush_l2_line(`L2_TAG_WAY[3].sram_tags.data[set], l2_set_idx_t'(set), l2_way_idx_t'(3));
		
			if (`L2_TAG_WAY[4].line_valid[set])
				flush_l2_line(`L2_TAG_WAY[4].sram_tags.data[set], l2_set_idx_t'(set), l2_way_idx_t'(4));

			if (`L2_TAG_WAY[5].line_valid[set])
				flush_l2_line(`L2_TAG_WAY[5].sram_tags.data[set], l2_set_idx_t'(set), l2_way_idx_t'(5));

			if (`L2_TAG_WAY[6].line_valid[set])
				flush_l2_line(`L2_TAG_WAY[6].sram_tags.data[set], l2_set_idx_t'(set), l2_way_idx_t'(6));

			if (`L2_TAG_WAY[7].line_valid[set])
				flush_l2_line(`L2_TAG_WAY[7].sram_tags.data[set], l2_set_idx_t'(set), l2_way_idx_t'(7));
		end
	end
	endtask

	initial
	begin
		$display("num cores %0d threads per core %0d l1i$ %0dk %0d ways l1d$ %0dk %0d ways l2$ %0dk %0d ways",
			`NUM_CORES, `THREADS_PER_CORE, 
			`L1I_WAYS * `L1I_SETS * `CACHE_LINE_BYTES / 1024, `L1I_WAYS,
			`L1D_WAYS * `L1D_SETS * `CACHE_LINE_BYTES / 1024, `L1D_WAYS,
			`L2_WAYS * `L2_SETS * `CACHE_LINE_BYTES / 1024, `L2_WAYS);
	
		for (int i = 0; i < TRACE_REORDER_QUEUE_LEN; i++)
			trace_reorder_queue[i] = 0;

		do_register_trace = $test$plusargs("regtrace");
		if ($test$plusargs("statetrace") != 0)
		begin
			do_state_trace = 1;
			state_trace_fd = $fopen("statetrace.txt", "w");
		end
		else
			do_state_trace = 0;
			
		if ($value$plusargs("profile=%s", filename) != 0)
		begin
			do_profile = 1;
			profile_fd = $fopen(filename, "w");
		end
		else
			do_profile = 0;

		for (int i = 0; i < MEM_SIZE; i++)
			`MEMORY[i] = 0;

		if ($value$plusargs("bin=%s", filename) != 0)
			$readmemh(filename, `MEMORY);
		else
		begin
			$display("error opening file");
			$finish;
		end
	end

	final
	begin
		int mem_dump_start;
		int mem_dump_length;
		int dump_fp;

		$display("ran for %0d cycles", total_cycles);
		if ($value$plusargs("memdumpbase=%x", mem_dump_start) != 0
			&& $value$plusargs("memdumplen=%x", mem_dump_length) != 0
			&& $value$plusargs("memdumpfile=%s", filename) != 0)
		begin
			if ($test$plusargs("autoflushl2") != 0)
				flush_l2_cache;

			dump_fp = $fopen(filename, "wb");
			for (int i = 0; i < mem_dump_length; i += 4)
			begin
				$c("fputc(", `MEMORY[(mem_dump_start + i) / 4][31:24], ", VL_CVT_I_FP(", dump_fp, "));");
				$c("fputc(", `MEMORY[(mem_dump_start + i) / 4][23:16], ", VL_CVT_I_FP(", dump_fp, "));");
				$c("fputc(", `MEMORY[(mem_dump_start + i) / 4][15:8], ", VL_CVT_I_FP(", dump_fp, "));");
				$c("fputc(", `MEMORY[(mem_dump_start + i) / 4][7:0], ", VL_CVT_I_FP(", dump_fp, "));");
			end

			$fclose(dump_fp);
		end	
		
		if (do_state_trace != 0)
			$fclose(state_trace_fd);
			
		if (do_profile != 0)
			$fclose(profile_fd);

		$display("performance counters:");
		$display("      l2_writeback          %0d", nyuzi.performance_counters.event_counter[0]);
		$display("      l2_miss               %0d", nyuzi.performance_counters.event_counter[1]);
		$display("      l2_hit                %0d", nyuzi.performance_counters.event_counter[2]);
		
		for (int i = 0; i < `NUM_CORES; i++)
		begin
			$display("\n      core %0d", i);
			$display("      store rollback count  %0d", nyuzi.performance_counters.event_counter[3 +                  i]);
			$display("      store count           %0d", nyuzi.performance_counters.event_counter[3 +     `NUM_CORES + i]);
			$display("      instruction_retire    %0d", nyuzi.performance_counters.event_counter[3 + 2 * `NUM_CORES + i]);
			$display("      instruction_issue     %0d", nyuzi.performance_counters.event_counter[3 + 3 * `NUM_CORES + i]);
			$display("      l1i_miss              %0d", nyuzi.performance_counters.event_counter[3 + 4 * `NUM_CORES + i]);
			$display("      l1i_hit               %0d", nyuzi.performance_counters.event_counter[3 + 5 * `NUM_CORES + i]);
			$display("      l1d_miss              %0d", nyuzi.performance_counters.event_counter[3 + 6 * `NUM_CORES + i]);
			$display("      l1d_hit               %0d", nyuzi.performance_counters.event_counter[3 + 7 * `NUM_CORES + i]);
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

	always_ff @(posedge clk, posedge reset)
	begin : update
		if (reset)
		begin
			for (int i = 0; i < TRACE_REORDER_QUEUE_LEN; i++)
				trace_reorder_queue[i] <= 0;
		end
		else
		begin
			if (processor_halt)
			begin
				// Run some number of cycles after halt is triggered to flush pending
				// instructions, L2 cache transactions, and the trace reorder queue.
				if (finish_cycles == 0)
					finish_cycles <= 2000;
				else if (finish_cycles == 1)
				begin
					$display("***HALTED***");
					$finish;
				end
				else
					finish_cycles <= finish_cycles - 1;
			end
			else
				total_cycles <= total_cycles + 1;	// Don't count cycles after halt

			//
			// Device registers
			//
		
			if (io_write_en)
			begin
				if (io_address == 32'h20)
					$write("%c", io_write_data[7:0]);	// Serial output
			end

			if (io_read_en)
			begin
				case (io_address)
					'h4,
					'h8: io_read_data <= 32'hffffffff;	// Hack for cosimulation tests
					'h18: io_read_data <= 1;	// Serial status 
					'h38,
					'h3c: io_read_data <= ps2_read_data;
				

					'h48,
					'h4c:
					begin
						io_read_data <= spi_read_data;
					end
				
					default: io_read_data <= $random();
				endcase
			end

			if (do_state_trace != 0)
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
			if (do_profile != 0 && ($random() & 63) == 0)
				$fwrite(profile_fd, "%x\n", `CORE0.ifetch_tag_stage.next_program_counter[$random() % `THREADS_PER_CORE]);
		
			//
			// Output cosimulation event dump. Instructions don't retire in the order they are issued.
			// This makes it hard to correlate with the emulator. To remedy this, we reorder
			// completed instructions so the events are logged in issue order.
			//
			if (do_register_trace != 0)
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
					trace_reorder_queue[i] <= trace_reorder_queue[i + 1];
				
				trace_reorder_queue[TRACE_REORDER_QUEUE_LEN - 1] <= 0;

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

					assert(trace_reorder_queue[tindex + 1].event_type == TE_INVALID);
					if (`CORE0.wb_writeback_is_vector)
						trace_reorder_queue[tindex].event_type <= TE_VWRITEBACK;
					else
						trace_reorder_queue[tindex].event_type <= TE_SWRITEBACK;

					trace_reorder_queue[tindex].pc <= `CORE0.writeback_stage.__debug_wb_pc;
					trace_reorder_queue[tindex].thread_idx <= `CORE0.wb_writeback_thread_idx;
					trace_reorder_queue[tindex].writeback_reg <= `CORE0.wb_writeback_reg;
					trace_reorder_queue[tindex].mask <= { {`CACHE_LINE_BYTES - `VECTOR_LANES{1'b0}}, 
						`CORE0.wb_writeback_mask };
					trace_reorder_queue[tindex].data <= `CORE0.wb_writeback_value;
				end

				// Handle PC destination.
				if (`CORE0.ix_instruction_valid 
					&& `CORE0.ix_instruction.has_dest 
					&& `CORE0.ix_instruction.dest_reg == `REG_PC
					&& !`CORE0.ix_instruction.dest_is_vector)
				begin
					assert(trace_reorder_queue[6].event_type == TE_INVALID);
					trace_reorder_queue[5].event_type <= TE_SWRITEBACK;
					trace_reorder_queue[5].pc <= `CORE0.ix_instruction.pc;
					trace_reorder_queue[5].thread_idx <= `CORE0.wb_rollback_thread_idx;
					trace_reorder_queue[5].writeback_reg <= 31;
					trace_reorder_queue[5].data[0] <= `CORE0.wb_rollback_pc;
				end
				else if (`CORE0.dd_instruction_valid 
					&& `CORE0.dd_instruction.has_dest 
					&& `CORE0.dd_instruction.dest_reg == `REG_PC
					&& !`CORE0.dd_instruction.dest_is_vector
					&& !`CORE0.dd_rollback_en)
				begin
					assert(trace_reorder_queue[5].event_type == TE_INVALID);
					trace_reorder_queue[4].event_type <= TE_SWRITEBACK;
					trace_reorder_queue[4].pc <= `CORE0.dd_instruction.pc;
					trace_reorder_queue[4].thread_idx <= `CORE0.wb_rollback_thread_idx;
					trace_reorder_queue[4].writeback_reg <= 31;
					trace_reorder_queue[4].data[0] <= `CORE0.wb_rollback_pc;
				end

				if (`CORE0.dd_store_en)
				begin
					assert(trace_reorder_queue[6].event_type == TE_INVALID);
					trace_reorder_queue[5].event_type <= TE_STORE;
					trace_reorder_queue[5].pc <= `CORE0.dt_instruction.pc;
					trace_reorder_queue[5].thread_idx <= `CORE0.dt_thread_idx;
					trace_reorder_queue[5].addr <= {
						`CORE0.dt_request_addr[31:`CACHE_LINE_OFFSET_WIDTH],
						{`CACHE_LINE_OFFSET_WIDTH{1'b0}}
					};
					trace_reorder_queue[5].mask <= `CORE0.dd_store_mask;
					trace_reorder_queue[5].data <= `CORE0.dd_store_data;
				end

				// Invalidate the store instruction if it was rolled back.
				if (`CORE0.sq_rollback_en && `CORE0.dd_instruction_valid)
					trace_reorder_queue[4].event_type <= TE_INVALID;
				
				// Invalidate the store instruction if a synchronized store failed
				if (`CORE0.dd_instruction_valid 
					&& `CORE0.dd_instruction.memory_access_type == MEM_SYNC
					&& !`CORE0.dd_instruction.is_load
					&& !`CORE0.sq_store_sync_success)
					trace_reorder_queue[4].event_type <= TE_INVALID;

				// Signal interrupt to emulator.  Put this at the end of the queue so all
				// instructions that have already been retired will appear before the interrupt
				// in the trace.
				// Note that there would be a problem in instructions fetched after the interrupt
				// handler jumped in front of the interrupt in the queue.  However, that can't
				// happen because the thread is restarted and by the time they reach the
				// writeback stage, this interrupt will already have been processed.
				if (`CORE0.wb_interrupt_ack)
				begin
					trace_reorder_queue[5].interrupt_active <= 1;
					trace_reorder_queue[5].interrupt_thread_idx <= `CORE0.wb_rollback_thread_idx;
					trace_reorder_queue[5].interrupt_pc <= `CORE0.wb_fault_pc;
				end
			end
		end
	end
endmodule

// Local Variables:
// verilog-library-flags:("-y ../core" "-y ../fpga/common")
// verilog-auto-inst-param-value: t
// verilog-typedef-regexp:"_t$"
// End:
