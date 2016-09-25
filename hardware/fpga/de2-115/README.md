# Running on Terasic DE2-115 FPGA board

Follow instructions in the top level README to get the environment set up.

These instructions only work on Linux.  It uses Terasic's
[DE2-115 evaluation board](http://www.terasic.com.tw/cgi-bin/page/archive.pl?Language=English&No=502).
In addition to the packages listed in the top level README, this also requires
[Quartus II FPGA design software](http://dl.altera.com/?edition=web) 13.1+.

## Setup

1. This loads programs onto the board over the serial port, so your development
machine must be connected to the FPGA board with a serial cable.

2. Set the environment variable SERIAL_PORT to the path of the serial device.
For a Prolific USB based dongle, for example, the path is.

        export SERIAL_PORT="/dev/ttyUSB0"

    For a different serial device, you will need to find
    the device path. It may also be something like:

	    /dev/ttyS0

    This defaults to 921600 baud. If your serial device does not
    support this, you can change the rate the rate by modifying the
    DEFAULT_UART_BAUD define in the following two files:

        software/bootrom/boot.c
        tools/serial_boot/serial_boot.c

3. Ensure you can access the serial port without being root:

        sudo usermod -a -G dialout $USER

    You may need to log out and back in for the change to take effect.

4. Make sure the Quartus binary directory is in your PATH environment variable.
   The default install path is ~/altera/[version]/quartus/bin/

        export PATH=$PATH:<Path to Quartus bin directory>

5. Make sure the FPGA board is in JTAG mode by setting SW19 to 'RUN'

On some distributions of Linux, the Altera tools have trouble talking to USB if not
run as root. You can remedy this by creating a file
/etc/udev/rules.d/99-usbblaster.rules and adding the following line:

    ATTRS{idVendor}=="09fb" , MODE="0660" , GROUP="plugdev"

Reboot or execute the following command:

    sudo udevadm control --reload
    sudo killall -9 jtagd

## Synthesizing and Running Programs

The build system is command line based and does not use the Quartus GUI.

1. Synthesize the design. From this directory:

        make synthesize

2. Load the configuration bitstream onto the FPGA.

        make program

    You may get an error when running this command. If so, this can usually be fixed by doing:

        sudo killall -9 jtagd

3. Press 'key 0' on the lower right hand of the board to reset the processor. LED 0
   will light up on the board to indicate the bootloader is waiting to receive a
   program over the serial port.

4. Load program into memory and execute it:

        cd ../../../tests/fpga/blinky
        make fpgarun

Other notes:
- Most programs with makefiles have a target 'fpgarun' that will load them
  onto the FPGA board using the serial_loader program (tools/serial_loader).
- Reload programs by pressing the reset button (push button 0) and using
  'make fpgarun' again.
- You do not need to reload the bitstream (step 2) as long as the board is powered
  (it will be lost if it is turned off, however).
- The `program` target does not resynthesize the bitstream if source files have changed.
  This must be done explicitly by typing `make synthesize`.
- The serial_loader program is also capable of loading a ramdisk file into memory on
  the board, which some of the test programs use.

