This is a port of DOOM to the Nyuzi architecture. This doesn't utilize many 
advanced features of the architecture like vector arithmetic or hardware 
threading  (even floating point is used only in a few spots).  However, it 
is a good test of the toolchain, as it is fairly large (50k lines of code, 
compiled to 300k). 

* A shareware WAD file is required to use this. It should be named "doom1.wad" 
and placed in this directory.
* Only Mac builds have the ability to show the framebuffer window and be played
interactively (because the simulator hasn't implemented this for other windowing
systems)

To use, type 'make run'

The primary changes I made for the port were:

* In w_wad.c, read the WAD file directly from a simulated block device. Since this is 
running on bare metal with a minimal libc, there is no filesystem layer. I commented 
out other code that interacted with the filesystem (for example, saving and restoring 
games).
* in i_video.c, added code to copy the screen to the framebuffer, expanding from an 
8 bit paletted format to the 32 bit per pixel framebuffer format.
* in i_video.c, reads from a virtual keyboard device for input.
* Fixed some places that made bad assumptions that the hardware supported 
unaligned memory accesses.
* Code from i_net and i_sound mostly removed, since there's no support for them.

