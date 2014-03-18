

program: fpga_target.sof
	quartus_pgm fpga_target.cdf

fpga_target.sof: ../fpga_top.v
	quartus_map fpga_target
	quartus_fit fpga_target
	quartus_asm fpga_target
	quartus_sta fpga_target
	
FORCE:
