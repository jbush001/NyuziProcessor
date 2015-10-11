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

	int total_cycles = 0;
	logic[1000:0] filename;
	bit state_dump_en;
	int state_dump_fd;
	int finish_cycles;
	bit profile_en;
	int profile_fd;
	logic processor_halt;
	l2rsp_packet_t l2_response;
	scalar_t io_read_data;
	logic interrupt_req;
	int interrupt_counter;
	logic pc_event_dram_page_miss;	
	logic pc_event_dram_page_hit;
	logic[31:0] spi_read_data;
	logic[31:0] ps2_read_data;
	axi4_interface axi_bus_m0();
	axi4_interface axi_bus_m1();
	axi4_interface axi_bus_s0();
	axi4_interface axi_bus_s1();
	logic [SDRAM_DATA_WIDTH-1:0] dram_dq;	
	logic [12:0] dram_addr;
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
	logic[31:0] loopback_uart_read_data;
	logic loopback_uart_tx;
	logic loopback_uart_rx;
	logic loopback_uart_mask;

	/*AUTOLOGIC*/
	// Beginning of automatic wires (for undeclared instantiated-module outputs)
	scalar_t	io_address;		// From nyuzi of nyuzi.v
	logic		io_read_en;		// From nyuzi of nyuzi.v
	scalar_t	io_write_data;		// From nyuzi of nyuzi.v
	logic		io_write_en;		// From nyuzi of nyuzi.v
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

	assign loopback_uart_rx = loopback_uart_tx & loopback_uart_mask;
	uart #(.BASE_ADDRESS('h100), .BAUD_DIVIDE(8)) loopback_uart(
		.io_read_data(loopback_uart_read_data),
		.uart_tx(loopback_uart_tx),
		.uart_rx(loopback_uart_rx),
		.*);

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

	trace_logger trace_logger(
		.wb_writeback_en(`CORE0.wb_writeback_en),
		.wb_writeback_is_vector(`CORE0.wb_writeback_is_vector),
		.wb_writeback_reg(`CORE0.wb_writeback_reg),
		.wb_writeback_value(`CORE0.wb_writeback_value),
		.wb_writeback_mask(`CORE0.wb_writeback_mask),
		.wb_writeback_thread_idx(`CORE0.wb_writeback_thread_idx),
		.wb_rollback_thread_idx(`CORE0.wb_rollback_thread_idx),
		.wb_interrupt_ack(`CORE0.wb_interrupt_ack),
		.wb_rollback_pc(`CORE0.wb_rollback_pc),
		.debug_is_sync_store(`CORE0.writeback_stage.__debug_is_sync_store),
		.debug_wb_pipeline(`CORE0.writeback_stage.__debug_wb_pipeline),
		.debug_wb_pc(`CORE0.writeback_stage.__debug_wb_pc),
		.ix_instruction_valid(`CORE0.ix_instruction_valid),
		.ix_instruction_pc(`CORE0.ix_instruction.pc),
		.ix_instruction_has_dest(`CORE0.ix_instruction.has_dest ),
		.ix_instruction_dest_reg(`CORE0.ix_instruction.dest_reg),
		.ix_instruction_dest_is_vector(`CORE0.ix_instruction.dest_is_vector),
		.dd_instruction_valid(`CORE0.dd_instruction_valid),
		.dd_instruction_has_dest(`CORE0.dd_instruction.has_dest),
		.dd_instruction_dest_reg(`CORE0.dd_instruction.dest_reg),
		.dd_instruction_dest_is_vector(`CORE0.dd_instruction.dest_is_vector),
		.dd_rollback_en(`CORE0.dd_rollback_en),
		.dd_instruction_pc(`CORE0.dd_instruction.pc),
		.dd_store_en(`CORE0.dd_store_en),
		.dd_store_mask(`CORE0.dd_store_mask),
		.dd_store_data(`CORE0.dd_store_data),
		.dd_instruction_memory_access_type(`CORE0.dd_instruction.memory_access_type),
		.dd_instruction_is_load(`CORE0.dd_instruction.is_load),
		.dt_instruction_pc(`CORE0.dt_instruction.pc),
		.dt_thread_idx(`CORE0.dt_thread_idx),
		.dt_request_addr(`CORE0.dt_request_addr),
		.sq_rollback_en(`CORE0.sq_rollback_en),
		.sq_store_sync_success(`CORE0.sq_store_sync_success),
		.wb_fault_pc(`CORE0.wb_fault_pc),
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
			// the number of L2 ways, since (per IEEE 1800-2012) an 
			// instance select must be a constant expression.
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

		if ($test$plusargs("statetrace") != 0)
		begin
			state_dump_en = 1;
			state_dump_fd = $fopen("statetrace.txt", "w");
		end
		else
			state_dump_en = 0;
			
		if ($value$plusargs("profile=%s", filename) != 0)
		begin
			profile_en = 1;
			profile_fd = $fopen(filename, "w");
		end
		else
			profile_en = 0;

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
		
		if (state_dump_en)
			$fclose(state_dump_fd);
			
		if (profile_en)
			$fclose(profile_fd);

		$display("performance counters:");
		$display("      l2_writeback          %0d", nyuzi.performance_counters.event_counter[0]);
		$display("      l2_miss               %0d", nyuzi.performance_counters.event_counter[1]);
		$display("      l2_hit                %0d", nyuzi.performance_counters.event_counter[2]);
		
		for (int i = 0; i < `NUM_CORES; i++)
		begin
			$display("\n      core %0d", i);
			$display("      store rollback count  %0d", nyuzi.performance_counters.event_counter[3 + `NUM_CORES * i]);
			$display("      store count           %0d", nyuzi.performance_counters.event_counter[4 + `NUM_CORES * i]);
			$display("      instruction_retire    %0d", nyuzi.performance_counters.event_counter[5 + `NUM_CORES * i]);
			$display("      instruction_issue     %0d", nyuzi.performance_counters.event_counter[6 + `NUM_CORES * i]);
			$display("      l1i_miss              %0d", nyuzi.performance_counters.event_counter[7 + `NUM_CORES * i]);
			$display("      l1i_hit               %0d", nyuzi.performance_counters.event_counter[8 + `NUM_CORES * i]);
			$display("      l1d_miss              %0d", nyuzi.performance_counters.event_counter[9 + `NUM_CORES * i]);
			$display("      l1d_hit               %0d", nyuzi.performance_counters.event_counter[10 + `NUM_CORES * i]);
		end
		
		// Do this last so emulator doesn't kill us with SIGPIPE during cosimulation.
		if (processor_halt)
			$display("***HALTED***");
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
			loopback_uart_mask <= 1;
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
					$finish;
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
				case (io_address)
					// Serial output
					'h20: $write("%c", io_write_data[7:0]);	

					// Loopback UART
					'h10c: loopback_uart_mask <= io_write_data[0];
				endcase
			end

			if (io_read_en)
			begin
				case (io_address)
					// Hack for cosimulation tests
					'h4,
					'h8: io_read_data <= 32'hffffffff;	

					// Serial status 
					'h18: io_read_data <= 1;	

					// PS2
					'h38,
					'h3c: io_read_data <= ps2_read_data;

					// SPI
					'h48,
					'h4c: io_read_data <= spi_read_data;

					// External UART 0
					'h100,
					'h104: io_read_data <= loopback_uart_read_data;	

					default: io_read_data <= $random();
				endcase
			end

			if (state_dump_en)
			begin
				for (int i = 0; i < `THREADS_PER_CORE; i++)
				begin
					if (i != 0)
						$fwrite(state_dump_fd, ",");
			
					$fwrite(state_dump_fd, "%d", `CORE0.thread_select_stage.thread_state[i]);
				end

				$fwrite(state_dump_fd, "\n");
			end
		
			// Randomly sample a program counter for a thread and output to profile file
			if (profile_en && ($random() & 63) == 0)
				$fwrite(profile_fd, "%x\n", `CORE0.ifetch_tag_stage.next_program_counter[$random() % `THREADS_PER_CORE]);
		end
	end
endmodule

// Local Variables:
// verilog-library-flags:("-y ../core" "-y ../fpga/common")
// verilog-auto-inst-param-value: t
// verilog-typedef-regexp:"_t$"
// End:
