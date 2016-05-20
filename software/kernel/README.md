This is a quick and dirty kernel that exercises MMU and supervisor mode
related functionality. This is not used by other applications now, which
run on bare metal and use libos.

In the current default configuration, it attempts to load a file "program.elf"
from the filesystem as a user space program and execute it. The test program
is located in tests/kernel/.
