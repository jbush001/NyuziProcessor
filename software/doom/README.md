This is a port of DOOM to the Nyuzi architecture. This doesn't utilize a lot of 
features of the architecture like the vector unit or hardware threading (floating 
point is only used in a few spots), but is a good test of the toolchain, as it is
a fairly large program. This currently only works for Mac builds, since that is the only 
platform that I have implemented the framebuffer window in the simulator for. It also
only works in the functional sim, since the verilog model doesn't support the virtual 
block device (plus it would probably take a day to render a single frame :). A shareware 
WAD file is required to use this. It should be named "doom1.wad" and placed in this 
directory.

The primary changes I made in the port were:

* In w_wad.c, read the WAD file directly from a virtual block device. Since this is 
running on bare metal with a minimal libc, there is no filesystem layer. I commented 
out other code that interacted with the filesystem (for example, saving and restoring 
games).
* in i_video.c, added code to copy the screen to the framebuffer, expanding from an 
8 bit paletted format to 32 bits per pixel in the process.
* in i_video.c, it also reads from a virtual keyboard device for input.
* There were some places that made bad assumptions about the hardware supporting 
unaligned memory accesses.
* Code from i_net and i_sound mostly removed, since there's no OS to support them.
