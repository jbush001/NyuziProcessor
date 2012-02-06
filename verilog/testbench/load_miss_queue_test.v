module load_miss_queue_test;

	parameter TAG_WIDTH = 21;
	parameter SET_INDEX_WIDTH = 5;
	parameter WAY_INDEX_WIDTH = 2;

	reg clk = 0;
	reg request = 0;
	reg[TAG_WIDTH - 1:0] tag = 0;
	reg[SET_INDEX_WIDTH - 1:0] set = 0;
	reg[1:0] victim_way = 0;
	reg[1:0] strand = 0;
	wire[3:0] load_complete_strands;
	wire[SET_INDEX_WIDTH - 1:0] load_complete_set;
	wire[TAG_WIDTH - 1:0] load_complete_tag;
	wire[1:0] load_complete_way;
	wire pci_valid;
	reg pci_ack = 0;
	wire[3:0] pci_id;
	wire[1:0] pci_op;
	wire[1:0] pci_way;
	wire[25:0] pci_address;
	wire[511:0] pci_data;
	wire[63:0] pci_mask;
	reg cpi_valid = 0;
	reg[3:0] cpi_id = 0;
	reg[1:0] cpi_op = 0;
	reg cpi_allocate = 0;
	reg[1:0] cpi_way = 0;
	reg[511:0] cpi_data = 0;
	reg[3:0] save_pci_id0 = 0;
	reg[3:0] save_pci_id1 = 0;

	load_miss_queue lmq(
		.clk(clk),
		.request_i(request),
		.tag_i(tag),
		.set_i(set),
		.victim_way_i(victim_way),
		.strand_i(strand),
		.load_complete_strands_o(load_complete_strands),
		.load_complete_set_o(load_complete_set),
		.load_complete_tag_o(load_complete_tag),
		.load_complete_way_o(load_complete_way),
		.pci_valid_o(pci_valid),
		.pci_ack_i(pci_ack),
		.pci_id_o(pci_id),
		.pci_op_o(pci_op),
		.pci_way_o(pci_way),
		.pci_address_o(pci_address),
		.pci_data_o(pci_data),
		.pci_mask_o(pci_mask),
		.cpi_valid_i(cpi_valid),
		.cpi_id_i(cpi_id),
		.cpi_op_i(cpi_op),
		.cpi_allocate_i(cpi_allocate),
		.cpi_way_i(cpi_way),
		.cpi_data_i(cpi_data));

	task issue_load_request;
		input [31:0] address;
		input [1:0] way;
		input [1:0] st;
	begin
		request = 1;
		tag = address[31:11];
		set = address[10:6];
		victim_way = way;
		strand = st;
		#5 clk = 1;
		#5 clk = 0;
		request = 0;
	end
	endtask
	
	task validate_pci_request;
		input [31:0] address;
		input [1:0] way;
	begin
		if (pci_valid != 1)
		begin
			$display("validate_pci_request: no PCI access");
			$finish;
		end

		if (pci_address != address[31:6])
		begin
			$display("validate_pci_request: bad PCI address %x expected %x", 
				{ pci_address, 6'd0 }, address);
			$finish;
		end
	end
	endtask
	
	task ack_pci_request;
	begin
		pci_ack = 1;
		#5 clk = 1;
		#5 clk = 0;
		pci_ack = 0;
	end
	endtask
	
	task send_cpi_response;
		input [3:0] id;
		input [1:0] op;
		input allocate;
		input [1:0] way;
		input [511:0] data;
	begin
		cpi_valid = 1;
		cpi_id = id;
		cpi_op = op;
		cpi_allocate = allocate;
		cpi_way = way;
		cpi_data = data;
	end
	endtask
	
	task validate_load_response;
		input [3:0] strands;
	begin
		if (load_complete_strands != strands)
		begin
			$display("validate_load_response: no load complete expected %b got %b",
				strands, load_complete_strands);
			$finish;
		end
		
		// XXX check rest of signals
	end
	endtask
	
	initial
	begin
		
		$dumpfile("trace.vcd");
		$dumpvars;

		///////////////////////////////////////////////////////////////
		// Case 1: enqueue a single load and verify it is issued
		///////////////////////////////////////////////////////////////

		$display("case 1");
		issue_load_request('h1234abcd, 1, 0);
		#5 clk = 1;
		#5 clk = 0;
		save_pci_id0 = pci_id;
		validate_pci_request('h1234abcd, 1);
		ack_pci_request;
		send_cpi_response(save_pci_id0, 0, 0, 1, 0);
		#1 validate_load_response(4'b0001);
		#5 clk = 1;
		#5 clk = 0;
		cpi_valid = 0;

		///////////////////////////////////////////////////////////////
		// Case 2: enqueue loads for two different lines and ensure
		// they are handled in order
		///////////////////////////////////////////////////////////////
		$display("case 2");
		issue_load_request('habababab, 1, 0);
		issue_load_request('hcdcdcdcd, 2, 1);
		#5 clk = 1;
		#5 clk = 0;

		$display("access 1");
		validate_pci_request('habababab, 1);

		save_pci_id0 = pci_id;
		ack_pci_request;
		#5 clk = 1;
		#5 clk = 0;

		$display("access 2");
		validate_pci_request('hcdcdcdcd, 2);
		save_pci_id1 = pci_id;
		ack_pci_request;

		send_cpi_response(save_pci_id0, 0, 0, 1, 0);
		#1 validate_load_response(4'b0001);
		#5 clk = 1;
		#5 clk = 0;

		send_cpi_response(save_pci_id1 , 0, 0, 2, 0);	
		#1 validate_load_response(4'b0010);
		#5 clk = 1;
		#5 clk = 0;
		
		///////////////////////////////////////////////////////////////
		// Case 3: enqueue loads for the same line and ensure they
		// are properly combined
		///////////////////////////////////////////////////////////////
		$display("case 3");
		issue_load_request('habababab, 1, 0);
		issue_load_request('habababab, 2, 1);
		#5 clk = 1;
		#5 clk = 0;

		$display("access 1");
		validate_pci_request('habababab, 1);
		save_pci_id0 = pci_id;
		ack_pci_request;
		#5 clk = 1;
		#5 clk = 0;

		if (pci_valid != 0)
		begin
			$display("unexpected PCI access");
			$finish;
		end

		send_cpi_response(save_pci_id0, 0, 0, 1, 0);
		#1 validate_load_response(4'b0011);
		
		
		
		

		///////////////////////////////////////////////////////////////
		// Case 4: random loads
		///////////////////////////////////////////////////////////////
	
	
		$display("tests complete");
	end

endmodule
