This is a port of DOOM to the Nyuzi architecture. This doesn't utilize many 
advanced features of the architecture like vector arithmetic or hardware 
threading  (even floating point is used only in a few spots), but it 
is a good test of the toolchain, as it is fairly large (50k lines of code, 
compiled to 300k). 

A shareware WAD file is required to use this. This is not included in this
repository, but can be found pretty easily with a Google search. It should be 
named "DOOM1.WAD" (case sensitive) and placed in this directory.

To run (in the emulator) type 'make run'.  This does not currently run on FPGA
because there isn't a mass storage device to store the WAD.

The primary changes I made for the port were:

* in i_video.c, added code to copy the screen to the framebuffer, expanding 
from an 8 bit paletted format to the 32 bit per pixel framebuffer format.
* in i_video.c, reads from a virtual keyboard device for input.
* W_CheckNumForName assumes support for unaligned accesses, changed to use memcmp.
* Code from i_net and i_sound removed, since there's no support for them.

