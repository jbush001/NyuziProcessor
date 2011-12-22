//`define PIPELINE_ONLY

module pipeline_sim;
	
	parameter NUM_STRANDS = 4;
	parameter NUM_REGS = 32;

	reg clk;
	integer i;
 	reg[1000:0] filename;
	reg[31:0] regtemp[0:17 * NUM_REGS * NUM_STRANDS - 1];
	integer do_register_dump;
	integer mem_dump_start;
	integer mem_dump_length;
	reg[31:0] cache_dat;
	integer simulation_cycles;

`ifdef PIPELINE_ONLY
	sim_l1cache l1cache(
		.clk(clk),
		.iaddress_i(iaddr),
		.idata_o(idata),
		.iaccess_i(iaccess),
		.daddress_i(daddr),
		.ddata_o(ddata_from_mem),
		.ddata_i(ddata_to_mem),
		.dwrite_i(dwrite),
		.daccess_i(daccess),
		.dwrite_mask_i(dwrite_mask),
		.dack_o(dcache_hit));
		
	assign stbuf_full = 0;
	assign cache_load_complete = 0;
	assign icache_hit = 1;
`else
	wire 			port0_read;
	wire 			port0_ack;
	wire [25:0] 	port0_addr;
	wire [511:0] 	port0_data;
	wire 			port1_write;
	wire 			port1_ack;
	wire [25:0] 	port1_addr;
	wire [511:0] 	port1_data;
	wire [63:0] 	port1_mask;
	wire 			port2_read;
	wire 			port2_ack;
	wire [25:0] 	port2_addr;
	wire [511:0] 	port2_data;
	wire			processor_halt;

	core c(
		.clk(clk),
		.port0_read_o(port0_read),
		.port0_ack_i(port0_ack),
		.port0_addr_o(port0_addr),
		.port0_data_i(port0_data),
		.port1_write_o(port1_write),
		.port1_ack_i(port1_ack),
		.port1_addr_o(port1_addr),
		.port1_data_o(port1_data),
		.port1_mask_o(port1_mask),
		.port2_read_o(port2_read),
		.port2_ack_i(port2_ack),
		.port2_addr_o(port2_addr),
		.port2_data_i(port2_data),
		.halt_o(processor_halt));

	sim_l2cache l2cache(
		.clk(clk),
		.port0_read_i(port0_read),
		.port0_ack_o(port0_ack),
		.port0_addr_i(port0_addr),
		.port0_data_o(port0_data),
		.port1_write_i(port1_write),
		.port1_ack_o(port1_ack),
		.port1_addr_i(port1_addr),
		.port1_data_i(port1_data),
		.port1_mask_i(port1_mask),
		.port2_read_i(port2_read),
		.port2_ack_o(port2_ack),
		.port2_addr_i(port2_addr),
		.port2_data_o(port2_data));

`endif
 
	initial
	begin
		// Load executable binary into memory
        if ($value$plusargs("bin=%s", filename))
		begin
`ifdef PIPELINE_ONLY
			$readmemh(filename, l1cache.data);
`else
            $readmemh(filename, l2cache.data);
`endif

		end
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
			$dumpvars(100, c);
`ifdef PIPELINE_ONLY
			$dumpvars(100, l1cache);
`else
			$dumpvars(100, l2cache);
			$dumpvars(100, c.dcache);
			$dumpvars(100, c.icache);
`endif
		end
	
		// Run simulation for some number of cycles
		if (!$value$plusargs("simcycles=%d", simulation_cycles))
			simulation_cycles = 500;

		clk = 0;
		for (i = 0; i < simulation_cycles * 2 && !processor_halt; i = i + 1)
			#5 clk = ~clk;

		if (processor_halt)
			$display("***HALTED***");

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
`ifdef PIPELINE_ONLY
				cache_dat = l1cache.data[(mem_dump_start + i) / 4];
`else
				cache_dat = l2cache.data[(mem_dump_start + i) / 4];
`endif
				$display("%02x", cache_dat[31:24]);
				$display("%02x", cache_dat[23:16]);
				$display("%02x", cache_dat[15:8]);
				$display("%02x", cache_dat[7:0]);
			end
		end
	end
endmodule
