# Running on Terasic DE2-115 FPGA board

Follow instructions in the top level README to get the environment set up.

Synthesizing and running on FPGA only works on Linux.  It uses Terasic's
[DE2-115 evaluation board](http://www.terasic.com.tw/cgi-bin/page/archive.pl?Language=English&No=502).
In addition to the packages listed in the top level README, this also requires 
[Quartus II FPGA design software](http://dl.altera.com/?edition=web) 13.1+.

## Setup

1. This loads programs onto the board over the serial port, so your development
machine must be connected to the FPGA board using a serial cable. 

2. Set the environment variable SERIAL_PORT to the path of the serial device.
For a Prolific USB based dongle, for example, the path is.

        export SERIAL_PORT="/dev/ttyUSB0"

    For a different serial device, you will need to figure
    out the device path.

3. Ensure you can access the serial port without being root:

        sudo usermod -a -G dialout $USER
    
4. Make sure the FPGA board is in JTAG mode by setting SW19 to 'RUN'

On some distributions of Linux, the Altera tools have trouble talking to USB if not 
run as root. This can be remedied by creating a file 
/etc/udev/rules.d/99-custom.rules and adding the following line:

    ATTRS{idVendor}=="09fb" , MODE="0660" , GROUP="plugdev" 

## Running

The build system is command line based and does not use the Quartus GUI.

1. Make sure you've compiled the bootrom , either by typing make at the top 
level, or in the software/bootrom directory.

2. Synthesize the design (ensure quartus binary directory is in your PATH, by
   default installed in ~/altera/[version]/quartus/bin/). From this directory:

        make

3. Load the configuration bitstream onto the FPGA.

        make program 

4. Press 'key 0' on the lower right hand of the board to reset the processor
5. Load program into memory and execute it using the runit script as below.

        cd ../../../tests/fpga/blinky
        ./runit.sh

Other notes:
- Programs can be reloaded by pressing the reset button and executing the runit script
or makefile again.
- Many programs with makefiles have a target 'fpgarun' that will load them
onto the FPGA board using the serial loader.
- The bitstream does not need to be reloaded (step 3) as long as the board is powered 
(it will be lost if it is turned off, however). 
- The program target does not resynthesize the bitstream if source files have changed.
This must be done explicitly by typing make.

