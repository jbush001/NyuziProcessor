This is a quick and dirty kernel that exercises MMU and supervisor mode related
functionality. This is not used by the other applications now, which run on
bare metal and use libos.

This isn't executed from this directory. There are test programs in
tests/kernel that use the image produced here. On startup, it executes the file
"program.elf" from the filesystem as a user space program.

