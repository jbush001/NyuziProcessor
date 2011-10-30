`include "timescale.v"

module pipeline_sim;

	reg clk;
	wire[31:0] iaddr;
	wire[31:0] idata;
	wire iaccess;
	wire[31:0] daddr;
	wire[31:0] ddata_to_mem;
	wire[31:0] ddata_from_mem;
	wire dwrite;
	wire daccess;
	wire[3:0] dsel;
	wire dack;

	sim_cache cache(
		.clk(clk),
		.iaddress_i(iaddr),
		.idata_o(idata),
		.iaccess_i(iaccess),
		.daddress_i(daddr),
		.ddata_o(ddata_from_mem),
		.ddata_i(ddata_to_mem),
		.dwrite_i(dwrite),
		.daccess_i(daccess),
		.dsel_i(dsel),
		.dack_o(dack));

	pipeline p(
		.clk(clk),
		.iaddress_o(iaddr),
		.idata_i(idata),
		.iaccess_o(iaccess),
		.dcache_hit_i(dack),
		.daddress_o(daddr),
		.ddata_i(ddata_from_mem),
		.ddata_o(ddata_to_mem),
		.dwrite_o(dwrite),
		.daccess_o(daccess),
		.dsel_o(dsel));

	integer i;
 	reg[1000:0] code_filename;
 	reg[1000:0] trace_filename;
 
	initial
	begin
        if ($value$plusargs("bin=%s", code_filename))
            $readmemh(code_filename, cache.data);
        else
        begin
            $display("error opening file");
            $finish;
        end

		if ($value$plusargs("trace=%s", trace_filename))
		begin
			$dumpfile(trace_filename);
			$dumpvars(100, p);
			$dumpvars(100, cache);
		end
	
		clk = 0;
		for (i = 0; i < 1000; i = i + 1)
			#5 clk = ~clk;
	end
endmodule
