This is a quick and dirty kernel that exercises MMU and supervisor mode related
functionality. This is not used by default by other applications now, which run
on bare metal.

On startup, it loads the file "program.elf" from the filesystem and executes it
as a user space program. This isn't executed from this directory, but is
referenced from other directories that contain user space test programs.

Being a test platform, it is incomplete in spots. It contains a fairly full
virtual memory implementation, but no user level synchronization or filesystem
APIs. The downside of that is that I can't use it to stress the hardware with
real workloads.

The reason I built something from scatch rather than using an existing
OS was that I couldn't find something that met my needs. Linux and
FreeBSD are very large: they would take forever to boot in simulation,
making them not well suited for automated testing and CI. There are simpler
operating systems like xv6, but their support for things like copy-on-write
and demand paging are limited, so they don't have very good coverage for
validating the design. There are other open source operating systems that
probably better balance these requirements, but that requires more research.
