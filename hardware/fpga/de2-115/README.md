# Running on Terasic DE2-115 FPGA board

Follow instructions in the top level README to get the environment set up.

These instructions only work on Linux.  It uses Terasic's
[DE2-115 evaluation board](http://www.terasic.com.tw/cgi-bin/page/archive.pl?Language=English&No=502).
In addition to the packages listed in the top level README, this also requires
[Quartus II FPGA design software](http://dl.altera.com/?edition=web) 13.1+.

The core runs at 50 MHz on this board.

## Setup

A diagram showing how to wire up the board is on the Wiki
[here](https://github.com/jbush001/NyuziProcessor/wiki/DE2-115-Setup).

1. This loads programs onto the board over the serial port, so your development
machine must be connected to the FPGA board with a serial cable.<sup>1</sup>

2. Set the environment variable SERIAL_PORT to the path of the serial device.
For example:

        export SERIAL_PORT="/dev/cu.usbserial"

    For a different serial device, you will need to find
    the device path. It may also be something like:

        /dev/ttyS0
        /dev/ttyUSB0

    This defaults to 921600 baud. If your serial device does not
    support this, you can change the rate the rate by modifying the
    DEFAULT_UART_BAUD define in the following two files:

        software/bootrom/boot.c
        tools/serial_boot/serial_boot.c

    You will need to resynthesize the design and rebuild the tools.

3. Allow serial port access without being root:

        sudo usermod -a -G dialout $USER

    You may need to log out and back in for the change to take effect.

4. Add the Quartus binary directory is in your PATH environment variable.
   The default install path is ~/altera/[version]/quartus/bin/

        export PATH=$PATH:<Path to Quartus bin directory>

5. Put the FPGA board is in JTAG mode by setting SW19 to 'RUN'

On some distributions of Linux, the Altera tools have trouble talking to USB if not
run as root. You can remedy this by creating a file
/etc/udev/rules.d/99-usbblaster.rules and adding the following line:

    ATTRS{idVendor}=="09fb" , MODE="0660" , GROUP="plugdev"

...then rebooting or executing the following command:

    sudo udevadm control --reload
    sudo killall -9 jtagd

<sup>1</sup> *Since most computers don't have native serial ports nowadays,
this will probably require a USB-to-serial adapter. Almost all of the adapters
one can buy use one of two chipsets: FTDI or Prolific. The Prolific chips are
more... common, especially in cheaper adapters. But the OS drivers for these
chips are notoriously unstable on all platforms, especially when transferring
large amounts of data like this project does. They often hang mid transfer or
cause the host machine to reboot. I would recommend finding one with a FTDI
based chipset. Unfortunately, most serial cables do not advertise which
chipset they use, but you can sometimes tell by going to their website to
download the drivers. Also, if you search for 'FTDI USB serial' on a retail
site like Amazon, there are a number that do explicitly note the chipset type.
This one has worked well for me: <http://a.co/hOTKx9R>*

## Synthesizing and Running Programs

The build system is command line based and does not use the Quartus GUI.

1. Synthesize the design. From this directory:

        make synthesize

2. Load the configuration bitstream onto the FPGA.

        make program

    You may get an error when running this command. If so, this can usually be
    fixed by running the following command:

        sudo killall -9 jtagd

3. Press 'key 0' on the lower right hand of the board to reset the processor.
   Green LED 0 will start blinking, indicating the bootloader is waiting to
   receive a program over the serial port.

4. Load program into memory and execute it:

        cd ../../../tests/fpga/blinky
        run_fpga

## Other notes

- Most programs have a script 'run_fpga' that will load them
  onto the FPGA board using the serial_loader program (tools/serial_loader).
- Reload programs by pressing the reset button (push button 0) and using
  'run_fpga' again.
- You do not need to reload the bitstream (step 2) as long as the board is
  powered (it will be lost if it is turned off, however).
- The `program` target does not resynthesize the bitstream if source files
  have changed. This must be done explicitly by typing `make synthesize`.
- The serial_loader program is also capable of loading a ramdisk file into
  memory on the board, which some of the test programs use.
