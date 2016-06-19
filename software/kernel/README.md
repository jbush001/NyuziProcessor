This is a quick and dirty kernel that exercises MMU and supervisor mode related
functionality. This is not used by the other applications now, which run on
bare metal and use libos.

This isn't executed from this directory. On startup, it loads the file
"program.elf" from the filesystem and executes it as a user space program.

