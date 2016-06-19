This static library is linked with programs to provide OS-like functionality.
This includes POSIX system calls and driver functions for peripherals like the
UART.

There are two variants of this library. The 'bare-metal' version runs as a
standalone executable with no operating system support and the MMU disabled.
The 'kernel' runs as a user mode program loaded by os/kernel and makes system
calls where necessary.

Both the crt0 and libos libraries must be linked against to use a specific
variant. The kernel version must be linked at an address greater than 0x1000.
The bare metal version must be linked at address 0.

The kernel version is a work in progress. A number of system calls are not yet
implemented.
