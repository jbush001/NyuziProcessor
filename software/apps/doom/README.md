This is a port of DOOM to the Nyuzi architecture. Although it doesn't use many 
advanced features of the architecture like vector arithmetic or hardware 
threading, it is a good test of the toolchain, as it is fairly large (50k lines 
of code, compiled to 300k). 

This requires a shareware WAD file to run.  This is not included in this 
repository, but you can find it easily with a Google search. It should be 
named "DOOM1.WAD" (case sensitive) and placed in this directory.

To run (in the emulator) type 'make run'.  This does not run on FPGA yet 
because there isn't a functional mass storage device to store the WAD.

The primary changes I made for the port were:

* in i_video.c, added code to copy the screen to the framebuffer, 
  expanding from an 8 bit paletted format to the 32 bit per pixel 
  framebuffer format.
* in i_video.c, read from a virtual keyboard device for input.
* W_CheckNumForName assumed support for unaligned accesses. Changed 
  to use memcmp.
* Code from i_net and i_sound removed, since there's no support for 
  them.