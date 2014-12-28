This is a first stage bootloader that is used to work around size limitations in
the FPGA JTAG loader (which can only load images into the small chunk of
boot SRAM).  This is controlled by the command line tool in tools/serial_boot. This
is first loaded into SRAM using the jload command:

    jload boot.hex

Then the serial boot program talks to this loaded to load an ELF file into SDRAM:

    bin/serial_boot program.elf

