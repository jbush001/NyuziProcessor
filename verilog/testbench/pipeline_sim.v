module pipeline_sim;
	
	parameter NUM_STRANDS = 4;
	parameter NUM_REGS = 32;

	reg 			clk;
	integer 		i;
	reg[1000:0] 	filename;
	reg[31:0] 		regtemp[0:17 * NUM_REGS * NUM_STRANDS - 1];
	integer 		do_register_dump;
	integer			do_register_trace;
	integer 		mem_dump_start;
	integer 		mem_dump_length;
	reg[31:0] 		mem_dat;
	integer 		simulation_cycles;
	wire			processor_halt;
	wire			pci_valid;
	wire			pci_ack;
	wire[1:0]		pci_unit;
	wire[1:0]		pci_strand;
	wire[2:0]		pci_op;
	wire[1:0]		pci_way;
	wire[25:0]		pci_address;
	wire[511:0]		pci_data;
	wire[63:0]		pci_mask;
	wire 			cpi_valid;
	wire			cpi_status;
	wire[1:0]		cpi_unit;
	wire[1:0]		cpi_strand;
	wire[1:0]		cpi_op;
	wire 			cpi_update;
	wire[1:0]		cpi_way;
	wire[511:0]		cpi_data;
	integer			fp;
	integer			pixelval;
	wire [31:0]		sm_addr;
	wire			sm_request;
	wire			sm_ack;
	wire			sm_write;
	wire [31:0]		data_from_sm;
	wire [31:0]		data_to_sm;
	reg[31:0] 		wb_pc = 0;
	integer			dummy_return;
	integer			do_autoflush_l2;
	
	core core(
		.clk(clk),
		.pci_valid(pci_valid),
		.pci_ack(pci_ack),
		.pci_strand(pci_strand),
		.pci_unit(pci_unit),
		.pci_op(pci_op),
		.pci_way(pci_way),
		.pci_address(pci_address),
		.pci_data(pci_data),
		.pci_mask(pci_mask),
		.cpi_valid(cpi_valid),
		.cpi_status(cpi_status),
		.cpi_unit(cpi_unit),
		.cpi_strand(cpi_strand),
		.cpi_op(cpi_op),
		.cpi_update(cpi_update),
		.cpi_way(cpi_way),
		.cpi_data(cpi_data),
		.halt_o(processor_halt));

	l2_cache l2_cache(
		.clk(clk),
		.pci_valid(pci_valid),
		.pci_ack(pci_ack),
		.pci_strand(pci_strand),
		.pci_unit(pci_unit),
		.pci_op(pci_op),
		.pci_way(pci_way),
		.pci_address(pci_address),
		.pci_data(pci_data),
		.pci_mask(pci_mask),
		.cpi_valid(cpi_valid),
		.cpi_status(cpi_status),
		.cpi_unit(cpi_unit),
		.cpi_strand(cpi_strand),
		.cpi_op(cpi_op),
		.cpi_update(cpi_update),
		.cpi_way(cpi_way),
		.cpi_data(cpi_data),
		.addr_o(sm_addr),
		.request_o(sm_request),
		.ack_i(sm_ack),
		.write_o(sm_write),
		.data_i(data_from_sm),
		.data_o(data_to_sm));

	sim_memory memory(
		.clk(clk),
		.sm_addr(sm_addr),
		.sm_request(sm_request),
		.sm_ack(sm_ack),
		.sm_write(sm_write),
		.data_from_sm(data_from_sm),
		.data_to_sm(data_to_sm));

	initial
	begin
		// Load executable binary into memory
		if ($value$plusargs("bin=%s", filename))
			$readmemh(filename, memory.memory);
		else
		begin
			$display("error opening file");
			$finish;
		end

		do_register_dump = 0; // Dump all registers at end

		`define PIPELINE core.pipeline
		`define SS_STAGE `PIPELINE.strand_select_stage
		`define VREG_FILE `PIPELINE.vector_register_file
		`define SFSM0 `SS_STAGE.strand_fsm0
		`define SFSM1 `SS_STAGE.strand_fsm1
		`define SFSM2 `SS_STAGE.strand_fsm2
		`define SFSM3 `SS_STAGE.strand_fsm3

		// If initial values are passed for scalar registers, load those now
		if ($value$plusargs("initial_regs=%s", filename))
		begin
			$readmemh(filename, regtemp);
			for (i = 0; i < NUM_REGS * NUM_STRANDS; i = i + 1)		// ignore PC
				`PIPELINE.scalar_register_file.registers[i] = regtemp[i];

			for (i = 0; i < NUM_REGS * NUM_STRANDS; i = i + 1)
			begin
				`VREG_FILE.lane15[i] = regtemp[(i + 8) * 16];
				`VREG_FILE.lane14[i] = regtemp[(i + 8) * 16 + 1];
				`VREG_FILE.lane13[i] = regtemp[(i + 8) * 16 + 2];
				`VREG_FILE.lane12[i] = regtemp[(i + 8) * 16 + 3];
				`VREG_FILE.lane11[i] = regtemp[(i + 8) * 16 + 4];
				`VREG_FILE.lane10[i] = regtemp[(i + 8) * 16 + 5];
				`VREG_FILE.lane9[i] = regtemp[(i + 8) * 16 + 6];
				`VREG_FILE.lane8[i] = regtemp[(i + 8) * 16 + 7];
				`VREG_FILE.lane7[i] = regtemp[(i + 8) * 16 + 8];
				`VREG_FILE.lane6[i] = regtemp[(i + 8) * 16 + 9];
				`VREG_FILE.lane5[i] = regtemp[(i + 8) * 16 + 10];
				`VREG_FILE.lane4[i] = regtemp[(i + 8) * 16 + 11];
				`VREG_FILE.lane3[i] = regtemp[(i + 8) * 16 + 12];
				`VREG_FILE.lane2[i] = regtemp[(i + 8) * 16 + 13];
				`VREG_FILE.lane1[i] = regtemp[(i + 8) * 16 + 14];
				`VREG_FILE.lane0[i] = regtemp[(i + 8) * 16 + 15];
			end
			
			do_register_dump = 1;
		end

		if (!$value$plusargs("regtrace=%d", do_register_trace))
			do_register_trace = 0;

		// Open a trace file
		if ($value$plusargs("trace=%s", filename))
		begin
			$dumpfile(filename);
			$dumpvars;
		end
	
		// Run simulation for some number of cycles
		if (!$value$plusargs("simcycles=%d", simulation_cycles))
			simulation_cycles = 500;

		if (do_register_trace)
		begin
			clk = 0;
			for (i = 0; i < simulation_cycles && !processor_halt; i = i + 1)
			begin
				#5 clk = 1;
				#5 clk = 0;
				
				wb_pc <= core.pipeline.ma_pc;

				// Display register dump
				if (core.pipeline.wb_has_writeback)
				begin
					if (core.pipeline.wb_writeback_is_vector)
					begin
						$display("%08x [st %d] v%d{%04x} <= %128x", 
							wb_pc - 4, 
							core.pipeline.wb_writeback_reg[6:5], 
							core.pipeline.wb_writeback_reg[4:0], 
							core.pipeline.wb_writeback_mask,
							core.pipeline.wb_writeback_value);
					end
					else
					begin
						$display("%08x [st %d] s%d <= %8x", 
							wb_pc - 4, 
							core.pipeline.wb_writeback_reg[6:5], 
							core.pipeline.wb_writeback_reg[4:0], 
							core.pipeline.wb_writeback_value[31:0]);
					end
				end
			end
		end
		else
		begin
			clk = 0;
			for (i = 0; i < simulation_cycles && !processor_halt; i = i + 1)
			begin
				#5 clk = 1;
				#5 clk = 0;
			end
		end

		if (processor_halt)
			$display("***HALTED***");

		$display("ran for %d cycles", i);
		$display(" no issue cycles %d", `SS_STAGE.idle_cycle_count);
		$display(" RAW conflict %d", 
			`SFSM0.raw_wait_count
			+ `SFSM1.raw_wait_count
			+ `SFSM2.raw_wait_count
			+ `SFSM3.raw_wait_count);
		$display(" wait for dcache/store %d", 
			`SFSM0.dcache_wait_count
			+ `SFSM1.dcache_wait_count
			+ `SFSM2.dcache_wait_count
			+ `SFSM3.dcache_wait_count);
		$display(" wait for icache %d", 
			`SFSM0.icache_wait_count
			+ `SFSM1.icache_wait_count
			+ `SFSM2.icache_wait_count
			+ `SFSM3.icache_wait_count);
		$display("L1 icache hits %d misses %d", 
			core.icache.hit_count, core.icache.miss_count);
		$display("L1 dcache hits %d misses %d", 
			core.dcache.hit_count, core.dcache.miss_count);
		$display("L1 store count %d",
			core.store_buffer.store_count);
		$display("L2 cache hits %d misses %d",
			l2_cache.hit_count, l2_cache.miss_count);

		if (do_register_dump)
		begin
			$display("REGISTERS:");
			// Dump the registers
			for (i = 0; i < NUM_REGS * NUM_STRANDS; i = i + 1)
				$display("%08x", `PIPELINE.scalar_register_file.registers[i]);
	
			for (i = 0; i < NUM_REGS * NUM_STRANDS; i = i + 1)
			begin
				$display("%08x", `PIPELINE.vector_register_file.lane15[i]);
				$display("%08x", `PIPELINE.vector_register_file.lane14[i]);
				$display("%08x", `PIPELINE.vector_register_file.lane13[i]);
				$display("%08x", `PIPELINE.vector_register_file.lane12[i]);
				$display("%08x", `PIPELINE.vector_register_file.lane11[i]);
				$display("%08x", `PIPELINE.vector_register_file.lane10[i]);
				$display("%08x", `PIPELINE.vector_register_file.lane9[i]);
				$display("%08x", `PIPELINE.vector_register_file.lane8[i]);
				$display("%08x", `PIPELINE.vector_register_file.lane7[i]);
				$display("%08x", `PIPELINE.vector_register_file.lane6[i]);
				$display("%08x", `PIPELINE.vector_register_file.lane5[i]);
				$display("%08x", `PIPELINE.vector_register_file.lane4[i]);
				$display("%08x", `PIPELINE.vector_register_file.lane3[i]);
				$display("%08x", `PIPELINE.vector_register_file.lane2[i]);
				$display("%08x", `PIPELINE.vector_register_file.lane1[i]);
				$display("%08x", `PIPELINE.vector_register_file.lane0[i]);
			end
		end

		if ($value$plusargs("autoflushl2=%d", do_autoflush_l2))
			sync_l2_cache;

		if ($value$plusargs("memdumpbase=%x", mem_dump_start)
			&& $value$plusargs("memdumplen=%x", mem_dump_length)
			&& $value$plusargs("memdumpfile=%s", filename))
		begin
			fp = $fopen(filename, "wb");
			for (i = 0; i < mem_dump_length; i = i + 4)
			begin
				mem_dat = memory.memory[(mem_dump_start + i) / 4];
				dummy_return = $fputc(mem_dat[31:24], fp);
				dummy_return = $fputc(mem_dat[23:16], fp);
				dummy_return = $fputc(mem_dat[15:8], fp);
				dummy_return = $fputc(mem_dat[7:0], fp);
			end

			$fclose(fp);
		end
		
		// Write a chunk of memory as a PPM file
		if ($value$plusargs("dumpfb=%s", filename))
		begin
			fp = $fopen(filename);
			$fwrite(fp, "P3\n64 64\n256\n");
			for (i = 'h3F000; i < 'h40000; i = i + 1)
			begin
				pixelval = memory.memory[i];
				$fwrite(fp, "%d %d %d\n", (pixelval >> 24) & 'hff,
					(pixelval >> 16) & 'hff,
					(pixelval >> 8) & 'hff);
			end
			$fclose(fp);
		end
	end

	// Manually copy lines from the L2 cache back to memory so we can
	// validate it there.
	reg[`L2_SET_INDEX_WIDTH - 1:0] set_index;
	reg[3:0] line_offset;
	reg[`L2_TAG_WIDTH - 1:0] flush_tag;
	integer set_index_count;
	integer line_offset_count;

	task sync_l2_cache;
	begin
		for (set_index_count = 0; set_index_count < `L2_NUM_SETS; set_index_count
			= set_index_count + 1)
		begin
			set_index = set_index_count;
	
			if (l2_cache.l2_cache_tag.l2_valid_mem0.data[set_index])
			begin
				flush_tag = l2_cache.l2_cache_tag.l2_tag_mem0.data[set_index];
				for (line_offset_count = 0; line_offset_count < 16; line_offset_count 
					= line_offset_count + 1)
				begin
					line_offset = line_offset_count;
					memory.memory[{ flush_tag, set_index, line_offset }] = 
						l2_cache.l2_cache_read.cache_mem.data[{ 2'd0, set_index }]
						 >> ((15 - line_offset) * 32);
				end
			end

			if (l2_cache.l2_cache_tag.l2_valid_mem1.data[set_index])
			begin
				flush_tag = l2_cache.l2_cache_tag.l2_tag_mem1.data[set_index];
				for (line_offset_count = 0; line_offset_count < 16; line_offset_count 
					= line_offset_count + 1)
				begin
					line_offset = line_offset_count;
					memory.memory[{ flush_tag, set_index, line_offset }] = 
						l2_cache.l2_cache_read.cache_mem.data[{ 2'd1, set_index }]
						 >> ((15 - line_offset) * 32);
				end
			end

			if (l2_cache.l2_cache_tag.l2_valid_mem2.data[set_index])
			begin
				flush_tag = l2_cache.l2_cache_tag.l2_tag_mem2.data[set_index];
				for (line_offset_count = 0; line_offset_count < 16; line_offset_count 
					= line_offset_count + 1)
				begin
					line_offset = line_offset_count;
					memory.memory[{ flush_tag, set_index, line_offset }] = 
						l2_cache.l2_cache_read.cache_mem.data[{ 2'd2, set_index }]
						 >> ((15 - line_offset) * 32);
				end
			end

			if (l2_cache.l2_cache_tag.l2_valid_mem3.data[set_index])
			begin
				flush_tag = l2_cache.l2_cache_tag.l2_tag_mem3.data[set_index];
				for (line_offset_count = 0; line_offset_count < 16; line_offset_count 
					= line_offset_count + 1)
				begin
					line_offset = line_offset_count;
					memory.memory[{ flush_tag, set_index, line_offset }] = 
						l2_cache.l2_cache_read.cache_mem.data[{ 2'd3, set_index }]
						 >> ((15 - line_offset) * 32);
				end
			end
		end
	end
	endtask
endmodule
