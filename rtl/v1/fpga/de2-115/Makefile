


fpga_target.sof: 
	quartus_map fpga_target
	quartus_fit fpga_target
	quartus_asm fpga_target
	quartus_sta fpga_target
	
program: fpga_target.sof
	quartus_pgm fpga_target.cdf

FORCE:
