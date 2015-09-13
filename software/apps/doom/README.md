This is a port of DOOM to the Nyuzi architecture. Although it doesn't use
features like vector arithmetic or hardware threading, it is a good test of the
toolchain, as it is fairly large (50k lines of code, compiled to 300k binary).

This requires a shareware WAD file. This is not included in this repository, 
but you can find it with a Google search. Name it "DOOM1.WAD" (all uppercase) 
and put it in this directory.

To run in the emulator, type 'make run'.

To run on FPGA, type 'make fpgarun' in this directory. The makefile transfers 
the data files over the serial port into the ramdisk. This takes a while.

The primary changes I made for the port were:

* in i_video.c, added code to copy the screen to the framebuffer, expanding
  from an 8 bit paletted format to the 32 bit per pixel framebuffer format. 
* in i_video.c, read from a virtual keyboard device for input. 
* W_CheckNumForName assumed support for unaligned accesses. Changed to 
  use memcmp.
* Code from i_net and i_sound removed, as there is no hardware support 
  for them.
