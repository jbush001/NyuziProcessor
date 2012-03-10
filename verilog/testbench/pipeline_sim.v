module pipeline_sim;
	
	parameter NUM_STRANDS = 4;
	parameter NUM_REGS = 32;

	reg 			clk;
	integer 		i;
	reg[1000:0] 	filename;
	reg[31:0] 		regtemp[0:17 * NUM_REGS * NUM_STRANDS - 1];
	integer 		do_register_dump;
	integer 		mem_dump_start;
	integer 		mem_dump_length;
	reg[31:0] 		cache_dat;
	integer 		simulation_cycles;
	wire			processor_halt;
	wire			pci_valid;
	wire			pci_ack;
	wire[1:0]		pci_unit;
	wire[1:0]		pci_strand;
	wire[1:0]		pci_op;
	wire[1:0]		pci_way;
	wire[25:0]		pci_address;
	wire[511:0]		pci_data;
	wire[63:0]		pci_mask;
	wire 			cpi_valid;
	wire[1:0]		cpi_unit;
	wire[1:0]		cpi_strand;
	wire[1:0]		cpi_op;
	wire 			cpi_update;
	wire[1:0]		cpi_way;
	wire[511:0]		cpi_data;
	integer			fp;
	integer			pixelval;

	core c(
		.clk(clk),
		.pci_valid_o(pci_valid),
		.pci_ack_i(pci_ack),
		.pci_strand_o(pci_strand),
		.pci_unit_o(pci_unit),
		.pci_op_o(pci_op),
		.pci_way_o(pci_way),
		.pci_address_o(pci_address),
		.pci_data_o(pci_data),
		.pci_mask_o(pci_mask),
		.cpi_valid_i(cpi_valid),
		.cpi_unit_i(cpi_unit),
		.cpi_strand_i(cpi_strand),
		.cpi_op_i(cpi_op),
		.cpi_update_i(cpi_update),
		.cpi_way_i(cpi_way),
		.cpi_data_i(cpi_data),
		.halt_o(processor_halt));

	sim_l2cache l2cache(
		.clk(clk),
		.pci_valid_i(pci_valid),
		.pci_ack_o(pci_ack),
		.pci_unit_i(pci_unit),
		.pci_strand_i(pci_strand),
		.pci_op_i(pci_op),
		.pci_way_i(pci_way),
		.pci_address_i(pci_address),
		.pci_data_i(pci_data),
		.pci_mask_i(pci_mask),
		.cpi_valid_o(cpi_valid),
		.cpi_unit_o(cpi_unit),
		.cpi_strand_o(cpi_strand),
		.cpi_op_o(cpi_op),
		.cpi_update_o(cpi_update),
		.cpi_way_o(cpi_way),
		.cpi_data_o(cpi_data));

	initial
	begin
		// Load executable binary into memory
		if ($value$plusargs("bin=%s", filename))
			$readmemh(filename, l2cache.data);
		else
		begin
			$display("error opening file");
			$finish;
		end

		do_register_dump = 0;

		// If initial values are passed for scalar registers, load those now
		if ($value$plusargs("initial_regs=%s", filename))
		begin
			$readmemh(filename, regtemp);
			for (i = 0; i < NUM_REGS * NUM_STRANDS; i = i + 1)		// ignore PC
				c.p.srf.registers[i] = regtemp[i];

			for (i = 0; i < NUM_REGS * NUM_STRANDS; i = i + 1)
			begin
				c.p.vrf.lane15[i] = regtemp[(i + 8) * 16];
				c.p.vrf.lane14[i] = regtemp[(i + 8) * 16 + 1];
				c.p.vrf.lane13[i] = regtemp[(i + 8) * 16 + 2];
				c.p.vrf.lane12[i] = regtemp[(i + 8) * 16 + 3];
				c.p.vrf.lane11[i] = regtemp[(i + 8) * 16 + 4];
				c.p.vrf.lane10[i] = regtemp[(i + 8) * 16 + 5];
				c.p.vrf.lane9[i] = regtemp[(i + 8) * 16 + 6];
				c.p.vrf.lane8[i] = regtemp[(i + 8) * 16 + 7];
				c.p.vrf.lane7[i] = regtemp[(i + 8) * 16 + 8];
				c.p.vrf.lane6[i] = regtemp[(i + 8) * 16 + 9];
				c.p.vrf.lane5[i] = regtemp[(i + 8) * 16 + 10];
				c.p.vrf.lane4[i] = regtemp[(i + 8) * 16 + 11];
				c.p.vrf.lane3[i] = regtemp[(i + 8) * 16 + 12];
				c.p.vrf.lane2[i] = regtemp[(i + 8) * 16 + 13];
				c.p.vrf.lane1[i] = regtemp[(i + 8) * 16 + 14];
				c.p.vrf.lane0[i] = regtemp[(i + 8) * 16 + 15];
			end
			
			do_register_dump = 1;
		end

		// Open a trace file
		if ($value$plusargs("trace=%s", filename))
		begin
			$dumpfile(filename);
			$dumpvars;
		end
	
		// Run simulation for some number of cycles
		if (!$value$plusargs("simcycles=%d", simulation_cycles))
			simulation_cycles = 500;

		clk = 0;
		for (i = 0; i < simulation_cycles * 2 && !processor_halt; i = i + 1)
			#5 clk = ~clk;

		if (processor_halt)
			$display("***HALTED***");

		$display("ran for %d cycles", i / 2);
		$display(" no issue cycles %d", c.p.ss.idle_cycle_count);
		$display(" RAW conflict %d", 
			c.p.ss.s0.raw_wait_count
			+ c.p.ss.s1.raw_wait_count
			+ c.p.ss.s2.raw_wait_count
			+ c.p.ss.s3.raw_wait_count);
		$display(" wait for dcache/store %d", 
			c.p.ss.s0.dcache_wait_count
			+ c.p.ss.s1.dcache_wait_count
			+ c.p.ss.s2.dcache_wait_count
			+ c.p.ss.s3.dcache_wait_count);
		$display(" wait for icache %d", 
			c.p.ss.s0.icache_wait_count
			+ c.p.ss.s1.icache_wait_count
			+ c.p.ss.s2.icache_wait_count
			+ c.p.ss.s3.icache_wait_count);


		if (do_register_dump)
		begin
			$display("REGISTERS:");
			// Dump the registers
			for (i = 0; i < NUM_REGS * NUM_STRANDS; i = i + 1)
				$display("%08x", c.p.srf.registers[i]);
	
			for (i = 0; i < NUM_REGS * NUM_STRANDS; i = i + 1)
			begin
				$display("%08x", c.p.vrf.lane15[i]);
				$display("%08x", c.p.vrf.lane14[i]);
				$display("%08x", c.p.vrf.lane13[i]);
				$display("%08x", c.p.vrf.lane12[i]);
				$display("%08x", c.p.vrf.lane11[i]);
				$display("%08x", c.p.vrf.lane10[i]);
				$display("%08x", c.p.vrf.lane9[i]);
				$display("%08x", c.p.vrf.lane8[i]);
				$display("%08x", c.p.vrf.lane7[i]);
				$display("%08x", c.p.vrf.lane6[i]);
				$display("%08x", c.p.vrf.lane5[i]);
				$display("%08x", c.p.vrf.lane4[i]);
				$display("%08x", c.p.vrf.lane3[i]);
				$display("%08x", c.p.vrf.lane2[i]);
				$display("%08x", c.p.vrf.lane1[i]);
				$display("%08x", c.p.vrf.lane0[i]);
			end
		end

		// This doesn't really work right with the cache
		if ($value$plusargs("memdumpbase=%x", mem_dump_start)
			&& $value$plusargs("memdumplen=%x", mem_dump_length))
		begin
			$display("MEMORY:");
			for (i = 0; i < mem_dump_length; i = i + 4)
			begin
				cache_dat = l2cache.data[(mem_dump_start + i) / 4];
				$display("%02x", cache_dat[31:24]);
				$display("%02x", cache_dat[23:16]);
				$display("%02x", cache_dat[15:8]);
				$display("%02x", cache_dat[7:0]);
			end
		end
		
		// Write a chunk of memory as a PPM file
		if ($value$plusargs("dumpfb=%s", filename))
		begin
			fp = $fopen(filename);
			$fwrite(fp, "P3\n64 64\n256\n");
			for (i = 'h3F000; i < 'h40000; i = i + 1)
			begin
				pixelval = l2cache.data[i];
				$fwrite(fp, "%d %d %d\n", (pixelval >> 24) & 'hff,
					(pixelval >> 16) & 'hff,
					(pixelval >> 8) & 'hff);
			end
			$fclose(fp);
		end
		
	end
endmodule
