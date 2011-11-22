`define PIPELINE_ONLY

module pipeline_sim;

	reg clk;
	wire[31:0] iaddr;
	wire[31:0] idata;
	wire iaccess;
	wire[31:0] daddr;
	wire[511:0] ddata_to_mem;
	wire[511:0] ddata_from_mem;
	wire dwrite;
	wire daccess;
	wire[63:0] dwrite_mask;
	wire dcache_hit;
	integer i;
 	reg[1000:0] filename;
	reg[31:0] vectortmp[0:17 * 32 - 1];
	integer do_register_dump;
	integer mem_dump_start;
	integer mem_dump_length;
	reg[31:0] cache_dat;
	integer simulation_cycles;
	wire cache_load_complete;

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
		
	assign cache_load_complete = 1;
`else
	wire l2_write;
	wire l2_read;
	wire l2_ack;
	wire[31:0] l2_addr;
	wire[511:0] data_to_l2;
	wire[511:0] data_from_l2;

	sim_l2cache l2cache(
		.clk(clk),
		.iaddress_i(iaddr),
		.idata_o(idata),
		.iaccess_i(iaccess),
		.dwrite_i(l2_write),
		.dread_i(l2_read),
		.dack_o(l2_ack),
		.daddr_i(l2_addr),
		.ddata_i(data_to_l2),
		.ddata_o(data_from_l2));

	data_cache dcache(
		.clk(clk),
		.address_i(daddr),
		.data_o(ddata_from_mem),
		.data_i(ddata_to_mem),
		.write_i(dwrite),
		.access_i(daccess),
		.write_mask_i(dwrite_mask),
		.cache_hit_o(dcache_hit),
		.cache_load_complete_o(cache_load_complete),
		.l2_write_o(l2_write),
		.l2_read_o(l2_read),
		.l2_ack_i(l2_ack),
		.l2_addr_o(l2_addr),
		.l2_data_i(data_from_l2),
		.l2_data_o(data_to_l2));

`endif

	pipeline p(
		.clk(clk),
		.iaddress_o(iaddr),
		.idata_i(idata),
		.iaccess_o(iaccess),
		.dcache_hit_i(dcache_hit),
		.daddress_o(daddr),
		.ddata_i(ddata_from_mem),
		.ddata_o(ddata_to_mem),
		.dwrite_o(dwrite),
		.daccess_o(daccess),
		.dwrite_mask_o(dwrite_mask),
		.cache_load_complete_i(cache_load_complete));
 
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
			$readmemh(filename, vectortmp);
			for (i = 0; i < 31; i = i + 1)		// ignore PC
				p.srf.registers[i] = vectortmp[i];

			for (i = 0; i < 32; i = i + 1)
			begin
				p.vrf.lane15[i] = vectortmp[(i + 2) * 16];
				p.vrf.lane14[i] = vectortmp[(i + 2) * 16 + 1];
				p.vrf.lane13[i] = vectortmp[(i + 2) * 16 + 2];
				p.vrf.lane12[i] = vectortmp[(i + 2) * 16 + 3];
				p.vrf.lane11[i] = vectortmp[(i + 2) * 16 + 4];
				p.vrf.lane10[i] = vectortmp[(i + 2) * 16 + 5];
				p.vrf.lane9[i] = vectortmp[(i + 2) * 16 + 6];
				p.vrf.lane8[i] = vectortmp[(i + 2) * 16 + 7];
				p.vrf.lane7[i] = vectortmp[(i + 2) * 16 + 8];
				p.vrf.lane6[i] = vectortmp[(i + 2) * 16 + 9];
				p.vrf.lane5[i] = vectortmp[(i + 2) * 16 + 10];
				p.vrf.lane4[i] = vectortmp[(i + 2) * 16 + 11];
				p.vrf.lane3[i] = vectortmp[(i + 2) * 16 + 12];
				p.vrf.lane2[i] = vectortmp[(i + 2) * 16 + 13];
				p.vrf.lane1[i] = vectortmp[(i + 2) * 16 + 14];
				p.vrf.lane0[i] = vectortmp[(i + 2) * 16 + 15];
			end
			
			do_register_dump = 1;
		end

		// Open a trace file
		if ($value$plusargs("trace=%s", filename))
		begin
			$dumpfile(filename);
			$dumpvars(100, p);
`ifdef PIPELINE_ONLY
			$dumpvars(100, l1cache);
`else
			$dumpvars(100, l2cache);
			$dumpvars(100, dcache);
`endif
		end
	
		// Run simulation for some number of cycles
		if (!$value$plusargs("simcycles=%d", simulation_cycles))
			simulation_cycles = 500;

		clk = 0;
		for (i = 0; i < simulation_cycles * 2; i = i + 1)
			#5 clk = ~clk;

		if (do_register_dump)
		begin
			$display("REGISTERS:");
			// Dump the registers
			for (i = 0; i < 32; i = i + 1)
				$display("%08x", p.srf.registers[i]);
	
			for (i = 0; i < 32; i = i + 1)
			begin
				$display("%08x", p.vrf.lane15[i]);
				$display("%08x", p.vrf.lane14[i]);
				$display("%08x", p.vrf.lane13[i]);
				$display("%08x", p.vrf.lane12[i]);
				$display("%08x", p.vrf.lane11[i]);
				$display("%08x", p.vrf.lane10[i]);
				$display("%08x", p.vrf.lane9[i]);
				$display("%08x", p.vrf.lane8[i]);
				$display("%08x", p.vrf.lane7[i]);
				$display("%08x", p.vrf.lane6[i]);
				$display("%08x", p.vrf.lane5[i]);
				$display("%08x", p.vrf.lane4[i]);
				$display("%08x", p.vrf.lane3[i]);
				$display("%08x", p.vrf.lane2[i]);
				$display("%08x", p.vrf.lane1[i]);
				$display("%08x", p.vrf.lane0[i]);
			end
		end
		
`ifdef PIPELINE_ONLY
		// This doesn't really work right with the cache
		if ($value$plusargs("memdumpbase=%x", mem_dump_start)
			&& $value$plusargs("memdumplen=%x", mem_dump_length))
		begin
			$display("MEMORY:");
			for (i = 0; i < mem_dump_length; i = i + 4)
			begin
				cache_dat = l1cache.data[(mem_dump_start + i) / 4];
				$display("%02x", cache_dat[31:24]);
				$display("%02x", cache_dat[23:16]);
				$display("%02x", cache_dat[15:8]);
				$display("%02x", cache_dat[7:0]);
			end
		end
`endif
	end
endmodule
